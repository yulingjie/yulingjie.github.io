---
layout: post
title : C.Sereja and Brackets
categories: [算法]
exceprt_seperator: <!--more-->

---

趁热打铁，深入理解segment tree算法。参考文章[链接](https://codeforces.com/blog/entry/15890)。

## 问题描述
>Sereja has a bracket sequence s1, s2, ..., sn, or, in other words, a string s of length n, consisting of characters "(" and ")".
>
>Sereja needs to answer m queries, each of them is described by two integers li, ri (1 ≤ li ≤ ri ≤ n). The answer to the i-th query is the length of the maximum correct bracket subsequence of sequence sli, sli + 1, ..., sri. Help Sereja answer all queries.
>
>You can find the definitions for a subsequence and a correct bracket sequence in the notes.
>
>Input
>The first line contains a sequence of characters s1, s2, ..., sn (1 ≤ n ≤ 106) without any spaces. Each character is either a "(" or a ")". The second line contains integer m (1 ≤ m ≤ 105) — the number of queries. Each of the next m lines contains a pair of integers. The i-th line contains integers li, ri (1 ≤ li ≤ ri ≤ n) — the description of the i-th query.
>
>Output
>Print the answer to each question on a single line. Print the answers in the order they go in the input.

## 解答
首先，我们看下标准的segment tree函数:
```
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
int sum(int x, int y, int id=1, int l =0, int r=n)
{
    if(x >=r || l>=y) return 0;
    if(x<=l &&  r <= y) return s[id];
    int mid =(l + r)/2;
    return sum(x,y,id*2,l, mid)
    + sum(x,y,id*2+1,mid,r);
}
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
我们通过完全二叉树储存区间，查询的时候，查询这个区间的最大子节点所储存的值。

这里同样，为了实现括号配对，我们对每个节点储存三种数据:
+ t[x], x节点所有的配对的数目;
+ o[x], x节点所代表的区间上，未配对的左括号数；
+ c[x], x节点所代表的区间上,为配对的右括号数；

而每次合并子节点时：
```
tmp = min(o[2*x], c[2*x +1])
t[x] = t[2*x] + t[2*x + 1] + tmp
o[x] = o[2*x] + o[2*x +1] - tmp
c[x] = c[2*x] + c[2*x + 1] - tmp
```
类似的，我们可以得出build函数：

```
void update(int id)
{
    int tmp = min(o[2*id], c[2*id +1]);
    t[id] = t[2*id] + t[2*id + 1] + tmp;
    o[id] = o[2*id] + o[2*id +1] - tmp;
    c[id] = c[2*id] + c[2*id + 1] - tmp;
}
void build(int id = 1, int l = 0, int r = n)
{
    if(r - l < 2)
    {
        if(s[l] == '(')
        {
            o[l] = 1;
        }
        else
        {
            c[l] = 1;
        }
        return;
    }
    int mid = ( l + r) /2;
    build(2 * id,l,mid);
    build(2 * id +1,mid, r);
    update(id);
}

```
对应的查询函数：
```
typedef pair<int, int>pii;
typedef pair<int,pii> node;
node segment(int x, int y,int id=1, int l =0, int r = n)
{
    if( l>= y || x >= r) return node(0,pii(0,0));
    if(x <= l && r<= y)
    {
        return node(t[id], pii(o[id],c[id]));
    }
    int mid = (l + r)/2;
    node a = segment(x, y, 2 * id, l, mid);
    node b = segment(x,y,2*id + 1,mid,r);
    int temp = min(a.y.x,b.y.y);
    int T = a.x + b.x + temp;
    int O = a.y.x + b.y.x - temp;
    int C = a.y.y + b.y.y - temp;
    return node(T,pii(O,C));
}
```
完工。

