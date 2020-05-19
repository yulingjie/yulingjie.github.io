---
layout: post
title : BM算法（字符串快速匹配算法）
categories: [算法]
excerpt_seperator: <!--more-->
---


本文目的在于研究BM算法的大概思路。


### BM算法
字符串string
匹配串P，长度patlen。
对字符串T和匹配串P进行匹配，如果自右向左进行匹配，而不是自左向右，有如下观察：
1. 如果对于第一个匹配，即P[patlen]处的字符X和T[i]处的字符Y不匹配，而匹配串P中不含任何Y，那么
我们下次匹配的时候，可以直接跳过Y，那么下次匹配的时候可以直接右移patlen的长度即可。
![operation 1](/assets/faststringsearch/2019_12_23_21_36.46.bmp)
2. 如果P中包含Y,假设Y的字符的位置距离P右侧的距离为delta，那么此时，我们可以直接将P右移delta的长度，
直接让P中右边第一个Y出现的位置对上我们当前string中正在匹配的字符Y。
![operation 2](/assets/faststringsearch/2019_12_23_22_07.51.bmp)
3. 现在假设我们自右边开始的匹配一一满足，那么我们可以一直自右向左的匹配。那么此时只有
两种结果，或者我们全部匹配完了P，此时我们匹配成功了；或者我们在某个位置匹配失败。很明显，
现在感兴趣的是我们在某个位置匹配失败的情况。我们把在某个失败之前匹配成功的距离记为m。
![operation 3](/assets/faststringsearch/2019_12_23_22_23.17.bmp)
3(a) 我们可以基于之前的逻辑，在X的左侧，我们找到第一个出现的Y，我们假设这个Y为Y1，
将Y1右移动到我们string中目前Y的位置。假设这个Y1距离X的长度为k，那么我们只需右移k即可。
![operation 4](/assets/faststringsearch/2019_12_24_10_17.34.bmp)
此时，我们重新开始匹配的话，通用从P的最右端开始匹配，匹配的位置距离当前位置k+m的长度。
假设，P中最右侧的Y1出现在X的右侧，此时，P可以使得Y1与Y进行匹配，但这并不是我们想要的。
或者说，对于回退P的验证，我们应该在之前的搜寻中包括了。此时，我们简单的右移1.
![operation 5](/assets/faststringsearch/2019_12_24_10_54.53.bmp)
![operation 6](/assets/faststringsearch/2019_12_24_10_57.36.bmp)
3(b)现在我们看下另一种情况。同样在第一次不匹配之前，我们已经匹配了m个字符了，我们把这个字符串
称为子串sP，那么，我们可预想到，在下次右移后，这个子串sP一定是匹配的，或者说sP在P中，除了末尾出现
一次，还在之前也出现过。且这个子串的前序字符Z一定与X不一致。
![operation 7](/assets/faststringsearch/2019_12_24_11_23.38.bmp)
![operation 8](/assets/faststringsearch/2019_12_24_11_35.25.bmp)

目前为止，我们已经说了三种可以跳转的情况，我们只需从这三种情况中选择最远的跳转即可。

## 算法
```
input:	string, pat

		stringlen := length of string
		i := patlen
top:	
		if i> stringlen then return false
		j := patlen
loop:	
		if j==0 then return i+1
		if string(i) == pat(j) then
			j = j - 1
			i = i - 1
			goto loop
			close;
		i = i + max(delta1(string(i)), delta2(j))
		goto top
```

```
delta1(char) :=  if char does not occur in pat, 
					then patlen;
				else patlen - j,
				where j is the maximum integer such that
				pat(j) == char.
delta2(j)	:= k + m
			k : the discovered occurence (in string) of the last patlen-j characters of pat
			m : additional distance we have already matched
			:= patlen + 1 - rpr(j)
rpr(j)		:= the rightmost plausible reoccurrence 
```

