---
title: Redis底层数据结构
date:  2021-04-12 21:56:31
toc: true
tags: 
- redis
- 2021
- redis 进阶
categories:
- 知识体系
---

原文：https://haicoder.net/note/redis-interview/redis-interview-redis-implement.html

**[Redis](https://haicoder.net/redis/redis-tutorial.html)** 的五大数据类型也称五大数据对象，即分别为 **[string](https://haicoder.net/redis/redis-string.html)**、 **[list](https://haicoder.net/redis/redis-list.html)**、 **[hash](https://haicoder.net/redis/redis-hash.html)**、 **[set](https://haicoder.net/redis/redis-sset.html)** 和 **[zset](https://haicoder.net/redis/redis-sortedset.html)**，但 Redis 并没有直接使用这些结构来实现键值对数据库，而是使用这些结构构建了一个对象系统 redisObject。

这个对象系统包含了五大数据对象，字符串对象（string）、列表对象（list）、哈希对象（hash）、集合（set）对象和有序集合对象（zset）；而这五大对象的底层数据编码可以用命令 OBJECT ENCODING 来进行查看。
<!-- more -->

## Redis对象

Redis 基于上述的数据结构自定义一个 Object 系统，Object 结构，即 redisObject 结构：

```
typedef struct redisObject{
	//类型
	unsigned type:4;
	//编码
	unsigned encoding:4;
	//指向底层实现数据结构的指针
	void *ptr;
	…..
}
```

Object 系统包含五种 Object：

- String：字符串对象
- List：列表对象
- Hash：哈希对象
- Set：集合对象
- ZSet：有序集合

Redis 使用对象来表示数据库中的键和值，即每新建一个键值对，至少创建有两个对象，而且使用对象的具有以下好处：

1. redis 可以在执行命令前会根据对象的类型判断一个对象是否可以执行给定的命令。
2. 针对不同的使用场景，为对象设置不同的数据结构实现，从而优化对象的不同场景夏的使用效率。
3. 对象系统还可以基于引用计数计数的内存回收机制，自动释放对象所占用的内存，或者还可以让多个数据库键共享同一个对象来节约内存。
4. redis 对象带有访问时间记录信息，使用该信息可以进行优化空转时长较大的 key，进行删除！

对象的 ptr 指针指向对象的底层现实数据结构，而这些数据结构由对象的 encoding 属性决定，对应关系：

| 编码常量                  | 编码对应的底层数据结构      |
| ------------------------- | --------------------------- |
| REDIS_ENCODING_INT        | long 类型的整数             |
| REDIS_ENCODING_EMBSTR     | embstr 编码的简单动态字符串 |
| REDIS_ENCODING_RAW        | 简单动态字符串              |
| REDIS_ENCODING_HT         | 字典                        |
| REDIS_ENCODING_LINKEDLIST | 双向链表                    |
| REDIS_ENCODING_ZIPLIST    | 压缩列表                    |
| REDIS_ENCODING_INTSET     | 整数集合                    |
| REDIS_ENCODING_SKIPLIST   | 跳跃表和字典                |

每种 Object 对象至少有两种不同的编码，对应关系：

| 类型       | 编码       | 对象              |
| ---------- | ---------- | ----------------- |
| String     | int        | 整数值实现        |
| String     | embstr     | sds实现 <=39 字节 |
| String     | raw        | sds实现 > 39字节  |
| List       | ziplist    | 压缩列表实现      |
| List       | linkedlist | 双端链表实现      |
| Set        | intset     | 整数集合使用      |
| Set        | hashtable  | 字典实现          |
| Hash       | ziplist    | 压缩列表实现      |
| Hash       | hashtable  | 字典使用          |
| Sorted set | ziplist    | 压缩列表实现      |
| Sorted set | skiplist   | 跳跃表和字典      |

## String对象实现

### 说明

字符串对象底层数据结构实现为简单动态字符串（SDS）和直接存储，但其编码方式可以是 int、raw 或者 embstr，区别在于内存结构的不同。

### 结构

#### int编码

字符串保存的是整数值，并且这个正式可以用 long 类型来表示，那么其就会直接保存在 redisObject 的 ptr 属性里，并将编码设置为 int，如图：

![69_redis底层数据结构实现.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135027.png)

#### raw编码

字符串保存的大于 32 字节的字符串值，则使用简单动态字符串（SDS）结构，并将编码设置为 raw，此时内存结构与 SDS 结构一致，内存分配次数为两次，创建 redisObject 对象和 sdshdr 结构，如图：

![70_redis底层数据结构实现.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135031.png)

#### embstr编码

字符串保存的小于等于 32 字节的字符串值，使用的也是简单的动态字符串（SDS 结构），但是内存结构做了优化，用于保存顿消的字符串；内存分配也只需要一次就可完成，分配一块连续的空间即可，如图：

![71_redis底层数据结构实现.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135035.png)

### String对象之间的编码转换

int 编码的字符串对象和 embstr 编码的字符串对象在条件满足的情况下，会被转换为 raw 编码的字符串对象。比如：对 int 编码的字符串对象进行 append 命令时，就会使得原来是 int 变为 raw 编码字符串。

### C字符串与SDS

| C 字符串                                       | SDS                                        |
| ---------------------------------------------- | ------------------------------------------ |
| 获取字符串长度的复杂度为 O(N)                  | 获取字符串长度的复杂度为 O(1)              |
| API 是不安全的，可能会造成缓冲区溢出           | API 是安全的，不会造成缓冲区溢出           |
| 修改字符串长度 N 次必然需要执行 N 次内存重分配 | 修改字符串长度 N 次最多执行 N 次内存重分配 |
| 只能保存文本数据                               | 可以保存二进制数据和文本文数据             |
| 可以使用所有 <String.h> 库中的函数             | 可以使用一部分 <string.h> 库中的函数       |

### 总结

1. 在 Redis 中，存储 long、double 类型的浮点数是先转换为字符串再进行存储的。
2. raw 与 embstr 编码效果是相同的，不同在于内存分配与释放，raw 两次，embstr 一次。
3. embstr 内存块连续，能更好的利用缓存在来的优势。
4. int 编码和 embstr 编码如果做追加字符串等操作，满足条件下会被转换为 raw 编码；embstr 编码的对象是只读的，一旦修改会先转码到 raw。

## List对象

### 说明

list 对象可以为 ziplist 或者为 linkedlist，对应底层实现 ziplist 为压缩列表，linkedlist 为双向列表。

### 结构

比如如下结构：

```
Redis> RPUSH numbers "CcWw" 520 1
```

用 ziplist 编码的 List 对象结构：

![72_redis底层数据结构实现.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135038.png)

用 linkedlist 编码的 List 对象结构：

![73_redis底层数据结构实现.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135041.png)

### 压缩表结构

压缩表各部分组成说明如下：

**zlbytes**：记录整个压缩列表占用的内存字节数，在压缩列表内存重分配，或者计算 zlend 的位置时使用。

**zltail**：记录压缩列表表尾节点距离压缩列表的起始地址有多少字节，通过该偏移量，可以不用遍历整个压缩列表就可以确定表尾节点的地址。

**zllen**：记录压缩列表包含的节点数量，但该属性值小于 UINT16_MAX（65535）时，该值就是压缩列表的节点数量，否则需要遍历整个压缩列表才能计算出真实的节点数量。

**entryX**：压缩列表的节点。

**zlend**：特殊值 0xFF（十进制 255），用于标记压缩列表的末端。

### List对象的编码转换

当 list 对象可以同时满足以下两个条件时，list 对象使用的是 ziplist 编码：

1. list 对象保存的所有字符串元素的长度都小于 64 字节。
2. list 对象保存的元素数量小于 512 个。

不能满足这两个条件的 list 对象需要使用 linkedlist 编码。

## Hash对象

### 说明

Hash 对象的编码可以是 ziplist 或者 hashtable，其中，ziplist 底层使用压缩列表实现：

1. 保存同一键值对的两个节点紧靠相邻，键 key 在前，值 vaule 在后。
2. 先保存的键值对在压缩列表的表头方向，后来在表尾方向。

hashtable 底层使用字典实现，Hash 对象种的每个键值对都使用一个字典键值对保存：

1. 字典的键为字符串对象，保存键 key。
2. 字典的值也为字符串对象，保存键值对的值。

### 结构

比如 HSET 命令：

```
redis>HSET author name  "Ccww"
(integer)
redis>HSET author age  18
(integer)
redis>HSET author sex  "male"
(integer)
```

ziplist 的底层结构：

![74_redis底层数据结构实现.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135046.png)

hashtable 底层结构：

![75_redis底层数据结构实现.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135049.png)

### Hash对象的编码转换

当 list 对象可以同时满足以下两个条件时，list 对象使用的是 ziplist 编码：

1. list 对象保存的所有字符串元素的长度都小于 64 字节。
2. list 对象保存的元素数量小于 512 个。

不能满足这两个条件的 hash 对象需要使用 hashtable 编码，但这两个条件的上限值是可以修改的，可查看配置文件 hash-max-zaiplist-value 和 hash-max-ziplist-entries。

## Set对象

### 说明

Set 对象的编码可以为 intset 或者 hashtable：

1. **intset 编码**：使用整数集合作为底层实现，set 对象包含的所有元素都被保存在 intset 整数集合里面。
2. **hashtable 编码**：使用字典作为底层实现，字典键 key 包含一个 set 元素，而字典的值则都为 null。

### 结构

inset 编码 Set 对象结构：

```
redis> SAD number  1 3 5
```

![76_redis底层数据结构实现.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135053.png)

hashtable 编码 Set 对象结构：

```
redis> SAD Dfruits  “apple”  "banana" " cherry"
```

![77_redis底层数据结构实现.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135055.png)

### Set对象的编码转换

使用 intset 编码：

1. set 对象保存的所有元素都是整数值。
2. set 对象保存的元素数量不超过 512 个。

不能满足这两个条件的 Set 对象使用 hashtable 编码。

## ZSet对象

### 说明

ZSet 对象的编码可以为 ziplist 或者 skiplist，ziplist 编码，每个集合元素使用相邻的两个压缩列表节点保存，一个保存元素成员，一个保存元素的分值，然后根据分数进行从小到大排序。

### 结构

ziplist 编码的 ZSet 对象结构：

```
Redis>ZADD price 8.5 apple 5.0 banana 6.0 cherry
```

![78_redis底层数据结构实现.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135058.png)

skiplist 编码的 ZSet 对象使用了 zset 结构，包含一个字典和一个跳跃表：

```
Type struct zset{
    Zskiplist *zsl；
    dict *dict；
    ...
}
```

### ZSet对象的编码转换

当 ZSet 对象同时满足以下两个条件时，对象使用 ziplist 编码：

1. 有序集合保存的元素数量小于 128 个。
2. 有序集合保存的所有元素的长度都小于 64 字节。

不能满足以上两个条件的有序集合对象将使用 skiplist 编码，同时，可以通过配置文件中 zset-max-ziplist-entries 和 zset-max-ziplist-vaule 来改变这个数值。

## Redis底层数据结构总结

Redis 的 redisObject 结构如下图：

![79_redis底层数据结构实现.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135102.png)

五大数据类型对应的底层数据结构如下图所示：

![80_redis底层数据结构实现.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135105.png)