---
layout: post
title: ECS初探-一个简单的例子
categories: [Unity-Technoligies]
tags: [unity]
excerpt_seperator: <!--more-->

---
# ECS初探

## ECS是什么
    ECS是基于DOTS理念的一套Unity逻辑框架。这个框架目前还在开发当中，在逐渐把之前的依稀OOP理念转到ECS的开发理念中。
    DOTS，Data Oriented Tech. Stack,与之前OOP的理念不同，将数据放在一起储存，方法放在另外的地方，而不是将数据与方法放在一起。
    ECS在这里指的是一套框架用来实现DOTS的理念。
    Entity，Component，System， Entity是指实体，指数据的集合，在Unity中是指Component的集合; Component这里指的是单纯的数据了，
与Unity之前的Component概念并不一致；System这里是用来处理数据的方法。

<!--more-->
## 简单的例子
    加载一个Cube，旋转它一定时间后，销毁这个Cube。
    按照OOP的理念，我们可以迅速的写出代码：
```
public class TestOOP : MonoBehaviour
{
    public Transform prefab;
    public float duration;
    public float rotateSpeed;

    private GameObject m_rtGoCube;
    // Start is called before the first frame update
    void Start()
    {
        m_rtGoCube = GameObject.Instantiate(prefab.gameObject,Vector3.zero, Quaternion.identity);
    }

    // Update is called once per frame
    void Update()
    {
        if(m_rtGoCube != null)
        {
            m_rtGoCube.transform.Rotate(1, rotateSpeed * Time.deltaTime,0);
        }
       if(duration >1.0f)
       {
           duration -= Time.deltaTime;
           if(duration <= 1.0f)
           {
               GameObject.Destroy(m_rtGoCube);
           }
       }
    }
}
```
    现在我们可以理出数据，实例化一个prefab，然后旋转并销毁这个操作需要如下数据：
```
    // 创建
    public Transform prefab; // 需要实例化的prefab
    public Vector3 worldPosition; // 实例话的prefab需要放的位置
    public Quaternion rotation; // 初始旋转角度
    // 旋转
    public float rotationSpeed; //选择速度
    public float duration; //选择持续时间
```
    ECS中，数据使用Component来表示。Component的集合称之为Entity。既然所有的数据都是Entity了，创建数据本身也需要是个Entity：
```
// 创建数据

public struct Spawner_Cube: IComponentData
{
    public Entity Prefab;
    public Vector3 startPosition;
    public Quaternion startRotation;
    public float rotationSpeed;
    public int duration;
}
```
    现在有了数据结构，需要解决：1 如何定义这两个数据；2 如何将这两个Component绑在一个Entity上； 3 如何获取数据然后使用。
    1 定义数据：目前看到的方法仍然是定义一个MonoBehaviour脚本，在上修改参数：
```
public class SpawnerAuthoring_Spawn: MonoBehaviour
{
    public GameObject  Prefab;
    public Vector3 startPosition;
    public Quaternion rotation;
    public int duration;
    public float rotationSpeed;
}
```
    2 如何绑定到Entity上，看了下需要挂ConvertToEntity脚本，实现接口` IDeclareReferencedPrefabs,IConvertGameObjectToEntity`:
    ```
public void DeclareReferencedPrefabs(List<GameObject> referencedPrefabs)
{
    referencedPrefabs.Add(Prefab);
}
public void Convert(Entity entity, EntityManager dstManager,
        GameObjectConversionSystem  conversionSystem)
{
    var spawnerData = new Spawner_Cube
    {
        Prefab = conversionSystem.GetPrimaryEntity(Prefab),
        startPosition = startPosition,
        startRotation = rotation,
        rotationSpeed = rotationSpeed,
        duration = duration,
    };
   
    dstManager.AddComponentData(entity, spawnerData);
}
```
    3 如何使用。ECS中使用是发生在System里，目前System继承自SystemBase。这里需要明确两个使用目的，一个是依据Entity数据创建这个Prefab，一个是旋转Cube一定时间然后摧毁它。 那么这里有两个System，Spawner与Rotator。
    依据Entity上的数据创建：