### delta1的构造
```
make_delta1:

input:	pat
		
		patlen := pat.length
		delta1 := array[256] // 把所有字符表都遍历一遍, array 从1开始
		j := 1;
loop:
		delta1[j] := patlen
		j := j + 1
		if j <= 256 then goto loop
		j := 1;
delta:
		delta1[pat[j]] := patlen - j
		if j <= patlen then goto delta
		
```
### delta2的构造
我们先构造rpr表，即对每一个后缀找到the rightmost plausible reoccurrence.
这里论文中没有给出明确的方案，这里搜寻了下[wiki](https://en.wikipedia.org/wiki/Boyer%E2%80%93Moore_string-search_algorithm)
采用wiki里提到的delta2的实现方案，并且只考虑rpr的情况。这里统一下标从1开始计算。
```
suffix_length: // 算出在pos处最长后缀的长度

input:	pat, pos

		patlen := pat.length
		i := 0
		
loop:	if (pat[pos-i] == word[patlen-i]) and ( i< pos) then
			++i
			goto loop
			
		return i

```

```
make_delta2:

input:	pat

		patlen := pat.length
		p := 1		
loop:	
		if p < patlen then
			slen := suffix_length(pat, p)
			if ((p-slen <=0) or // 这里加个前序不存在的判定,wiki里这种情况通过loop1考虑了
				(pat[p-slen] != pat[patlen - slen]) then
				delta2[patlen - slen] = patlen - p + slen
			p ++
			goto loop
```

## 实现细节
使用delta0替换delta1，`delta0(pat(patlen)) := large := stringlen + patlen + 1`
```
input: 	string, pat

		stringlen := string.length
		patlen := pat.length
		i := patlen
		if i > stringlen then return false
fast:	
		i := i + delta0(string(i))
		if i<= stringlen then goto fast
undo:	if i <= large then 	return false
		i := (i - large) -1
		j := patlen -1
slow:	if j == 0 return i + 1
		if string(i) == pat(j)
			then 
			j := j-1
			i := i-1
			goto slow
			close
		i := i + max(delta1(string(i)), delta2(j))
		goto fast			
```
这部分代码比较难理解。是作者为了优化算法速度做的实现，原理与之前的版本是一致的。这里细细剖析下。

首先看下`fast`循环进来和结束的状态与条件：
* 程序开始时进入，此时`i <= stringlen`，或者确切的说`i := patlen`。进入`fast`后运行`i := i + string(patlen)`。
	+ 如果，`string(patlen)`与`pat(patlen)`不相等，此时右移到下一次匹配的位置；
	+ 如果，`string(patlen)`与`pat(patlen)`相等，此时右移large；
	+ 判断 `i <= stringlen`，如果`i > stringlen`，并且`i > large`，这说明我们的末尾字符匹配成功，可以进入`slow`逻辑继续匹配。
	+ 如果`i> stringlen`,但`i <= large`，这说明，我们末尾字符没有匹配成功，但是`i`移出了string的范围，匹配失败。
* 从`slow`中进入，此时`string(i) != pat(j)`，出现了第一次不匹配，`i`更新为`i + max(delta1(string(i)), delta2(j))`，
注意这里，使用的仍然是`delta1`。

`slow`的逻辑与原版算法基本一致。

这版算法将对`patlen`处字符的匹配单独提出，作者评估过80%的匹配时间都消耗在`fast`loop，通过将这部分代码单独提出，使用机器指令单独编码，可以加快算法的运行
速度。

## 理论分析
这部分见论文吧，通过概率模型分析，运行时间是c*(i + patlen) c< 1。

## 代码实现
```

#include <iostream>
#include <algorithm>



void make_delta1(const char* pat, int patlen, int* delta1)
{	
	for(int i = 0; i < 256; ++i)
	{
		delta1[i] = patlen;
	}
	for(int i = 0; i < patlen; ++i)
	{
		delta1[(int)pat[i]] = patlen - i -1; // we start index from zero	
	}
}

int suffix_length(const char* pat, int patlen,int pos)
{
	int i = 0;
	while( i <= pos 
			&& pat[pos-i] == pat[patlen-i-1])
	{
			++i;
			
	}
	return i;
}



void make_delta2(const char* pat, int patlen, int* delta2)
{	
	// 默认正在p处不匹配时，直接移动到+1的位置进行新的匹配，
	// 最慢的
	// 默认值
	for(int p = 0; p < patlen; ++p)
	{
		delta2[p] = patlen - p ;
	}
	for(int p = 0; p < patlen-1;++p)
	{
		int slen = suffix_length(pat, patlen, p);
		
		if(p - slen < 0 || pat[p-slen] != pat[patlen-slen])
		{
			delta2[patlen-slen -1] = patlen - p -1 + slen;
			//std::cout<<" set delta2 "<<patlen-slen -1 << " = "<<patlen-p-1 + slen<<std::endl;
		}
	}

}

int match(const char* txt, int txtLen, const char* pat, int patlen)
{
		
		int delta1[256];
		make_delta1(pat, patlen, delta1);
		
		int* delta2 = new int[patlen];
		make_delta2(pat, patlen, delta2);
		
		int j = patlen-1;
		int i = patlen - 1;
		while( i < txtLen)
		{
			int j = patlen-1;
			//std::cout<<" i = "<<i<<" j = "<<j<<std::endl;
			while( j >= 0)
			{
				//std::cout<<" compare "<<txt[i] << " and "<<pat[j]<<std::endl;
				if(txt[i] == pat[j])
				{
					j--;
					i--;
				}
				else{
					break;
				}
			}
			if(j <0)
			{
				return i + 1;
			}
			//std::cout<<" delta1 = "<<delta1[txt[i]] << " delta2 = "<<delta2[j]<<std::endl;
			i = i + std::max(delta1[txt[i]],delta2[j]);
		}
		return -1;
}
```
## 附
在 "Knuth D.E. Morris J.H., and Pratt, V.R. Fast pattern matching in strings"中Knuth提出了线性时间
构造delta2的方法。
参考论文["A Fast String Searching Algorithm"](https://www.cs.utexas.edu/users/moore/publications/fstrpos.pdf)
