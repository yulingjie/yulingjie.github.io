# 一个简单的ShadowMap

## 简述
使用Metal实现一个简单的shadowmap。
 1. 使用Metal实现Blin-Phong模型；
 2. 生成点光源的ShadowMap并实现阴影；

## 使用Metal实现Blin-Phong模型
细节网上比较多; 
![blinn_phong](/assets/blinn_phong/D255A71F-BC82-4D18-80A2-76C7B6946AED.png)

$$L_o(\theta_o,\phi_o)=\int_{\phi_i=0}^{2\pi}\int_{\theta_i=0}^{\pi/2}f(\theta_i,\phi_i,\theta_o,\phi_o)L(\theta_i,\phi_i)cos\theta_isin\theta_id\theta_id\phi_i$$

对物体的着色分为：环境光+漫反射+高光。

Metal模型的加载从官网的Demo上复制下
```
+ (nonnull id<MTLTexture>) createMetalTextureFromMaterial: (nonnull MDLMaterial*) material
                                  modelIOMaterialSemantic: (MDLMaterialSemantic) materialSemantic
                                    metalKitTextureLoader: (nonnull MTKTextureLoader*) textureLoader
{
    id<MTLTexture> texture;
    NSArray<MDLMaterialProperty*> *propertiesWithSemantic = [material propertiesWithSemantic:materialSemantic];
    
    for(MDLMaterialProperty * property in propertiesWithSemantic)
    {
        if(property.type == MDLMaterialPropertyTypeString || property.type == MDLMaterialPropertyTypeURL)
        {
            NSDictionary * textureLoaderOptions = @{
                MTKTextureLoaderOptionTextureUsage : @(MTLTextureUsageShaderRead),
                MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate),
                MTKTextureLoaderOptionSRGB : @(NO)
            };
            NSURL * url = property.URLValue;
            NSMutableString * URLString = nil;
            if(property.type == MDLMaterialPropertyTypeURL){
                URLString = [[NSMutableString alloc] initWithString:[url absoluteString]];
            }
            else{
                URLString = [[NSMutableString alloc] initWithString:@"file://"];
                [URLString appendString:property.stringValue];
            }
            
            NSURL* textureURL = [NSURL URLWithString:URLString];
            texture = [textureLoader newTextureWithContentsOfURL:textureURL options:textureLoaderOptions error:nil];
            
            if(texture){
                return texture;
            }
            
            NSString * lastComponent = [[URLString componentsSeparatedByString:@"/"] lastObject];
            texture = [textureLoader newTextureWithName:lastComponent scaleFactor:0 bundle:nil options:textureLoaderOptions error:nil];
            if(texture){
                return texture;
            }
            
            [NSException raise:@"Texture data for material property not found"
                        format:@"Requested material property semantic: %lu string:%@",
             materialSemantic, property.stringValue];
        }
    }
    [NSException raise:@"No appropriate material property from which to create texture"
                format:@"Requested material property semantic: %lu", materialSemantic];
    return nil;
}

- (nonnull instancetype) initWithModelIOSubmesh: (nonnull MDLSubmesh*) modelIOSubmesh
                                metalKitSubmesh:(nonnull MTKSubmesh*) metalKitSubmesh
                          metalKitTextureLoader:(nonnull MTKTextureLoader *)textureLoader
{
    self = [super init];
    if(self)
    {
        _metalKitSubmesh = metalKitSubmesh;
        _textures = [[NSMutableArray alloc] initWithCapacity:AAPLNumTextureIndices];
        for(NSUInteger shaderIndex = 0; shaderIndex < AAPLNumTextureIndices; shaderIndex ++)
        {
            [_textures addObject:(id<MTLTexture>)[NSNull null]];
        }
        @try {
            _textures[AAPLTextureIndexBaseColor] = [AAPLSubmesh createMetalTextureFromMaterial:modelIOSubmesh.material modelIOMaterialSemantic:MDLMaterialSemanticBaseColor metalKitTextureLoader:textureLoader];
        } @catch (NSException *exception) {
            NSLog(@"Failed to Load AAPLTextureIndexBaseColor, error %@", [exception description]);
        } @finally {
            
        }
        @try{
            _textures[AAPLTextureIndexSpecular] = [AAPLSubmesh createMetalTextureFromMaterial:modelIOSubmesh.material modelIOMaterialSemantic:MDLMaterialSemanticSpecular metalKitTextureLoader:textureLoader];
        } @catch (NSException * exception){
            NSLog(@"Failed to Load AAPLTextureIndexSpecular, error %@", [exception description]);
        } @finally{
            
        }
        @try{
            _textures[AAPLTextureIndexNormal] = [AAPLSubmesh createMetalTextureFromMaterial:modelIOSubmesh.material modelIOMaterialSemantic:MDLMaterialSemanticTangentSpaceNormal metalKitTextureLoader:textureLoader];
        } @catch (NSException * exception){
            NSLog(@"Failed to Load AAPLTextureIndexNormal, error %@", [exception description]);
        } @finally{
            
        }
      
        
    }
    return self;
}

@end

@implementation  AAPLMesh{
    NSMutableArray<AAPLSubmesh *> *_submeshes;
}
@synthesize  submeshes = _submeshes;

- (nonnull instancetype) initWithModelIOMesh: (nonnull MDLMesh*) modelIOMesh
                     modelIOVertexDescriptor: (nonnull MDLVertexDescriptor*) vertexDescriptor
                       metalKitTextureLoader: (nonnull MTKTextureLoader *) textureLoader
                                 metalDevice: (nonnull id<MTLDevice>) device
                                       error: (NSError *__nullable * __nullable)error
{
    self = [super init];
    if(!self){
        return nil;
    }
    // Have ModelIO create the tangents from mesh texture coordinates and normals
    [modelIOMesh addTangentBasisForTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate
                                              normalAttributeNamed:MDLVertexAttributeNormal
                                             tangentAttributeNamed:MDLVertexAttributeTangent];
    // Have ModelIO create bitangents from mesh texture coordinates and the newly created tangents
    [modelIOMesh addTangentBasisForTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate
                                             tangentAttributeNamed:MDLVertexAttributeTangent
                                           bitangentAttributeNamed:MDLVertexAttributeBitangent];
    
    modelIOMesh.vertexDescriptor = vertexDescriptor;
    
    MTKMesh* metalKitMesh = [[MTKMesh alloc] initWithMesh: modelIOMesh
                                                   device:device
                                                    error:error];
    _metalKitMesh = metalKitMesh;
    
    assert(metalKitMesh.submeshes.count == modelIOMesh.submeshes.count);
    
    _submeshes = [[NSMutableArray alloc] initWithCapacity:metalKitMesh.submeshes.count];
    
    for(NSUInteger index = 0; index < metalKitMesh.submeshes.count; ++index)
    {
        AAPLSubmesh * submesh = [[AAPLSubmesh alloc] initWithModelIOSubmesh:modelIOMesh.submeshes[index] metalKitSubmesh:metalKitMesh.submeshes[index] metalKitTextureLoader:textureLoader];
        
        [_submeshes addObject:submesh];
    }
    return self;
    
}

+ (NSArray<AAPLMesh*> *) newMeshesFromObject:(nonnull MDLObject*) object
                     modelIOVertexDescriptor:(nonnull MDLVertexDescriptor*) vertexDescriptor
                       metalKitTextureLoader:(nonnull MTKTextureLoader *) textureLoader
                                 metalDevice:(nonnull id<MTLDevice>) device
                                       error:(NSError * __nullable * __nullable) error
{
    NSMutableArray<AAPLMesh *> *newMeshes = [[NSMutableArray alloc] init];
    
    if([object isKindOfClass:[MDLMesh class]])
    {
        MDLMesh * mesh = (MDLMesh*) object;
        AAPLMesh *newMesh = [[AAPLMesh alloc] initWithModelIOMesh:mesh modelIOVertexDescriptor:vertexDescriptor metalKitTextureLoader:textureLoader metalDevice:device error:error];
        
        [newMeshes addObject:newMesh];
    }
    for(MDLObject* child in object.children)
    {
        NSArray<AAPLMesh*> *childMeshes;
        childMeshes = [AAPLMesh newMeshesFromObject:child
                            modelIOVertexDescriptor:vertexDescriptor
                              metalKitTextureLoader:textureLoader
                                        metalDevice:device
                                              error:error];
        [newMeshes addObjectsFromArray:childMeshes];
    }
    return newMeshes;
}

+ (nullable NSArray<AAPLMesh *> *) newMeshesFromURL:(NSURL *)url
                        modelIOVertexDesriptor:(MDLVertexDescriptor *)vertexDescriptor
                                         metalDeice:(id<MTLDevice>)device
                                              error:(NSError * _Nullable __autoreleasing *)error
{
    MTKMeshBufferAllocator * bufferAllocator = [[MTKMeshBufferAllocator alloc] initWithDevice:device];
    
    MDLAsset * asset = [[MDLAsset alloc] initWithURL:url
                                    vertexDescriptor:nil
                                     bufferAllocator:bufferAllocator];
    NSAssert(asset, @"Failed to open model file with given URL: %@", url.absoluteString);
    
    MTKTextureLoader * textureLoader = [[MTKTextureLoader alloc] initWithDevice:device];
    
    NSMutableArray<AAPLMesh*> *newMeshes = [[NSMutableArray alloc] init];
    
    for(MDLObject* object in asset)
    {
        NSArray<AAPLMesh*> *assetMeshes;
        
        assetMeshes = [AAPLMesh newMeshesFromObject:object
                             modelIOVertexDescriptor:vertexDescriptor
                               metalKitTextureLoader:textureLoader
                                         metalDevice:device
                                               error:error];
        [newMeshes addObjectsFromArray:assetMeshes];
    }
    return newMeshes;
}
```
设置PipelineState
```
 _mtlVertexDescriptor = [[MTLVertexDescriptor alloc] init];

    _mtlVertexDescriptor.attributes[VertexAttributePosition].format = MTLVertexFormatFloat3;
    _mtlVertexDescriptor.attributes[VertexAttributePosition].offset = 0;
    _mtlVertexDescriptor.attributes[VertexAttributePosition].bufferIndex = BufferIndexMeshPositions;

    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].format = MTLVertexFormatFloat2;
    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].offset = 0;
    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].bufferIndex = BufferIndexMeshGenerics;
    
    _mtlVertexDescriptor.attributes[VertexAttributeNormal].format = MTLVertexFormatHalf4;
    _mtlVertexDescriptor.attributes[VertexAttributeNormal].offset = 8;
    _mtlVertexDescriptor.attributes[VertexAttributeNormal].bufferIndex = BufferIndexMeshGenerics;

    _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stride = 12;
    _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stepRate = 1;
    _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stepFunction = MTLVertexStepFunctionPerVertex;

    _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stride = 16;
    _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stepRate = 1;
    _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stepFunction = MTLVertexStepFunctionPerVertex;

    
    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

    
    {
        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];

        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"MyPipeline";
        pipelineStateDescriptor.sampleCount = view.sampleCount;
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.vertexDescriptor = _mtlVertexDescriptor;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
        pipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
        pipelineStateDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;

        NSError *error = NULL;
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        if (!_pipelineState)
        {
            NSLog(@"Failed to create pipeline state, error %@", error);
        }
    

    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStateDesc.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];
    }
   
```
绘制
```
 for(__unsafe_unretained AAPLMesh * mesh in _meshes)
    {
        __unsafe_unretained MTKMesh *metalKitMesh = mesh.metalKitMesh;
        
        for(NSUInteger bufferIndex = 0; bufferIndex < metalKitMesh.vertexBuffers.count; bufferIndex++)
        {
            __unsafe_unretained MTKMeshBuffer * vertexBuffer = metalKitMesh.vertexBuffers[bufferIndex];
            if((NSNull*) vertexBuffer != [NSNull null])
            {
                [renderEncoder setVertexBuffer:vertexBuffer.buffer
                                        offset: vertexBuffer.offset
                                       atIndex:bufferIndex];
                
            }
        }
        for(AAPLSubmesh * submesh in mesh.submeshes)
        {
            MTKSubmesh *metalKitSubmesh = submesh.metalKitSubmesh;
            id<MTLTexture> texture = submesh.textures[AAPLTextureIndexBaseColor];
            
            
            [renderEncoder setFragmentTexture:submesh.textures[AAPLTextureIndexBaseColor] atIndex:AAPLTextureIndexBaseColor];
            
            
            [renderEncoder drawIndexedPrimitives:metalKitSubmesh.primitiveType
                                      indexCount:metalKitSubmesh.indexCount
                                       indexType:metalKitSubmesh.indexType
                                     indexBuffer:metalKitSubmesh.indexBuffer.buffer
                               indexBufferOffset:metalKitSubmesh.indexBuffer.offset];
        }
    }
```
shader
```

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColorInOut out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.texCoord = in.texCoord;
    out.normal = in.normal;
    out.worldPosition = uniforms.modelViewMatrix * position;
    float4 shadow_coord = (uniforms.shadowOrthographicMatrix * uniforms.shadowModelViewMatrix * position);
    out.shadow_uv = shadow_coord.xy;
    out.shadow_depth = half(shadow_coord.z);
    return out;
}
fragment float4 fragmentShader(ColorInOut in[[stage_in]],
                               constant Uniforms & uniforms [[buffer(BufferIndexUniforms)]],
                               texture2d<half> colorMap [[texture(AAPLTextureIndexBaseColor)]],
                               device AAPLPointLight * light_data [[buffer(BufferIndexLightsData)]])
{
    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
   
    half4 colorSample = colorMap.sample(colorSampler, in.texCoord.xy);
    
  
    return float4(colorSample);
}
```
显示模型的话用Games202的mari:
![normal](/assets/blinn_phong/20220619-161816.png)
换成Blinn-Phong
```
fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(AAPLTextureIndexBaseColor) ]],
                               device AAPLPointLight *light_data [[buffer(BufferIndexLightsData)]]
                               )
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
  
    half4 colorSample   = colorMap.sample(colorSampler, in.texCoord.xy);
   
    float3 color = float3(colorSample.xyz);
    
    float3 ambient = 0.05 * color;
    
    device AAPLPointLight &light = light_data[0];
    float3 fragPos = float3(in.worldPosition.xyz);
    float3 lightPos = float3(light.lightPosition.xyz);
    
    float3 lightDir = normalize(lightPos - fragPos);
    
    float3 normal = normalize(in.normal);
    
    float diff = max(dot(lightDir, normal), 0.0);
   
    float len = length(lightPos - fragPos);
    float light_atten_coff = light.lightIntensity / len;
    
   // float3 diffuse = diff * light_atten_coff * color;
    float3 diffuse = diff * light_atten_coff * color;
   
    float3 viewDir = normalize(uniforms.uCameraPos - fragPos);
    
    float spec = 0.0f;
    float3 reflectDir = reflect(-lightDir, normal);
    spec = pow(max(dot(viewDir, reflectDir),0.0), 35.0);
    
    float3 specular = uniforms.uKs * light_atten_coff * spec;

    return float4(pow((ambient + diffuse  + specular ), float3(1.0/2.2)),1.0);
    
}

```
![blinn_phong_mari](/assets/blinn_phong/20220619-163610.png)
Ambient
![ambient_mari](/assets/blinn_phong/20220619-164836.png)
Diffuse
![diffuse_mari](/assets/blinn_phong/20220619-164951.png)
Specular
![specular_mari](/assets/blinn_phong/20220619-165040.png)


