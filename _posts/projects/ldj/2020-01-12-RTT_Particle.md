---
layout: post
title : Particle System rendered on Unity RT Image
categories: [projects, ldj]
excerpt_separator: <!--more-->
---

# 粒子效果在RT上的显示

本文目的: 对于项目中遇到的的在RT上显示特效的问题进行总结。

<!--more-->

## 综述

项目最近需要在组队页面添加个星盘系统，所谓星盘，就是一大堆特效悬浮在人的周围。由于组队页面一直采用的是RT的方法进行显示，使用特效后，会出现局部黑片，效果非常差。这里探索下对应的处理方案。

由于本篇文章总结的性质，这里把问题单独提出来研究。

特效效果![operation 1](/assets/unity_rtt/2020_01_12_20_03.14.bmp)。

问题特效的结构![operation 2](/assets/unity_rtt/2020_01_12_20_20.35.bmp)

可以看到，对应的粒子的底图是黑色的。

现在先禁用其它的特效，只留下单独的*lizi_1001*，我们可以看到单独的一个粒子的效果![operation 3](/assets/unity_rtt/2020_01_12_20_34.42.bmp)，当然这个效果是不正确的，我们需要对此 做出一些探究。

## Shader

我们先来看下这个粒子效果的材质![operation 4](/assets/unity_rtt/2020_01_12_20_37.27.bmp)。

这个粒子效果是由两个材质构成的，其中*glow_2009*对应着粒子图片的显示，而*huahen_0001_a_01*则对应着拖尾效果。我们主要看下在粒子图片的显示上。

*glow_2009*使用了AddParticles的Shander：

```glsl
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Artist/Effect/Add Particles" {
Properties {
	_Brightness ("Brightness", Float) = 1.0
	_TintColor ("Tint Color", Color) = (0.5,0.5,0.5,0.5)
	_MainTex ("Particle Texture", 2D) = "white" {}
	//_InvFade ("Soft Particles Factor", Range(0.01,3.0)) = 1.0
}

Category {
	Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
	
	Blend SrcAlpha One
	AlphaTest Greater .01
	ColorMask RGBA
	Cull Off Lighting Off ZWrite Off Fog { Color (0,0,0,0) }
	BindChannels {
		Bind "Color", color
		Bind "Vertex", vertex
		Bind "TexCoord", texcoord
	}
	
	// ---- Fragment program cards
	SubShader {
		LOD 150
		Pass {
		
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			//#pragma fragmentoption ARB_precision_hint_fastest
			//#pragma multi_compile_particles

			#include "UnityCG.cginc"

			sampler2D _MainTex;
			fixed4 _TintColor;
			float _Brightness;
			
			struct appdata_t {
				float4 vertex : POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
			};

			struct v2f {
				float4 vertex : POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
				/*#ifdef SOFTPARTICLES_ON
				float4 projPos : TEXCOORD1;
				#endif*/
			};
			
			float4 _MainTex_ST;

			v2f vert (appdata_t v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				/*#ifdef SOFTPARTICLES_ON
				o.projPos = ComputeScreenPos (o.vertex);
				COMPUTE_EYEDEPTH(o.projPos.z);
				#endif*/
				o.color = v.color;
				o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
				return o;
			}

			//sampler2D _CameraDepthTexture;
			//float _InvFade;
			
			fixed4 frag (v2f i) : COLOR
			{
				/*#ifdef SOFTPARTICLES_ON
				float sceneZ = LinearEyeDepth (UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos))));
				float partZ = i.projPos.z;
				float fade = saturate (_InvFade * (sceneZ-partZ));
				i.color.a *= fade;
				#endif*/
				
				i.color.rgb *= _Brightness;
				return 2.0f * i.color * _TintColor * tex2D(_MainTex, i.texcoord);
			}
			ENDCG 
		}
	} 	
	
	// ---- Dual texture cards
	/*SubShader {
		Pass {
			SetTexture [_MainTex] {
				constantColor [_TintColor]
				combine constant * primary
			}
			SetTexture [_MainTex] {
				combine texture * previous DOUBLE
			}
		}
	}
	
	// ---- Single texture cards (does not do color tint)
	SubShader {
		Pass {
			SetTexture [_MainTex] {
				combine texture * primary
			}
		}
	}*/
}
}

```

Shader比较简单，这里做个简要的说明：

+ 这个Shader使用来显示`Transparent`的物体的，并采用的混合模式`Blend SrcAlpha One`，这个混合模式正好是*Add Particles*，即在原有的颜色的基础上加上当前的颜色。

+ `ColorMask RGBA`，这表示当前的Shader输出颜色和透明度。

+ `BindChannels`这个是Legacy的语法了，这里不起作用。

+ 这个Shader只有一个通道，顶点对应着`vert`，着色对应着`frag`。

+ 顶点函数基本上只是转了下位置坐标空间，`UnityObjectToClipPos`，并且拿了下uv的位置`o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex)`。

  + `TRANSFORM_TEX`这个函数单独说下，这是Unity定义的一个宏，定义为

    ```glsl
    // Transforms 2D UV by scale/bias property
    #define TRANSFORM_TEX(tex,name) (tex.xy * name##_ST.xy + name##_ST.zw)
    ```

+ fragment函数这里也只是做了个简单的颜色计算，附上了_Brightness这个属性。



从Shader这里我们可以看到，这个粒子效果是输出了Alpha值的，但是我们截下RT的alpha看下：

![operation 5](/assets/unity_rtt/2020_01_12_21_11.28.bmp)

可以看到，

对应的位置的Alpha为全白的，即这里我们输出的Alpha值为1。那么自然，用这张图的UI图片在这个位置输出的是黑块了。

## 实验 关闭Alpha通道的输出

当我们关闭Alpha通道的输出时，`ColorMask RGB`，此时粒子效果干脆都不显示了。

![operation 6](/assets/unity_rtt/2020_01_12_21_24.07.bmp)

这里应该是因为，Alpha通道没有输出，默认直接设置为0了，经过RT这里直接就是不显示了。

## 问题定位

现在问题就比较好理解了。黑块对应的位置的Alpha值为1。但从Shader来看，我们是输出了Alpha值的，那只有可能是图片问题了。

我们定位到图片：

![operation 7](/assets/unity_rtt/2020_01_12_21_28.12.bmp)

可以看到，这张图片是带Alpha通道的，我们看下Alpha通道的值：

![operation 8](/assets/unity_rtt/2020_01_12_21_30.55.bmp)

那么这个问题是美术的资源制作问题了，通知美术改下就好了。

