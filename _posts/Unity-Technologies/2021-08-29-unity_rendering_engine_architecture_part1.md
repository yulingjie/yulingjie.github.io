---
layout: post
title : Unity Rendering Engine ARchitecture Part I
categories: [unity]
excerpt_separator: <!--more-->
---




## Principles

+ Performance reach: Scaling of high-end to low end
    -  intelligently
        - Without sacrificing performance whenever possible
        - Make "whenever possible" be as non-conservative as possible
        - Make smart performant choices without pushing constraints on crators
+ Enable the creator
        - Provide deep ability to customize but with solid table-stakes architecture ( don't ask to reinvent the wheel)
+ Enable quick iteration
+ Be Reliable
        - Whenever possible, keep content always working through the architecture evolution

<!--more-->
## Architecture

### Evolution
    
    Build-in Render Pipeline (BiRP) -> Scriptable Render Pipeline (SRP) -> Hybrid DOTS SRP

### Build-In Render Pipeline (BiRP)

+ Unity's single rendering pipeline prior to SRP
+ Targets mobile to console | PC | AR | VR
+ Supports forward | deferred rendering and decent variety of features
+ Convenience: One-stop shop for rendering
+ Turnkey solution for all platforms

### BiBP Challenges

+ Blackbox System
+ Locked down configuration
+ Bulk of code in c++ (not user-modifiable)
+ Prestructed render flow and render passes
+ Hardcoded rendering algorithm
+ Unconstrained customization makes achieving performance hard

### SRP Architecture Goals

+ Componentize the steps of rendering
+ Provide a rich set of building blocks and a way to composite or extend them
+ Separation of control of execution
+ Fast native inner loops for low-level rendering
+ Fast developer iteration

### SRP High-Level Concept

+ Invoke filtered drawcalls from script
+ Shaders can be designed for specific render pipelines
+ Combine with a list of visible objects | lights, etc.
+ Significantly simplifies high level code for render pipeline

### Scriptable Render Pipeline

+ Unity by default provides two concrete pipelines by default
    - Universal Render Pipeline (URP)
    - High Definition Render Pipeline (HDRP)
+ Users can build their own pipeline
    - Either by modifying existing URP and HDRP pipelines as the base
    - Or completely make your own

## Scriptable Render Pipeline Architecture

![srp architecture](/assets/srp/srp_architecture.png)

+ SRP fronted: scripting layer lives in userland where you can customize your rendering
+ grahpiics backed: core rendering lives - batching, graphics device interaction , etc
+ In Unity a shader is essentially an interface, and a material is a specific override of that interface with concrete properties

### SRP Batch Processing API

+ Submitting Individual draws from C# - SLOW
+ Controlling higher level rendering flow - Not so slow!
+ RenderContext - A proxy object that lives within our c++ layer but has a binding layer into c#

## How does Unity render a Frame
![srp unity frame](/assets/srp/srp_unity_frame.png)
+ Unity is a heavily main thread focused engine due to it's extensive c# callback based playerloop
    - very fast and easy to prototype with
    - needs extra attention when you are looking to scale up a project
+ A frame in Unity is build in a number of stages
    - Game Logic Section: non rendering systems and user script code is executed
    - Rendering
        1. Culling - Includes callbacks to userland code for visibility
        2. Performing the rendering algorithm (on the main thread in userland script code)
        3. Submitting the operations which includes figure out draw state, sorting, and calculating per object draw data (c++)
        4. Offloading the rendering command buffer to the render thread
![srp render call](/assets/srp/srp_render_call.png)

### Culling

+ perform a lot of mathematical heavy operations to get a renderable set of nodes
+ performant and paralyzable
+ call context.Cull

![srp culling](/assets/srp/srp_culling.png)

### SRP Toolbox

+ Render Graph
+ Render Pass API
+ Improved Batch operations
+ Improved Batching
+ Material overrides
+ Volume System
+ Texture Atlas System
    
### Submit Call
    Commands are passed to the render thread in a producer / consumer model where the graphics device backend can consume the commands in a platform specific way.
    Some backends directly submit the commands. Others use native graphics jobs to process the command stream.

## Hybrid DOTS SRP Architecture
    This new technology no longer supports the old build-in rendering pipeline(BiRP)
### DOTS Data-Oriented Tech Stack
    + Classic Object oriented data model -- runtime performance is lacking
    + DOTS ECS separates components to chunks of linear data
    + DOTS Jobs System provides fine grained task parallelism
    + Burst Compiler is a new C# auto-vectorizing compiler convering a C99 subset of the C# languge
    + iterative conversion from GameObjects to DOTS ECS
### SRP Batcher & DOTS Hybrid Renderer
    + building batches of compatible renderers to aoid the costly shader changes
    + SRP Batcher is fully separating the material storage an dupload from the high frequency draw loop. The material data is now persistent in the GPU memory and uploaded only when changed

### Hybrid Renderer
![srp hybrid renderer](/assets/srp/srp_hybrid_renderer.png)

+ GameObject convert to DOTS data. convert existing authoring GameObject data to efficient runtime data layout
+ DOTS ECS: Chunks and Arhcetypes. Entities are split to archetypes based on their component set.
+ DOTS ECS: Queries. The query processes through the selected component arrasy of each chunk. Only the components in the query are touched. Other unrelated data is not touched.
+ DOTS ECS: Version Tracking. maintain a version number to each component array in each chunk.

#### Hybrid Renderer Data Model: Backend

+ allocate persistent GPU memory for each GPU visible ECS component
+ use a large ByteAddressBuffers to store the ECS data in GPU side
+ "Graphics Archetype": a subset of the DOTS archetype, the same grahpics archetype has the same GPU data layout
+ query each chunk for modified data. run a job with access to mapped GPU upload heap pointer. copy actual data arrays from the modified chunkts to the GPU visible memory.
+ use a compute shader to go through the linear upload heap data array and scatter the modifications.

#### Data access

+ Traditional GPU instancing: 
    - needs to define a hardcoded set of properties that can be overriden per instance --- too larger set or too small set
    - compiling multiple shader variants for different data layouts --- combinaatorial explosion
    - create a metadata constant buffer for each (graphics archetype, material) combination.
    - this buffer contains the start offsets of each shader property data stream.
    - steal the high bit of the offset for a stride mask. force all instances to read from the same shared memory location, instead of reading from contiguous memory addresses
    - use arithmetic shift to replicate the mask bit and bnary AND to mask the instance id.

## Conclusion: Principles

+ Customizability
+ Scalability & Platform Reach
+ Performance
+ Fast Iteration
