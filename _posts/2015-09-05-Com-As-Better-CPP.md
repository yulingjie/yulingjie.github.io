---
layout: post
category: Learn
tags: [program]
---
{% include JB/setup %}

最近研究了下C#的IDispose的用法，结果找到个[网页](http://stackoverflow.com/questions/538060/proper-use-of-the-idisposable-interface)推荐了Com As A Better C++这篇文章，花了些时间阅读。现在花些时间跟着书，走一边栗子，顺便加深下理解。

几个约定
1. 使用库文件的一律称为Client。
2. 库最初版本为v0,依次往上加，并存在同名文件中。


###从源码到库###
v0 版代码

    // FastString.h
    class FastString{
        char *m_psz;
        public:
        FastString(const char *psz);
        ~FastString(void);
        unsigned long Length(void) const;
        int Find(const char* psz) const;
    };    

    // FastString.cpp
    #include"FastString.h"
    #include<string.h>

    FastString::FastString(const char* psz)
        :m_psz(new char[strlen(psz) +1]){roblems of compiler/linker compatibility, which
ulti
            strcpy(m_psz, psz);
        }

    FastString::~FastString(void){
        delete[] m_psz;
    }
    unsigned long  FastString::Length(void) const{
        return strlen(m_psz);
    }
    int FastString::Find(const char *psz) const{
        if(*psz == *m_psz)
            return 0;
        return -1;
    }
    // main.cpp
    #include "FastString.h"
    #include<iostream>
    int main(int argc, char** argv)
    {
        FastString* fs = new FastString("test string");
        std::cout<<"FastString Length: "<< fs->Length()<<std::endl;
        if(0 == fs->Find("test")    )
        {
            std::cout<<"FastString Find 'test'"<<std::endl;
        }
        else
        {
            std::cout<<"FastString 'test' not Found"<<std::endl;
        }
    }

新建Makefile编译

    CC = g++
    CFLAG = -std=c++11 -Wall
    TARGET = test
    INCLUDE = .
    LIB = .

    $(TARGET): FastString
        $(CC) $(CFLAG) -I $(INCLUDE) main.cpp -o $(TARGET) -L $(LIB) -lFastString

    FastString:
        $(CC) $(CFLAG) -fPIC -shared -o libFastString.so FastString.cpp

动态库在系统中只存在同一份，这样一个系统上的所有Clients可以共享同一份库文件，减少了库占用空间。但同时，也引出库更新的问题。

对v0进行少量修改，v1版代码。

    // FastString.h 中添加私有变量 m_cch
    const unsigned long m_cch;

    // FastString.cpp 的constructor进行变量初始化
    FastString::FastString(const char* psz)
        :m_cch(strlen(psz)),m_psz(new char[strlen(psz) +1]){
            strcpy(m_psz, psz);
        }

    // Length()返回储存的长度
    unsigned long  FastString::Length(void) const{
        return m_cch;
    }


同样编译，结果不变。。。
按照书中所说，由于C++ Compilation Model的设计，v0版本的test是无法知道新加入的私有变量m_cch的存在的，C++标准并没有关于Binary Encapsulation的明确描述。这里很可能产生未定义的行为，不过GNU成功运行，这里记录下，以后看看原因。

###分离接口与实现###
由于Binary Encapsulation问题的存在，书中引入了接口与实现的分离的方法，让接口本身是一个不变的obj，实现是另一个。这样，当修改实现部分时，Client是不会受到任何影响的。

v2代码

    // FastStringItf.h
    class FastString;

    class FastStringItf{
        FastString * m_pThis;

        public:
        FastStringItf(const char*psz);
        ~FastStringItf(void);
        unsigned long Length(void) const;
        int Find(const char* psz) const;
    };
    
    // FastStringItf.cpp
    #include"FastString.h"
    #include "FastStringItf.h"
    #include <cassert>

    FastStringItf::FastStringItf(const char* psz)
        :m_pThis(new FastString(psz)){
            assert(m_pThis !=0);
        }

    FastStringItf::~FastStringItf(void)
    {
        delete m_pThis;
    }
    unsigned long FastStringItf::Length(void) const
    {
        return m_pThis->Length();
    }
    int FastStringItf::Find(const char* psz) const
    {
        return m_pThis->Find(psz);
    }

这样，不管真正的FastString怎么变化，main使用的FastStringItf不变，main本身不受影响。
但是，当前做法有如下问题：

1. 所有的接口都要写两遍，麻烦且运行效率不高。
2. 并没有解决Compiler/Linker依赖的问题。

###编译器/链接器依赖###

目测是个深坑，这里先根据书中说的列下，以后有时间理理。

要想让同一份C++代码在不同厂家的编译器/链接器上能用，必须满足一下两点：

1. 运行时C++语言特性的表现是一致的;
2. 链接时有着可以通用的符号命名方式。

使用Modle Definition File解决命名问题，让接口不使用任何编译器依赖的语言特性，解决语言特性问题，这样同一份C++代码就可以在不同厂家的编译器/链接器上使用了。

三大条件：