```
[UpdateInGroup(typeof(SimulationSystemGroup))] // 更新时序，这里意味着在SimulationSystemGroup这个Group里更新
public  class SpawnerSystem_Cube: SystemBase
{
    BeginInitializationEntityCommandBufferSystem m_EntityCommandBufferSystem; // EntityCommmandBuffer 的使用, 在创建Entity的时候必须通过EntityCommandBuffer来操作

    protected override void OnCreate()
    {
        m_EntityCommandBufferSystem = World.GetOrCreateSystem<BeginInitializationEntityCommandBufferSystem>(); // 初始化EntityCommandBuffer
    }

    protected override void OnUpdate()
    {
        var commandBuffer = m_EntityCommandBufferSystem.CreateCommandBuffer().AsParallelWriter(); // 需要在ForEach中操作CommandBuffer，需要调用AsParallelWriter
        // 遍历Entity找到具有Spawner_Cube数据与LocalToWorld数据的Entity
        Entities.ForEach((Entity entity, 
                int entityInQueryIndex, 
                in Spawner_Cube spawnerCube,
                in LocalToWorld localtion) => 
        {
            var instance = commandBuffer.Instantiate(entityInQueryIndex, spawnerCube.Prefab); // 创建一个Prefab Entity
            var position = math.transform(localtion.Value,
                    spawnerCube.startPosition);
            var rotation = math.rotate(localtion.Value, spawnerCube.startRotation.eulerAngles);
            commandBuffer.SetComponent(entityInQueryIndex, instance,
                    new Unity.Transforms.Translation{Value = position}); // 设置这个prefab entity的position属性
            
            commandBuffer.SetComponent(entityInQueryIndex, instance,
                    new Unity.Transforms.Rotation{ Value = Quaternion.Euler(rotation)}); // 设置这个prefab entity ritation 属性
            
            commandBuffer.DestroyEntity(entityInQueryIndex, entity); // 摧毁创建Entity, 保证这个Entity只创建一次
        }).ScheduleParallel();
       // 让BeginInitializationEntityCommandBufferSystem 感知当前System 
       m_EntityCommandBufferSystem.AddJobHandleForProducer(this.Dependency); 
    }
}
```
    `EntityCommandBufferSystem`是ECS框架内置的一套操作Entity的机制；
> The default World initialization provides three system groups, for initialization, simulation, and presentation, that are updated in order each frame. Within a group, there is an entity command buffer system that runs before any other system in the group and another that runs after all other systems in the group. Preferably, you should use one of the existing command buffer systems rather than creating your own in order to minimize synchronization points. See Default System Groups for a list of the default groups and command buffer systems
    这样，我们就可以将Prefab创建出来了。
    现在，需要实现旋转，需要做如下两件事：1 这个Prefab Entity 我们是没有添加Rotation Component的；2  需要创建一个System来便利这个Entity并旋转；
    为这个Entity添加Rotation Component：
```
// 新建立一个Rotation_Cube  Component
public struct Rotation_Cube: IComponentData
{
    public float rotationSpeed;
}
```
```
// 在Spawner System中修改Entity 的Component结构，添加Rotation_Cube Component
commandBuffer.AddComponent(entityInQueryIndex, instance,  
                    new Rotation_Cube{rotationSpeed = spawnerCube.rotationSpeed, duration = spawnerCube.duration});
```
    旋转这个Entity:
```
// 同样，创建一个RotationSpeedSystem， 遍历所有有Rotation 与 Rotation_Cube的 Entity进行旋转
public  class RotationSpeedSystem: SystemBase
{
    protected override void OnUpdate()
    {
        var deltaTime = Time.DeltaTime;

        Entities.WithName("RotationSpeedSystem")
            .ForEach((ref Rotation rotation, in Rotation_Cube rotationCube) =>
                    {
                        rotation.Value = math.mul(math.normalize(rotation.Value),
                                Quaternion.AngleAxis(
                                    rotationCube.rotationSpeed * deltaTime,
                                    math.up()));
                    }).ScheduleParallel();
    }
}
```
    最后，需要在旋转一段时间后销毁这个Prefab Entity，同样，需要一个Component来记录duration参数，并且需要一个System来使用duration并销毁;
    创建一个Component：
```
public struct Duration_Cube: IComponentData
{
    public float remainTime;
}
```
    并且在添加System 专门用来处理倒计时：
```
public class LifeTimeSystem: SystemBase
{
    Unity.Entities.EndSimulationEntityCommandBufferSystem m_Barrier;

    protected override void OnCreate()
    {
        m_Barrier = World.GetOrCreateSystem<EndSimulationEntityCommandBufferSystem>();
    }
    protected override void OnUpdate()
    {
        var commandBuffer = m_Barrier.CreateCommandBuffer().AsParallelWriter();
        var deltaTime = Time.DeltaTime;

        Entities.ForEach((Entity entity, int nativeThreadIndex, ref Duration_Cube lifetime)=>
                {
                    lifetime.remainTime -= deltaTime;
                    if(lifetime.remainTime < 0.0f)
                    {
                        commandBuffer.DestroyEntity(nativeThreadIndex, entity);
                    }
                }).ScheduleParallel();
    }
}

        m_Barrier.AddJobHandleForProducer(Dependency);
```

    至此，一个简单的ECS任务就完成了。
