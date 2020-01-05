---
layout: post
title : interval trees
---

## 本文目的： 研究interval trees来加深对红黑树的理解。

### Augment Tree
通过对已有的数据结构附加额外的属性，达到实现额外功能的目的。
附加的额外属性要保证原数据结构的增删改查的时间复杂度不会有渐进意义上的增加。

## Interval Trees
通过对红黑树附加额外的数据，我们要来实现对不同intervals 的组织。

我们将每个interval看作一个节点x,节点x中含有额外的数据，x.int.low和x.int.high表示这个interval的区间，
x.max表示以x为根节点的子树上所有节点的high的最大值,即`x.max = max(x.int.high,x.left.max,x.right.max)`。

我们先证明对于这棵树的delete和insert操作时间仍然时O(lgn)的。

Proof:
+ 向interval tree中插入一个节点分为两步：1. 将节点x插入到合适的位置；2. 如果插入的节点不满足红黑树的属性，我们需要做fixup。
由于插入节点x及其所有祖先节点的max均有可能发生改变，我们需要更新O(lgn)个节点的属性值;对于需要旋转的节点，我们至多只需要做两次旋转，每次旋转只会动两个节点。我们最终只需要动O(lgn)个节点的属性。
+ 向interval tree中删除一个节点同样可以分为两步：1.删除指定节点，将后继节点移动到被删除的节点的位置；2. 后继节点可能发生不满足红黑树属性的情况，需要做fixup.我们知道删除操作最多只会发生3次旋转，于是我们更新属性的时间最多仍然是O(lgn).

## 查询


