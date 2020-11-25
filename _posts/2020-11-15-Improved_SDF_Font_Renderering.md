---
layout: post
title: SDF 字体渲染初探
categories: [工程]
excerpt_seperator: <!--more-->
tags: [TMP, SDF]
---
最近在看SDF字体渲染相关算法，从论文[Improved Alpha-Tested Magnification for Vector Textures and Special Effects](https://steamcdn-a.akamaihd.net/apps/valve/2007/SIGGRAPH2007_AlphaTestedMagnification.pdf "Improved Alpha-Tested Magnification")开始。

## 原理概述
二维平面上字体由一个封闭的区域形成，通过记录这个区域上每个像素点到外部区域的距离，我们可以将这个几何体的几何信息记录下来。在使用时，通过已经记录的信息来进行渲染。

## SDF生成
对目标图的每一个像素，计算源图上这个像素的distance值，直接遍历计算：
```
 void GenerateSDF64(Texture2D srcTexture, Texture2D dstTexture)
    {
        var colors = srcTexture.GetPixels();
        byte[] dst = new byte[dstTexture.width * dstTexture.height];
        int srcW = srcTexture.width;
        int srcH = srcTexture.height;
        int dstW = dstTexture.width;
        int dstH = dstTexture.height;
        int dx0 = 0;
        int dx1 = dstW;
        int dy0 = 0;
        int dy1 = dstH;
        int downScale = srcW / (dstW );
        for(int dy = dy0; dy < dy1;++dy)
        {
            int sy0 = (dy ) * downScale ;
            int sy1 = (dy + 1) * downScale ;
            float cy = (dy  ) * downScale;
            for(int dx = dx0; dx < dx1; ++dx)
            {
                int sx0 = (dx ) * downScale;
                int sx1 = (dx + 1) * downScale ;
                float cx = (dx ) * downScale;
                float d0 = 1e22f;
                float d1 = 1e22f;
                //var cl = (colors[(int)(cx + cy * srcW)]) ;
                //UnityEngine.Debug.LogFormat("r = {0} g = {1} b = {2} a = {3}",cl.r, cl.g, cl.b, cl.a);
                //UnityEngine.Debug.LogFormat("dy = {0} dx = {1} sx0 = {2} sx1 = {3} sy0 = {4} sy1 ={5} cx = {6} cy = {7}", dy, dx,sx0, sx1,sy0,sy1,cx,cy);
                for(int sy = sy0; sy <= sy1; ++sy)
                {
                    float yp = sy + 0.5f;
                    for(int sx = sx0; sx <= sx1; ++sx)
                    {
                        float xp = sx + 0.5f;
                        float d = (cx - xp) * (cx - xp) + (cy - yp) * (cy - yp);
                        float p = 0;
                        if(sx >= 0 && sx < srcW && sy >=0 && sy < srcH)
                        {
                            int index = sx + sy * srcW;
                            //UnityEngine.Debug.LogFormat("index = {0}, sx = {1} sy = {2}",index,sx, sy);
                            var c = colors[sx + sy * srcW];
                            if(c == Color.white)
                            {
                                p =1;
                            }
                            //if(p > 0f)
                             //   UnityEngine.Debug.LogFormat("c.r = {0} + c.g = {1} + c.b = {2}",c.r, c.g, c.b);
                        }
                        if (p > 0f)
                            d0 = Mathf.Min(d0, d);
                        else
                            d1 = Mathf.Min(d1, d);
                        //                if(sx >=0 && sx <
                        //UnityEngine.Debug.LogFormat("sy = {0} sx = {1}", sy, sx);
                    }
                }
                float dd = 0;
                if(d1 < d0)
                {
                    // outside
                    dd = Mathf.Max(0.0f, Mathf.Min(127.5f, Mathf.Sqrt(d0)));
                    dst[dx + dy * dstW] = (byte)(127.5f - dd );

                    //UnityEngine.Debug.LogFormat("compress {0} {1} to {2} outside",dx,dy,dd);
                }
                else
                {
                    // inside
                    dd = Mathf.Max(0.0f, Mathf.Min(127.5f, Mathf.Sqrt(d1)));
                    dst[dx + dy * dstW] = (byte)(127.5f + dd );

                    //UnityEngine.Debug.LogFormat("compress {0} {1} to {2} inside",dx,dy,dd);
                }
           //     UnityEngine.Debug.LogFormat("dx ={0} dy = {1} d0 = {2} d1 = {3}",dx, dy, d0, d1);
            }
        }
        for(int i = 0 ; i < dstW; ++i)
        {
            for(int j = 0; j < dstH; ++j)
            {
                var c = dst[ i + j *dstW];
                dstTexture.SetPixel(i,j, new Color(0, 0,0,c/255.0f));
            }
        }
    }
```
当前生成256x256大小的图片，64大小的效果变形严重。
![256_dst](assets/textmeshpro/256_dst.png)
一张Alpha8格式的图。每个像素点记录着这个点到外部区域的最短距离。
## 渲染
直接可以设置alpha > 0.5 来作为clip的边界。
![alpha_clip_0.5](assets/texmeshpro/alpha_clip_0.5.png)
可以看到，此时边界的锯齿还是比较明显的。
对边界做平滑处理。
```
fixed distance = tex2D(_MainTex, i.texcoord0).a;

fixed4 color = _FaceColor;
float alpha = smoothstep(_DstMin, _DstMax,distance);
color *= alpha;
return color;

```
效果 ![smooth_step](assets/textmeshpro/smoothstep.png)

outline效果的实现。
对于边界处0.5左右做一个黑色描边即可。
```
float outlineFactor = smoothstep(_DstMin, _DstMax, distance);
fixed4 color = lerp(_OutlineColor, _FaceColor, outlineFactor);
float alpha = smoothstep(_OutlineMin, _OutlineMax, distance);
//float alpha = 1.0;
return fixed4(color.rgb, color.a * alpha);

```
在`< _DstMin`的像素点全部画OutLine Color，在`_DstMin ,_DstMax`之间做渐变，在`>_DstMax`处画FaceColor,
限制alpha值即可：

![outline](assets/textmeshpro/outline.png)


shadow效果的实现。
shadow 可以理解为在偏移处再画一遍就好了。
![shadow_offset](assets/textmeshpro/shadow_0.01.png)
```
float alpha = smoothstep(_DstMin, _DstMax, distance);
fixed4 text = fixed4(_FaceColor.rgb, _FaceColor.a * alpha);
float shadowDistance = tex2D(_MainTex, i.texcoord0 - _ShadowOffset).a;
float shadowAlpha = smoothstep(_ShadowMin, _ShadowMax, shadowDistance);
fixed4 shadow = fixed4(_ShadowColor.rgb, _ShadowColor.a * shadowAlpha);
return lerp
```
结果：
![shadow_result](assets/textmeshpro/shadoww.png)


glow效果的实现。
论文中的glow效果比较简单，与shadow类似，在文字位置再画一次GlowColor,叠加在一起：
效果：
![glow](assets/textmeshpro/glow.png)


## 结语
本文较为简单的实现了一遍论文内容，对SDF算法做了个初步的认知。目前的实现会有较大的信息丢失，更为精细的实现可以参考TextMeshPro实现。








