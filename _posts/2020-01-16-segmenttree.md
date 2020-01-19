---
layout: post
title : segment tree
exceprt_seperator: <!--more-->

---
# segment tree
本文的目的，归纳整理segment tree这个数据结构的使用。参考codeforces的[链接
1](https://codeforces.com/blog/entry/15729)和[链接2](https://codeforces.com/blog/entry/18051)以及[链接3](https://codeforces.com/blog/entry/15890)。

<!--more-->
## 基本结构
先考虑2的k次幂,这个比较好理解。
考虑数组[0,16)：
[!operation 1](/assets/segmenttree/basic.png)
这里使用完全二叉树来存数据，对任意一个节点[l,r)都有指向[l,(l+r)/2)和[(l+r)/2,r)的子节点。
由于是使用数组储存完全二叉树的情况，对于序号为k的节点，其字节点指向序号为k*2和k*2 +1的节点。

### split
对任意一段区间[x,y)记为S，我们需要将这个区间分割到相应的节点上；比如说对于区间[3,10),我们应当将这个区间分割到节点19(3)、节点5([4,8))和节点12([8,10)).
这样，我们做运算的时候，只需要动这三个节点就好了。
```
//递归版本
vector<s>;
void split(int x, int y, int id =1,int l =0, int r = n)
{
    if( x >= r or l>=y) return; // [l,r)与[x,y)不相交。
    if(x <= l && r <= y)
    {
        s.push_back(id);
        return;
    }
    int mid = (l + r)/2;
    split(x,y,id*2,l,mid);
    split(x,y,id*2+1,mid,r);
}
```
递归的代码比较容易理解。我们从树根开始开始二分遍历，只有节点所表示的区间落在[x,y)内部的时候，我们才会采纳这个节点，这个节点不需要进一步细分了。

运行时间：直接从示意图上考虑， 我们split区间[l,r)时，[l,r)覆盖的一定是图上高度越高的内部节点，加上不超过两个的叶子节点，那么显然，时间是O(lgn)的。

```
//迭代版本
vector<s>;
void split(int x, int y,int n)
{
    int l = x;
    int r = y;
    for(l +=n, r+=n ; l< r; l >>= 1, r >>= 1)
    {
        if(l&1) s.push_back(l++);
        if(r&1) s.push_back(--r);
    }
}
```
迭代版本就难理解多了。迭代版本是自底向上的:
    + 首先解析 `l+=n, r+=n`这句，由于我们是使用数组储存的完全二叉树，那么叶子节点所在的序号即为l+n,r+n.
    + 如果l是右子节点，那么l的父亲节点一定包含[x,y)之外的区间，我们应采纳l节点，同时l++;
    + 如果r是右子节点，那么[x,y)区间应该落在r节点的左侧，此时我们应当采纳--r这个节点。

不管怎么说，这两个版本所要实现的功能是一致的。

### build
```
//递归版本
void build(int id =1, int l =0, int r = n)
{
    if(r - l< 2)
    {
        s[id]= a[l];
        return;
    }
    int mid = (l + r)/2;
    build(id *2 , l ,mid);
    build(id*2+1,mid,r);
    s[id] = s[id *2] + s[id*2 +1];
}
```
```
// 迭代版本
void build()
{
    // 预先在t[n,2n)间存储了叶节点数据。
    for(int i =0; i< n; ++i) scanf("%d", t + n + i);

    for(int i = n-1; i>0; --i)
    {
        t[i] = t[i<<1] + t[i<<1|1];    
    }
}

```
### modify
```
// 递归版本
void modify(int p,int x, int id =1,int l =0, int r= n)
{
    s[id] += x - a[p];
    if(r - l< 2)
    {
        a[p] = x;
        return;
    }
    int mid = (l + r)/2;
    if( p< mid)
    {
        modify(p,x,id*2,l,mid);
    }
    else
    {
        modify(p,x,id*2 +1,mid, r);
    }
}
```
```
// 迭代版本
void modify(int p, int value)
{
    for(t[p +=n] = value; p> 1;p>>=1) t[p>>1] = t[p] + t[p^1];
}
```
### sum
```
// 递归
int sum(int x, int y, int id=1, int l =0, int r=n)
{
    if(x >=r || l>=y) return 0;
    if(x<=l &&  r <= y) return s[id];
    int mid =(l + r)/2;
    return sum(x,y,id*2,l, mid)
    + sum(x,y,id*2+1,mid,r);
}

// 迭代
int sum(int l, int r)
{
    int res = 0;
    for(l +=n, r+=n; l< r; l >>= 1 , r>>=1)
    {
        if(l&1) res += t[l++];
        if(r&1) res += t[--r];
    }
    return res;
}
```

### lazy propagation
延迟更新，只在合适的时候才去更新数据。
比如说，我们需要将[l,r)这个区间段内的数据统统加x,我们不用逐个将每个数据加x，而是使用一个额外数组记录，在需要的时候，再加上:

直接看原版代码不太好理解，这里做个简单的推导。
```
// 对于节点id,区间为[l,r)的所有数据加x
// s[id]我们仍然储存这个区间的和，但同时，我们使用lazy[id]来储存需要变更的数据x，但是具体的区间上我们并不去做更新
// 事实上，更新x目前止于节点id.
void upd(int id,int l,int r,int x)
{
    lazy[id] += x;
    //s[id] += (r-l) * x;
}
void shift(int id, int l, int r)
{
    int mid = (l + r)/2;
    upd(id*2,l ,mid, lazy[id]);
    upd(id*2+1,mid, r, lazy[id]);
    lazy[id] = 0;
}
// 这里把计算sum的步骤分离出来了
// 更新区间数据时，我们只更新对应节点的数据
void increase(int x, int y,int v, int id =1,int l = 0,int r = n)
{
    if(x >= r or l >= y) return;
    if(x <= l && r <= y)
    {
        upd(id, l,r,v); // 同split一样，当节点的区间[l,r)在[x,y)之间时，我们停止向下更新节点数据了
        return; 
    }
    // shift(id, l,r); //这里稍微改动下
    int mid = (l + r)/2;
    increase(x, y, v, id*2,l,mid);
    increase(x,y,v,id*2 +1,mid,r);
    //s[id] = s[id*2] + s[id*2+1] ; //更新sum数据

}
```
在increase时我们标记了一些列需要更新数据的节点，但此时，如果我们直接取s[id]的话，是错误的。
考虑此时我们需要调用sum对区间[x,y)进行求值，首先，我们希望，在求值的时候，如果有碰到lazy[id]不为0的节点的话，我们能将这个节点的sum更新了,当然，这个节点的父节点也同样要更新。
```
// 初次尝试
int sum(int x, int y,int id= 1, int l =0, int r = n)
{
    if(x >= r || l>=y) return 0;
    if(x <=l && r <=y) 
    {
        s[id] += (lazy[id]* (r-l));
        //lazy[id] = 0; 此时节点id的sum值虽然更新了，但是我们并没真的更新每个叶节点，所以我们必须留着lazy[id]
        return s[id];
    }
    int mid = (l + r)/2;
    return sum(x,y,id*2, l,mid) +
        sum(x,y,id*2 +1 ,mid ,r);
}
```
可以看到，第一次sum的时候我们成功更新了s[id]的数据，但下次查询之前，lazy[id]必须要清除为0。这意味着，如果某个节点id标记了lazy[id],那么在第一次访问这个节点的s[id]时，我们要同时将s[id]更新到正确的值并且将lazy[id]清除为0.
我们对任意一节点分析下lazy[id]的情况：
+ 如果这个节点时叶节点，清楚lazy数据即可；
+ 如果这个节点是某个内部节点的话，记得我们设置lazy的方法，是从根节点往下设置的，那么，我们必须同时去设置这个节点的子节点，即id*2 与 id*2 +1这两个节点。

```
// 第二版
//在更新sum时，我们同时清楚lazy数据
int sum(int x, int y, int id=1, int l = 0, int r = n)
{
    if(x >= r|| l >= y) return 0;
    if( x <= l && r <= y)
    {
        s[id] += (lazy[id] * (r-l));
        shift(id,l,r);
        return s[id];
    }
    int mid = (l + r)/2;
    return sum(x,y,id*2, l,mid) + sum(x,y,id*2 +1,mid,r);
}
```
这样，sum数据的确更新成功，lazy数据也传导到子节点了，但是，我们发现，递归调用的中间路径上，遇到的内部节点的lazy[id]并没用做任何操作，而且，就我们设置lazy的方法来说，我们设置节点的子节点并没有设置lazy数据，换句话说，我们计算sum时，极有可能某个节点明明其父亲节点已经设置过了lazy了，但是由于我们并没有让lazy数据propagate down，在这个子节点上的sum数据获取是错误的。

再回到我们第二版的sum函数，我们是自顶向下进行split的，这意味着，我们可以将lazy数据自上向下传播开来。
```
// 我们需要一个只传播lazy数据，但是不重设lazy数据的函数
void shiftnoreset(int id, int l, int r)
{
    int mid = (l + r)/2;
    upd(id*2,l ,mid, lazy[id]);
    upd(id*2+1,mid, r, lazy[id]);
    //lazy[id] = 0;
}

// 第三版，在sum时，我们自顶向下的将lazy数据传播开来
int sum(int x,int y ,int id = 1,int l =0 ,int r = n)
{
    if(x >= r ||  l >= y) return 0;
    if( x <= l && r <= y)
    {
        s[id] += (lazy[id] * (r-l));//只在这里清除了lazy
        shift(id,l,r);
        return s[id];
    }
    shiftnoreset(id,l,r);
    int mid = (l + r)/2;
    return sum(x,y,id*2, l,mid) + sum(x,y,id*2 +1,mid,r);
}
```
第三版，虽然我们将lazy数据传播开来了，但是，我们只在最终节点处清楚了lazy数据，对于路径上的其它内部节点，下次再次访问的时候，必然会出现lazy的重复计算的问题。
```
// 第四版，我们将lazy数据传播开来后，计算sum值，更新sum[id],那么此时的lazy[id]就不再有用了，可以方心清零了。
int sum(int x, int y, int id=1, int l =0, int r = n)
{
    if(x >= r|| l >= y) return 0;
    if(x <= l && r <= y)
    {
        s[id] += (lazy[id] * (r-1));
        shift(id,l,r);
        return s[id];
    }
    shift(id,l,r);// 我们传播开来lazy后就直接清零了
    int mid = (l + r)/2;

    s[id] =  sum(x,y,id*2, l,mid) + sum(x,y,id*2 +1,mid,r);
    return s[id];
}
```
现在我们来研究下原版的代码：
```
void upd(int id, int l, int r, int x)
{
    lazy[id] += x;
    s[id] += (r - l) *x;
}   
void shift(int id,int l, int r)
{
    int mid = (l + r)/2;
    upd(id *2 , l ,mid,lazy[id]);
    upd(id*2+1,id, r, lazy[id]);
    lazy[id] = 0;
}
void increase(int x,int y,int v, int id=1,int l =0, int r =n)
{
    if(x >= r|| l >= y) return;
    if(x<= l || r <= y) 
    {
        upd(id, l,r, v);
        return ;
    }
    shift(id ,l ,r);
    int mid = (l + r)/2;
    increase(x, y, v, id*2 l ,mid);
    increase(x, y ,v, id*2 +1, mid,r);
    s[id] = s[id*2] + s[id*2+1];
}
int sum(int x,int y, int id = 1, int l = 0,  int r = n)
{
    if(x >= r || l >= y) return 0;
    if(x<= l && r <=y ) return s[id];
    shift(id,l,r);
    int mid = (l+r)/2;
    return sum(x, y, id*2, l ,mid) + sum(x, y,id*2 +1, mid,r);
}

```
这里使用下图的结构，选择更新[0,8)这个区间+1,来研究下,不妨设原来的所有数据都是0。
[!operation 2](/assets/segmenttree/basic.png)

+ 从根节点[0,16)入手，更新lazy[1]到节点2与节点3。此时lazy[1] =0,所以没有任何变化；
+ 进入左侧子节点[0,8),我们此时进入终止逻辑，更新节点2的lazy数据，lazy[2] = 1,更新sum值，s[2] += (8 - 0) * 1 ;
+ 右侧的不做任何更新，循环停止。

我们可以看到，此时，除了终止节点，所有路径上的内部节点均更新过了sum值，且lazy数据均为0。
对于终止节点和终止节点之下的节点数据，在没有访问到时，我们可以放心的不管它，而在访问到时，我们进入sum函数逻辑。

假设我们需要求sum(2,3)的值。

+ 我们从节点2开始lazy数据一路向下传播，更新节点4与5，5不向下传播了；
+ 节点4继续，更新节点8与节点9，8不继续向下传播了；
+ 节点9注意到，直接返回s[id]了。这几个节点的sum数据在lazy传播过来的同时就更新了，所以这个数据时正确的。

于是，我们得到正确的答案。