1. 所有符合类型的运行时表现是一致的; (任何基于C的系统调用必须满足的)
2. 所有函数的参数顺序是一致的，函数的栈清除方式是一致的;(Linux下只有一种方式，见[这个回答](http://stackoverflow.com/questions/3054257/is-there-stdcall-in-linux))。
3. 不同编译器的虚函数调用机制是一致的。 (只需满足无data field和有至多一个无data field的基类的情况)

在第三个猜测的情况下，书中引入的纯虚类来作为interface。

###使用纯虚类作为interface###

v3版代码

    // IFastString.h
    class IFastString{
        public:
            virtual unsigned long Length(void) const = 0;
            virtual int Find(const char* psz) const =0;
            virtual void Delete(void) = 0;
    };
    extern "C"
    IFastString * CreateFastString(const char* psz);

    // FastString.h
    class FastString:public IFastString{
        // add delete 
        void Delete(void);
    };

    // FastString.cpp
    IFastString * CreateFastString(const char* psz){
        return new FastString(psz);
    }
    void FastString::Delete(void)
    {
        delete this;
    }


注意到，这里并没有定义FastString的Virtual Destructor，由于书中说virtual destructor对不同平台的编译器处理方式是不同的，但对于linux这里还不清楚，先按书中方式，不使用virtual destructor,而是使用virtual Delete。

目前，我们有了一个编译器/链接器无关的，Client完全分离的FastString代码。

###运行时多态###

当Client发布自己的应用程序时，如果目标机器本身无需要的库文件时，程序会直接报错并无法运行，为此我们有v3版代码。

    // main.cpp
    // 动态加载 库文件
    typedef IFastString* (*FS)(const char* );
    IFastString * CallCreateFastString(const char* psz)
    {
        IFastString* pResult = NULL;
        static IFastString* (*pfn)(const char *) = 0;
        if(!pfn){
            void* lib_handle = dlopen("/home/ylj/Projects/test/comcpp/libFastString.so",RTLD_NOW | RTLD_GLOBAL);
            if(lib_handle)
            {
                pfn = (FS)dlsym(lib_handle,"CreateFastString");
            }
            pResult = pfn ? pfn(psz) :0;
        }
        return pResult;
    }

这样，即使目标机器并没有FastString动态库，也不会导致程序crash。

###扩展###
书中提出了新的问题，如何扩展接口。
假设现在我们需要添加新函数。

    // IFastString.h
    virtual int FindN(const char* psz) const = 0;

    // FastString.h
    int FindN(const char* psz) const;

    // FastString.cpp
    int FastString::FindN(const char* psz) const{
        return -1;
    }

使用v3版的test调用libFastString.so，嗯，一切正常。使用v3版的libFastString.so来运行test，嗯也是一切正常。

现在，修改main，调用FindN。

    // main.cpp
    fs->FindN("test find N");

再使用libFastString.so来运行test，报错。
这说明，直接修改接口并不是一定没问题的，当Client使用新接口时而库是老版本的时候会出现问题。书中提出了修改方法。

v4版代码。

    //添加IFastString2.h
    #include"IFastString.h"

    class IFastString2: public IFastString{
        public:
            virtual int FindN(const char* psz) const = 0;
    };

    //main.cpp
    int CallFindN(IFastString *fs)
    {
        IFastString2 *fs2 = dynamic_cast<IFastString2*>(fs);
       if(fs2)
       {
          std::cout<<"FastString FindN: "<<fs2->FindN("test faststring2")<<std::endl;
       }
       else
       {
           std::cerr<<"Cannot cast to IFastString2"<<std::endl;
       }
       return 0;
    }

可以看到，此时Client代码调用时必须判断当前的接口的运行时类型，即所谓的RTTI，这样Client面对不同版本的库也可以无crash的运行。

然而，RTTI是个编译器依赖的语言特性，这意味着当直接使用dynamic_cast时，跨平台的代码很可能出错。于是，对v4代码做进一步改进。与Delete的处理方法一样，添加新的函数Dynamic_Cast。

v5代码

    // IExtensibleObject.h
    class IExtensibleObject {
        public:
        virtual void *Dynamic_Cast(const char* pszType) =0;
        virtual void Delete(void) = 0;
    };

    // IFastString.h
    class IFastString:public IExtensibleObject{
        public:
            virtual unsigned long Length(void) const = 0;
            virtual int Find(const char* psz) const =0;
    };

    // FastString.h
    class FastString:public IFastString{
        void* Dynamic_Cast(const char* psz);
        void Delete();    
    };
    // FastString.cpp
    void* FastString::Dynamic_Cast(const char* psz)
    {
       if(strcmp(psz, "IFastString") == 0)
        {
            return static_cast<IFastString*>(this);
        }
       else if(strcmp(psz, "IExtensibleObject")== 0)
       {
           return static_cast<IExtensibleObject*>(this);
       }
       return 0;
    }
    // main.cpp
    // inside CallFindN
    IFastString2 *fs2 =(IFastString2*) fs->Dynamic_Cast("IFastString2");

最后，书中指出需要只能管理FastString的指针，类似智能指针,这里就不写代码实现了。

###总结###
大概走了一边代码，感觉，要想实现跨平台的C++代码还是很麻烦的，需要注意的点比较多,估计很难有机会亲手写这类代码了，这里了解下原理，记录下吧。

(源码地址)[https://github.com/yulingjie/ComAsBetterCPPTestCode]。
