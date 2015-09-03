---
layout: post
category: thought of books
tags: [program]
---
{% include JB/setup %}

最近研究了下C#的IDispose的用法，结果找到个[网页](http://stackoverflow.com/questions/538060/proper-use-of-the-idisposable-interface)推荐了Com As A Better C++这篇文章，花了些时间阅读，现在权且写些读后感之类的事吧。

#分享自己的代码库#
很多时候我们写好一些库，需要让其他人使用，最简单的便是直接贴代码了，但明显，库是一种跟好的形式，最基本的，静态库与动态库。

先上今天的栗子。
```
#pragma once
class OrderTestUnit
{
    public:
        OrderTestUnit(){}
        bool IsBigOrder();
    private:
        
};
```
```
#include<cstdint>
#include"HostOrder.h"
bool OrderTestUnit::IsBigOrder()
{
    union {
        char chs[2];
        uint16_t number;
    } orderTestUnit;
    orderTestUnit.number = 0x0102;
    if(orderTestUnit.chs[0] == 0x01 && orderTestUnit.chs[1] == 0x02)
    {
        return false;
    }
    else if(orderTestUnit.chs[0] == 0x02 && orderTestUnit.chs[1] == 0x01)
    {
        return true;
    }
    return false;
}
```
这是一个查询当前机器是大端序列还是小端序列的程序。
现在我们使用这个程序，最基本的，直接使用程序源码：


```
#include"HostOrder.h"
#include<iostream>

int main(int argc, char** argv)
{
    OrderTestUnit* order = new OrderTestUnit();
    bool bBigOrder = order->IsBigOrder();
    if(bBigOrder)
    {
        std::cout<<"BigOrder"<<std::endl;
    }
    else
    {
        std::cout<<"LittleOrder"<<std::endl;
    }
    std::cout<<"End";
}
```

编译： `g++ -std=c++11 main.cpp HostOrder.cpp -o test`输出结果：`LittleOrder`嗯，本机是大端机器。
换个方法，使用静态链接库，毕竟不能总是让别人用源码嘛。生成obj文件`g++ -std=c++11 -c HostOrder.cpp -o HostOrder.o`,生成archive文件`ar rcs libHostOrder.a HostOrder.o`.链接`g++ -std=c++11 -L . main.o -o test -lHostOrder`。嗯，结果一致。

OK,现在我们有了第一个发布库代码的方法了，但静态链接有如下问题：
1.所有使用HostOrder的Client程序自己会有一份HostOrder的拷贝。
2.当需要更新HostOrder时，必须一同更新Client代码。

我们知道动带链接库可以在系统中只存在一份，于是，我们有了第一个优化方法，动态链接库。创建动态库libHostOrder.so`g++ -std=c++11 -Wall -fPIC -shared -o libHostOrder.so HostOrder.cpp`,生成二进制`g++ -std=c++11 main.cpp -o test -L. -lHostOrder`,同时要把当前目录包括到链接路径中`export LD_LIBRARY_PATH=.`。嗯，结果一致。
当然，这里需要考虑不同编译器的名字解析问题。这里需要注意不同编译器的命名解析是不同的。

现在，我们考虑第二个问题，当我们发现需要修改HostOder时该怎么办。我们先把库文件拷到文件v1中.
然后，我们对OrderTestUnit做第一步优化，我们把比较的结果记录下来，这样就不用每次比较了。为此，我添加两个member字段，记录当前是否判断过大端小端，并记录结果。
```
#pragma once
class OrderTestUnit
{
    public:
        OrderTestUnit()
            :m_bInitialized(false),
            m_bIsBig(false)
        {}
        bool IsBigOrder();
    private:
        bool m_bInitialized;
        bool m_bIsBig;
        
};
```
然后我们出我们的v2版hostOrder的动态库文件。然后让跑我们的test。额，结果一切正常。。。。并没有出现crash之类的情况，为了让结果明显，这里更改下代码。
#pragma once
class OrderTestUnit
{
    const static int BIG_ORDER ;
    const static int LITTLE_ORDER ;
    const static int NULL_ORDER ;
    public:
        OrderTestUnit();
        bool IsBigOrder();
    private:
        int m_nResult ;
};

#include<cstdint>
#include<iostream>
#include"HostOrder.h"

const int OrderTestUnit::BIG_ORDER = 1;
const int OrderTestUnit::LITTLE_ORDER = 2;
const int OrderTestUnit::NULL_ORDER = 255;
OrderTestUnit::OrderTestUnit()
    :m_nResult(NULL_ORDER)
{
}
bool OrderTestUnit::IsBigOrder()
{
    if(m_nResult ==  BIG_ORDER) return true;
    else if(m_nResult == LITTLE_ORDER) return false;
    else if(m_nResult != NULL_ORDER)
    {
        std::cout<<"wrong result "<< m_nResult<<std::endl;
        return false;
    }
    union {
        char chs[2];
        uint16_t number;
    } orderTestUnit;
    orderTestUnit.number = 0x0102;
    if(orderTestUnit.chs[0] == 0x01 && orderTestUnit.chs[1] == 0x02)
    {
        m_nResult = LITTLE_ORDER;
    }
    else if(orderTestUnit.chs[0] == 0x02 && orderTestUnit.chs[1] == 0x01)
    {
        m_nResult = BIG_ORDER;
    }
    if(m_nResult == BIG_ORDER)
    {return true;}
    else if(m_nResult == LITTLE_ORDER)
    {
        return false;
    }
    else if(m_nResult == NULL_ORDER)
    {
        std::cout<<"Not initialized";
        return false;
    }
    else {
        std::cout<<"wrong result "<<m_nResult<<std::endl;
        return false;
    }

    return m_nResult == BIG_ORDER;

}
将生成的动态库拷到v1中，运行test，结果`wrong result 0`。这里可以看到，程序初始化时，由于test并不知道OrderTestUnit多了一个m_nResult变量，所以这里