## 使用Metal生成ShadowMap
原理不多赘述，从光源看物体生成ZBuffer信息。
```
 // Setup shadow pass
    {
        // render pass pipeline
        MTLPixelFormat shadowMapPixelFormat = MTLPixelFormatDepth32Float;
        
        id<MTLFunction> shadowVertexFunction = [defaultLibrary newFunctionWithName:@"shadow_vertex"];
        MTLRenderPipelineDescriptor * renderPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        renderPipelineDescriptor.label = @"Shadow Gen";
        renderPipelineDescriptor.vertexFunction = shadowVertexFunction;
        renderPipelineDescriptor.fragmentFunction = nil;
        renderPipelineDescriptor.depthAttachmentPixelFormat = shadowMapPixelFormat;
        renderPipelineDescriptor.vertexDescriptor = _mtlVertexDescriptor;
        
        NSError *error = NULL;
        _shadowGenPipelineState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:&error];
        if (!_shadowGenPipelineState)
        {
            NSLog(@"Failed to create ShowdowMap Gen pipeline state, error %@", error);
        }
        // depth state
        MTLDepthStencilDescriptor* depthStencilDesc = [MTLDepthStencilDescriptor new];
        depthStencilDesc.label = @"Shadow Gen";
        depthStencilDesc.depthCompareFunction = MTLCompareFunctionLessEqual;
        depthStencilDesc.depthWriteEnabled = YES;
        _shadowDepthStencilState = [_device newDepthStencilStateWithDescriptor:depthStencilDesc];
        
        // shadow map
        MTLTextureDescriptor * shadowTextureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:shadowMapPixelFormat width:2048 height:2048 mipmapped:NO];
        shadowTextureDesc.resourceOptions = MTLResourceStorageModePrivate;
        shadowTextureDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        _shadowMap = [_device newTextureWithDescriptor:shadowTextureDesc];
        _shadowMap.label = @"Shadow Map";
        
        // render pass descriptor
        _shadowRenderPassDescriptor = [MTLRenderPassDescriptor new];
        _shadowRenderPassDescriptor.depthAttachment.texture = _shadowMap;
        _shadowRenderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
        _shadowRenderPassDescriptor.depthAttachment.storeAction = MTLStoreActionStore;
        _shadowRenderPassDescriptor.depthAttachment.clearDepth = 1.0;
        
    }
```
渲染阴影
```
 id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_shadowRenderPassDescriptor];
    renderEncoder.label = @"Shadow Map Pass";
    [renderEncoder setRenderPipelineState:_shadowGenPipelineState];
    [renderEncoder setDepthStencilState:_shadowDepthStencilState];
    [renderEncoder setCullMode:MTLCullModeBack];
    [renderEncoder setVertexBuffer:_dynamicUniformBuffer offset:_uniformBufferOffset atIndex:BufferIndexUniforms];
    
    [self drawMeshes:renderEncoder];
    [renderEncoder endEncoding];
```
```
vertex ColorInOut shadow_vertex(Vertex in[[stage_in]],
                                constant Uniforms & uniforms[[buffer(BufferIndexUniforms)]])
{
    ColorInOut out;
    
    float4 position = float4(in.position, 1.0);
    out.position = uniforms.shadowOrthographicMatrix * uniforms.shadowModelViewMatrix * position;
    out.texCoord = in.texCoord;
    out.normal = in.normal;
    
    return out;
}
```
![shadow_map](/assets/blinn_phong/20220619-181739.png)
这里需要注意的是，阴影使用正交投影，矩阵的选择影响了阴影区域的大小和最终精度。

