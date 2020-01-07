---
layout: post
title : interval trees
excerpt_separator: <!--more-->
---

## 本文目的： 研究interval trees来加深对红黑树的理解。

<!--more-->
### Augment Tree
通过对已有的数据结构附加额外的属性，达到实现额外功能的目的。
附加的额外属性要保证原数据结构的增删改查的时间复杂度不会有渐进意义上的增加。

## Interval Trees
通过对红黑树附加额外的数据，我们要来实现对不同intervals 的组织。

我们将每个interval看作一个节点x,节点x中含有额外的数据，x.int.low和x.int.high表示这个interval的区间，
所有节点按照x.int.low作为key来组织。同时含有属性x.max,表示以x为根节点的子树上所有节点的high的最大值,即`x.max = max(x.int.high,x.left.max,x.right.max)`。

我们先证明对于这棵树的delete和insert操作时间仍然时O(lgn)的。

Proof:
+ 向interval tree中插入一个节点分为两步：1. 将节点x插入到合适的位置；2. 如果插入的节点不满足红黑树的属性，我们需要做fixup。
由于插入节点x及其所有祖先节点的max均有可能发生改变，我们需要更新O(lgn)个节点的属性值;对于需要旋转的节点，我们至多只需要做两次旋转，每次旋转只会动两个节点。我们最终只需要动O(lgn)个节点的属性。
+ 向interval tree中删除一个节点同样可以分为两步：1.删除指定节点，将后继节点移动到被删除的节点的位置；2. 后继节点可能发生不满足红黑树属性的情况，需要做fixup.我们知道删除操作最多只会发生3次旋转，于是我们更新属性的时间最多仍然是O(lgn).

## 查询

```
INTERVAL-SEARCH(T,i)
    x = T.root
    while x != T.nil and i does not overlap x.int
        if x.left != T.nil and x.left.max >= i.low
            x = x.left
        else x = x.right
    return x
```

Proof:

考察循环的不变性：
如果T有和interval i相交的interval，那么这个interval必然位于以x为根节点的子树上。

Initialization:

初始化时，x作为根节点，一定可以保证假设的正确。


Maintenance:
+ 如果当前节点x与i相交，循环终止。
+ 如果循环进入x的右子树，说明此时x的左子树为空或者左子树的max < i.low. 这两种情况均保证左子树不含与i相交的interval。
+ 如果循环进入x的左子树，此时，必然有x.left.max >= i.low。此时可以分为两种情况:
    * 如果左子树中不含和i相交的interval。那么此时必然有,对任何左子树中满足i'.high >= i.low的节点必然i.high < i'.low。又由于我们树是按照interval.low进行组织的，这意味着i.high < 所有右侧子树节点的int.low.
    * 如果左子树中含和i相交的interval。此时假设满足，进入左子树继续处理。

Termination:

如果循环终止于T.nil,由以上推导，可知，T中不含和i相交的节点。或者循环终止与找到某个节点x与i相交。

