---
layout: post
title : unity_ugui_particle
categories: [ugui]
excerpt_seperator: <!--more-->
tags: [unity, ugui, particlesystem]
---
最近在整理以前的代码，看到以前使用UGUI刷新ParticleSystem的一些代码，稍微整理下了。
<!--more-->

## 背景

主要是，制作UI的时候，会遇到一些游戏UI上特效层级遮挡关系，UGUI这边传统的做法无非canvas，sort layer+sort order, z值修改，略微麻烦，所以在考虑有没有更好点的方法，
当时写下了这个方法，现在回首看看，还是有些问题的。

## 源码
```
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.UI;

[ExecuteInEditMode]
class UIBillboardParticle : Graphic
{
    private Canvas _canvas;
    private ParticleSystem _pSystem;
    private ParticleSystemRenderer _pRenderer;
    private ParticleSystem.Particle[] _particles;
    private Mesh _mesh;
    private Texture _curTexture;
    private UIVertex[] _quad = new UIVertex[4];
    protected override void Awake()
    {
        base.Awake();
        _canvas = MaskUtilities.FindRootSortOverrideCanvas(transform).GetComponent<Canvas>();
        _pSystem = GetComponentInChildren<ParticleSystem>();
        _pRenderer = _pSystem.GetComponent<ParticleSystemRenderer>();
        if (_pRenderer != null)
        {
            _pRenderer.enabled = false;
        }
        var mat = _pRenderer.sharedMaterial;
        material = mat;
        _curTexture = mat.mainTexture;
        _particles = new ParticleSystem.Particle[_pSystem.main.maxParticles];
        _mesh = _pRenderer.mesh;
    }
    public override Texture mainTexture
    {
        get
        {
            return _curTexture;
        }
    }

    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();

        int count = _pSystem.GetParticles(_particles);

        for (int i = 0; i < count; ++i)
        {
            var particle = _particles[i];
            // transfer position to object space
            Vector3 position = Vector3.zero;
            if (_pSystem.main.simulationSpace == ParticleSystemSimulationSpace.Local)
            {
                position = particle.position;
            }
            else if (_pSystem.main.simulationSpace == ParticleSystemSimulationSpace.World)
            {
                position = transform.InverseTransformPoint(particle.position);
            }


            /// calculate correct scale factor
            Vector3 scaleFactor = Vector3.one;

            if (_pSystem.main.scalingMode == ParticleSystemScalingMode.Local)
            {
                scaleFactor.x /= _canvas.transform.localScale.x;
                scaleFactor.y /= _canvas.transform.localScale.y;
                scaleFactor.z /= _canvas.transform.localScale.z;
            }

            position.x *= scaleFactor.x;
            position.y *= scaleFactor.y;
            var size = particle.GetCurrentSize3D(_pSystem) * 0.5f;
            size.x *= scaleFactor.x;
            size.y *= scaleFactor.y;
            size.z = 0f;

            Color32 color = particle.GetCurrentColor(_pSystem);
            var uv = new Vector4(0, 0, 1, 1);
            _quad[0] = UIVertex.simpleVert;
            _quad[0].color = color;
            _quad[0].uv0 = new Vector2(0, 0);

            _quad[1] = UIVertex.simpleVert;
            _quad[1].color = color;
            _quad[1].uv0 = new Vector2(0, 1);

            _quad[2] = UIVertex.simpleVert;
            _quad[2].color = color;
            _quad[2].uv0 = new Vector2(1, 1);

            _quad[3] = UIVertex.simpleVert;
            _quad[3].color = color;
            _quad[3].uv0 = new Vector2(1, 0);

            var corner1 = position - size;
            var corner2 = position + size;
            
            _quad[0].position = new Vector2(corner1.x, corner1.y);
            _quad[1].position = new Vector2(corner1.x, corner2.y);
            _quad[2].position = new Vector2(corner2.x,corner2.y);
            _quad[3].position = new Vector2(corner2.x, corner1.y);
            vh.AddUIVertexQuad(_quad);
        }
    }
    void Update()
    {

        _pSystem.Simulate(Time.unscaledDeltaTime, false, false, true);
        SetVerticesDirty();
        //SetAllDirty();
    }
}

```
大体思路就是讲粒子面片刷到UI中去，使用canvasrender进行渲染，这样做的确可以方便UI的层级调整。
## 问题

问题主要还是出在效率上面吧，未来让OnPopulatedMesh每一帧被调用，于是Update中必须每一帧去SetVerticesDirty，导致Canvas的重新构建。
![non_script](assets/ugui_particlesystem/2020-05-23-080746.png)
可以看到，此时使用1000个粒子的效率。
然后我们使用脚本的方法看下1000个粒子的效率：
![with_script](assets/ugui_particlesystem/2020-05-23-081126.png)
可以看到，PostLateUpdate.PlayerUpdateCanvases这里会有额外消耗。
## 消耗解析

这里需要找下UGUI源码，定位到Graphics->Rebuild
```
  public virtual void Rebuild(CanvasUpdate update)
        {
            if (canvasRenderer == null || canvasRenderer.cull)
                return;

            switch (update)
            {
                case CanvasUpdate.PreRender:
                    if (m_VertsDirty)
                    {
                        UpdateGeometry();
                        m_VertsDirty = false;
                    }
                    if (m_MaterialDirty)
                    {
                        UpdateMaterial();
                        m_MaterialDirty = false;
                    }
                    break;
            }
        }
```
我们可以看到这里每一帧我们都需要UpdateGeometry，而这的确是我们的消耗大头。
最终代码定位到`canvasRender.SetMesh()`，接下来看不到源码了，没什么好的优化想法。

## 猜想
理论上这里知识构建一个简单的Mesh，然后去模拟粒子效果，当然，这里需要每一帧去创建Mesh，相比
粒子原来的Mesh变换会慢一定，但问题定位目前县搁置吧，以后有机会看到源码再研究下。