```

fragment float4 fragmentShader_Shadow(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(AAPLTextureIndexBaseColor) ]],
                               device AAPLPointLight *light_data [[buffer(BufferIndexLightsData)]],
                               texture2d<half> shadowMap [[texture(AAPLTextureIndexShadowMap)]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
  
    half4 colorSample   = colorMap.sample(colorSampler, in.texCoord.xy);
    constexpr sampler shadowSampler(coord::normalized,
                                    filter::linear,
                                    mip_filter::none,
                                    address::clamp_to_edge);
    float visibility = 1.0;
    half4 shadowSample = shadowMap.sample(shadowSampler, (-in.shadow_uv + float2(1.0,1.0)) /2.0 );
    
    //return float4(shadowSample);
    if(shadowSample.z < in.shadow_depth - 0.005)
    {
        visibility = 0.0;
    }
    float3 color = float3(colorSample.xyz);
    
    float3 ambient = 0.05 * color;
    
    device AAPLPointLight &light = light_data[0];
    float3 fragPos = float3(in.worldPosition.xyz);
    float3 lightPos = float3(light.lightPosition.xyz);
    
    float3 lightDir = normalize(lightPos - fragPos);
    
    float3 normal = normalize(in.normal);
    
    float diff = max(dot(lightDir, normal), 0.0);
   
    float len = length(lightPos - fragPos);
    float light_atten_coff = light.lightIntensity / len;
    
   // float3 diffuse = diff * light_atten_coff * color;
    float3 diffuse = diff * light_atten_coff * color;
   
    float3 viewDir = normalize(uniforms.uCameraPos - fragPos);
    
    float spec = 0.0f;
    float3 reflectDir = reflect(-lightDir, normal);
    spec = pow(max(dot(viewDir, reflectDir),0.0), 35.0);
    
    float3 specular = uniforms.uKs * light_atten_coff * spec;
    
    //return float4(visibility,visibility,visibility,1.0);
    //return float4(ambient + diffuse + specular, 1.0);
    return float4(pow((ambient + diffuse * visibility + specular * visibility), float3(1.0/2.2)),1.0);
    
}

```
![hard_shadow](/assets/blinn_phong/20220619-182137.png)
这样，我们的硬阴影就有了。