## 代码实现
这里借用了红黑树的结构，同时对红黑树做了一些重构。
```
#ifndef __RED_BLACK_TREE_H__
#define __RED_BLACK_TREE_H__ 1
#include <iostream>
#include <queue>

const int RED = 0;
const int BLACK = 1;
const int BLACK_BLACK= 3;
const int BLACK_RED = 4;
template<class T>
class BinNode
{
    public:
        BinNode (const T& data)
            :_data(data)
        {
            _color = BLACK;
            _lc = NULL;
            _rc = NULL;
            _p = NULL;
        }
        virtual ~BinNode (){}

        int & color() {return _color;}
        BinNode*& lc(){return _lc;}
        BinNode*& rc(){return _rc;}
        BinNode*& p(){return _p;}

        T& data(){return _data;}

    private:
    private:
        /* data */
        int _color;
        BinNode* _lc;
        BinNode* _rc;
        BinNode* _p;
        T _data;
};

template<class T,class Node>
class BinTree
{
    public:
class BinNode
{
    public:
        BinNode (const Node& data)
            :_data(data)
        {
            _color = BLACK;
            _lc = NULL;
            _rc = NULL;
            _p = NULL;
        }
        virtual ~BinNode (){}

        int & color() {return _color;}
        Node*& lc(){return _lc;}
        Node*& rc(){return _rc;}
        Node*& p(){return _p;}

        T& data(){return _data;}

    private:
    private:
        /* data */
        int _color;
        BinNode* _lc;
        BinNode* _rc;
        BinNode* _p;
        T _data;
};


    public:

        static Node* nil;
    public:
        BinTree()
        {
            _root = nil;
        }
        void insert(Node* node);
        Node* search(const T & t) const;

        void deletenode(Node* z);
        void dfs();
        void bfs();
        Node* root(){return _root;}
        void LeftRotate(Node* x) {left_rotate(x);}
        void RightRotate(Node* x){right_rotate(x);}
    protected:
        virtual void left_rotate(Node* x);

        virtual void right_rotate(Node* x);
    private:
        Node* search_recur(Node* node, const T& t) const;
        void insert_fixup(Node* node);
        void transplant(Node* u, Node* v);
        Node* minimum(Node* node);

        void delete_fixup(Node* x);

        void dfs_recur(Node* node);

    protected:
        Node* _root;
    public:
        static Node* make_node(const T& t)
        {
            Node* node = new Node(t);
            node->color() = RED;

            node->lc() = nil;
            node->rc() = nil;
            node->p() = nil;

            return node;
        }

};


template<class T>
class RedBlackTree:public BinTree<T,BinNode<T>>
{
};

template<class T,class Node>
Node* BinTree<T,Node>::nil = new Node(-1);

template<class T,class Node>
Node* BinTree<T,Node>::search(const T& t) const
{
    return search_recur(_root, t);
}
template<class T,class Node>
Node* BinTree<T,Node>::search_recur(Node* node, const T& t) const
{
    if(node == nil) return nil;
    if(node->data() == t) return node;
    if(node->data() < t)
    {
        return search_recur(node->rc(),t);
    }
    if (node->data() > t)
    {
        return search_recur(node->lc(),t);
    }
    return nil;

}
    template<class T,class Node>
void BinTree<T,Node>::dfs()
{
    dfs_recur(_root);
}
static const char* getColor(int color)
{
    if (color == RED)
    {
        return "red";
    }
    else if(color == BLACK)
    {
        return "black";
    }
    else if(color == BLACK_BLACK)
    {
        return "black_black";
    }
    else if(color == BLACK_RED)
    {
        return "black_red";
    }
    return "";
}
    template <class T,class Node>
void BinTree<T,Node>::bfs()
{
    if (_root == nil) return;
    std::queue<Node* > q;
    q.push(_root);
    int cur = 1;
    int next =0;
    while(q.size() > 0)
    {
        Node* node = q.front();

        q.pop();
        std::cout<<node->data() << " "<<getColor(node->color())<<"    ";


        if(node->lc() != NULL)
        {
            q.push(node->lc());
            next ++;
        }
        if(node->rc() != NULL)
        {
            q.push(node->rc());
            next += 1;
        }

        cur--;
        if(cur <=0)
        {
            std::cout<<std::endl;
            cur = next;
            next = 0;
        }
    }
    std::cout<<std::endl;
}

    template<class T,class Node>
void BinTree<T,Node>::dfs_recur(Node* node)
{
    if(node->lc() != nil)
    {
        dfs_recur(node->lc());
    }
    if(node->rc() != nil)
    {
        dfs_recur(node->rc());
    }
    std::cout<<" "<<node->data()<<" ";
}

    template<class T,class Node>
Node* BinTree<T,Node>::minimum(Node* node)
{

    while(node->lc() != nil)
    {
        node = node->lc();
    }
    return node;


}

    template<class T,class Node>
void BinTree<T,Node>::transplant(Node* u, Node* v)
{
    if(u->p() == nil)
    {
        _root = v;
    }
    else if(u == u->p()->lc())
    {
        u->p()->lc() = v;
    }
    else
    {
        u->p()->rc() = v;
    }
    v->p() = u->p();
}
    template<class T,class Node>
void BinTree<T,Node>::deletenode(Node* z)
{
    Node* y = z;
    Node* x= nil;
    int y_original_color = y->color();
    if (z->lc() == nil)
    {
        x = z->rc();
        transplant(z,z->rc());
    }
    else if(z->rc() == nil)
    {
        x = z->lc();
        transplant(z,z->lc());
    }
    else
    {
        y = minimum(z->rc());
        y_original_color = y->color();
        x = y->rc();
        if(y->p() == z)
        {
            x->p() = y;
        }
        else
        {
            transplant(y,y->rc());
            y->rc() = z->rc();
            y->rc()->p() = y;
        }
        transplant(z,y);
        y->lc() = z->lc();
        y->lc()->p() = y;
        y->color() = z->color();
    }
    if(y_original_color == BLACK)
    {
        std::cout<<"delete_fixup "<<x->data()<<std::endl;
        delete_fixup(x);
    }

}

    template<class T,class Node>
void BinTree<T,Node>::delete_fixup(Node* x)
{
    Node * w;
    while( x != _root && x->color() == BLACK)
    {
        if(x == x->p()->lc())
        {
            w = x->p()->rc();
            if(w->color() == RED) // case 1
            {
                w->color() = BLACK;
                x->p()->color() = BLACK;
                left_rotate(x->p());
                w = x->p()->rc();
            }
            if(w->lc()->color() == BLACK && w->rc()->color() == BLACK)
            {
                w->color() = RED;
                x = x->p();
            }
            else
            {
                if(w->rc()->color() == BLACK)
                {
                    w->lc()->color() = BLACK;
                    w->color() = RED;
                    right_rotate(w);
                    w = x->p()->rc();
                }
                w->color() = x->p()->color();
                x->p()->color()  = BLACK;
                w->rc()->color() = BLACK;
                left_rotate(x->p());
                x = _root;
            }
        }
        else
        {
            w = x->p()->lc();
            if(w->color() == RED)
            {
                w->color() = BLACK;
                x->p()->color() = RED;
                right_rotate(x->p());
                w = x->p()->lc();
            }
            if(w->lc()->color() == BLACK && w->rc()->color() == BLACK)
            {
                w->color() = RED;
                x = x->p();
            }
            else
            {
                if(w->lc()->color() == BLACK)
                {
                    w->rc()->color() = BLACK;
                    w->color() = RED;
                    left_rotate(w);
                    w = x->p()->lc();
                }
                w->color() = x->p()->color();
                x->p()->color() = BLACK;
                w->lc()->color() = BLACK;
                right_rotate(x->p());
                x = _root;
            }
        }
    }
    x->color() =BLACK;
}
    template<class T,class Node>
void BinTree<T,Node>::left_rotate(Node* x)
{
    Node* y = x->rc();
    x->rc() = y->lc();
    if(y->lc() != nil)
    {
        y->lc()->p() = x;
    }
    y->p() = x->p();
    if(x->p() == nil)
    {
        _root = y;
    }
    else if (x == x->p()->lc())
    {
        x->p()->lc() = y;
    }
    else if(x == x->p()->rc())
    {
        x->p()->rc() = y;
    }
    y->lc() = x;
    x->p() = y;
}
    template<class T,class Node>
void BinTree<T,Node>::right_rotate(Node* y)

{

    Node* x = y->lc();
    y->lc()  = x->rc();
    if(x->rc() != nil)
    {
        x->rc()->p() = y;
    }
    x->p() = y->p();
    if(y->p() == nil)
    {
        _root = x;
    }
    else if(y == y->p()->lc())
    {
        y->p()->lc() = x;
    }
    else if(y == y->p()->rc())
    {
        y->p()->rc() =x;
    }
    x ->rc() = y;
    y->p() = x;
}
    template<class T,class Node>
void BinTree<T,Node>::insert_fixup(Node* z)
{
    Node* y;
    while(z->p()->color() == RED)
    {
        if(z->p() == z->p()->p()->lc())
        {
            y = z->p()->p()->rc();
            if (y->color() == RED)
            {
                z->p()->color() = BLACK;
                y->color() = BLACK;
                z->p()->p()->color() = RED;
                z = z->p()->p();
            }
            else
            {
                if(z == z->p()->rc())
                {
                    z = z->p();
                    left_rotate(z);
                }
                z->p()->color() = BLACK;
                z->p()->p()->color() = RED;
                right_rotate(z->p()->p());
            }
        }
        else
        {
            //std::cout<<"case 2'"<<std::endl;
            y = z->p()->p()->lc();
            if (y ->color() == RED)
            {
                z->p()->color() = BLACK;
                y->color() = BLACK;
                z->p()->p()->color() = RED;
                z = z->p()->p();
            }
            else
            {
                if (z == z->p()->lc())
                {
                    z = z->p();
                    right_rotate(z);
                    //std::cout<<"right_rotate for case 2"<<std::endl;
                    //bfs();
                }
                z->p()->color() = BLACK;
                z->p()->p()->color() = RED;
                left_rotate(z->p()->p());
            }
        }
    }
    _root->color() = BLACK;
}

    template<class T,class Node>
void BinTree<T,Node>::insert(Node* node)
{
    Node* y = nil;
    Node* x= _root;;
    while (x != nil)
    {
        y = x;
        if(node->data() < x->data())
        {
            x = x->lc();
        }
        else
        {
            x = x->rc();
        }
    }
    node->p() = y;
    if (y == nil )
    {
        _root = node;
    }
    else if(node->data() < y->data())
    {
        y->lc() = node;
    }
    else
    {
        y->rc() = node;
    }
    node->lc() = nil;
    node->rc() = nil;
    node->color() = RED;
    //std::cout<<"before insert_fixup "<<std::endl;
    //bfs();
    //std::cout<<"==================="<<std::endl;
    insert_fixup(node);
}


#endif

```

```
#ifndef __INTERVAL_TREE_H__
#define __INTERVAL_TREE_H__ 1

#include <algorithm>
#include "redblacktree.h"

// use low as BinNode key
class IntervalNode
{
    public:

        IntervalNode(int noop)
            :_low(noop),_high(noop),_max(noop),_lc(NULL),_rc(NULL),_p(NULL)
        {

        }
        IntervalNode(int low, int high)
            :_low(low),_high(high),_max(high),_lc(NULL),_rc(NULL),_p(NULL)
        {
        }

        IntervalNode*& lc() {return _lc;}
        IntervalNode*& rc() {return _rc;}
        IntervalNode*& p() {return _p;}
        int & color() {return _color;}

        int& data() {return _low;}

        int& low() {return _low;}
        int& high() {return _high;}

        int& max() {return _max;}
        bool overlap(IntervalNode* i)
        {
            return  _low <= i->high() && _high >= i->low();
        }
    private:
        int _low;

        int _high;

        int _max;

        int _color;
        IntervalNode* _lc;
        IntervalNode* _rc;
        IntervalNode* _p;
};

class IntervalTree:public BinTree<int,IntervalNode>
{
    public:
        IntervalTree()
        {
        }
    public:
        static IntervalNode* make_node(int low, int high)
        {
            IntervalNode* node = new IntervalNode(low,high);
            node->color() = RED;

            node->lc() = nil;
            node->rc() = nil;
            node->p() = nil;

            return node;
 
        }
    public:
        IntervalNode* IntervalSearch(IntervalNode* i)
        {
           IntervalNode* x =this-> _root; 
           while( x != nil && ! x->overlap(i))
           {
               if(x->lc() != nil && x->lc()->max() > i->low())
               {
                    x= x->lc();
               }
               else
               {
                   x = x->rc();
               }
                       
           }
           return x;
        }
    protected:
        void left_rotate(IntervalNode* x) override
        {
            IntervalNode* y = x->rc();
            IntervalNode* y_lc = y->lc();
            IntervalNode* y_rc = x->rc();
            BinTree<int,IntervalNode>::left_rotate(x);
            int x_max = x->high();
            if( x->lc() != nil)
            {
                x_max = std::max(x_max, x->lc()->max());
            }
            if ( y_lc != nil)
            {
                x_max = std::max(x_max, y_lc->max());
            }
            x->max() = x_max;

            int y_max = y->high();
            y_max = std::max(y_max,x_max);
            if(y_rc != nil)
            {
                y_max = std::max(y_max,y_rc->max());
            }
            y_rc->max() = y_max;
        }
        void right_rotate(IntervalNode* y)  override
        {
            IntervalNode* x = y->lc();
            IntervalNode* x_lc = x->lc();
            IntervalNode* x_rc = x->rc();
            BinTree<int,IntervalNode>::right_rotate(y);
            int y_max = y->high();
            if (x_rc != nil)
            {
                y_max = std::max(x_rc->max(),y_max);
            }
            if(y->rc() != nil)
            {
                y_max = std::max(y->rc()->max(),y_max);
            }
            y->max() = y_max;
            int x_max = x->high();
            x_max = std::max(x_max, y_max);
            if(x_lc != nil)
            {
                x_max = std::max(x_lc->max(), x_max);
            }
            x->max() = x_max;
        }
};

#endif 
```
