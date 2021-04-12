---
title: Redis HyperLoglog
date:  2021-04-12 21:56:28
toc: true
tags: 
- redis
- 2021
- redis 进阶
categories:
- 知识体系
---

原文：https://haicoder.net/note/redis-interview/redis-interview-redis-hyperloglog.html

## 什么是HyperLoglog

HyperLoglog 是 **[Redis](https://haicoder.net/redis/redis-birth.html)** 新支持的两种类型中的另外一种(还有一种是位图类型 Bitmaps)，主要适用场景是海量数据的计算。特点是速度快，占用空间小。

HyperLogLog 是用来做基数统计的算法，HyperLogLog 的优点是，在输入元素的数量或者体积非常非常大时，计算基数所需的空间总是固定的、并且是很小的。在 Redis 里面，每个 HyperLogLog 键只需要花费 12KB 内存，就可以计算接近 2^64 个不同元素的基数。这和使用集合计算基数时，元素越多耗费内存就越多的集合形成鲜明对比。

但是，因为 HyperLogLog 只会根据输入元素来计算基数，而不会储存输入元素本身，所以 HyperLogLog 不能像集合那样，返回输入的各个元素。
<!-- more -->

## 特点

1. 用来做基数统计的算法，在输入的元素的数量或者体积非常大的时候，计算基数所需的空间总是固定的，并且是很小的。
2. 每一个 HyperLogLog 只需要花费 12KB 的内存就可以计算接近 2 的 64 次方不同元素的基数。
3. 因为 HyperLogLog 只会根据输入的元素来计算基数，而不会存储输入元素本身，所以，HyperLogLog 不能像集合那样，返回输入的各个元素。
4. 基数不存在重复的元素，例如：{1,3,4,5,6,6,7,8,9,9} 的基数集为 {1,3,4,5,6,7,8,9}，基数为 5，基数估计就是在误差可接受的范围内快速计算基数，但是该误差是在误差允许的范围内。

## HyperLoglog说明

1. HyperLogLog 是一种算法，并非 redis 独有。
2. 目的是做基数统计，故不是集合，不会保存元数据，只记录数量而不是数值。
3. 耗空间极小，支持输入非常体积的数据量。
4. 核心是基数估算算法，主要表现为计算时内存的使用和数据合并的处理。最终数值存在一定误差。
5. redis 中每个 hyperloglog key 占用了 12K 的内存用于标记基数（官方文档）。
6. pfadd 命令并不会一次性分配 12k 内存，而是随着基数的增加而逐渐增加内存分配；而 pfmerge 操作则会将 sourcekey 合并后存储在 12k 大小的 key 中，这由 hyperloglog 合并操作的原理（两个 hyperloglog 合并时需要单独比较每个桶的值）可以很容易理解。
7. 误差说明：基数估计的结果是一个带有 0.81% 标准错误（standard error）的近似值。是可接受的范围。
8. Redis 对 HyperLogLog 的存储进行了优化，在计数比较小时，它的存储空间采用稀疏矩阵存储，空间占用很小，仅仅在计数慢慢变大，稀疏矩阵占用空间渐渐超过了阈值时才会一次性转变成稠密矩阵，才会占用 12k 的空间。

## HyperLoglog与bitmaps

同样是用于计算，HyperLoglog 在适用场景方面与 Bitmaps 方面有什么不同呢，Bitmaps 更适合用于验证的大数据，比如签到，记录某用户是不是当天进行了签到，签到了多少天的时候。也就是说，你不光需要记录数据，还需要对数据进行验证的时候使用 Bitmaps。

HyperLoglog 则用于只记录的时候，比如访问的 uv 统计。

## 应用

1. 基数不大、数据量不到的时候就没必要用基数。
2. 只能统计基数数量，不能获取具体内容，即：不能存储数据。
3. 统计每一个用户点击博客的次数，只会计数一次，点击完第一次后，不会再随点击次数的增加而增加访问量。

## 原理

HyperLogLog 原理思路是通过给定 n 个的元素集合，记录集合中数字的比特串第一个 1 出现位置的最大值k，也可以理解为统计二进制低位连续为零的最大个数。通过 k 值可以估算集合中不重复元素的数量 m，m 近似等于 2^k。

也可以说其实 Redis HyperLogLog 的原理就是一种概率算法。

## HyperLoglog相关命令

### PFADD

#### 语法

```
PFADD key element [element ...]
```

#### 时间复杂度

O(1)

#### 说明

将除了第一个参数以外的参数存储到以第一个参数为变量名的 HyperLogLog 结构中。这个命令的一个副作用是它可能会更改这个 HyperLogLog 的内部来反映在每添加一个唯一的对象时估计的基数(集合的基数)。

如果一个 HyperLogLog 的估计的近似基数在执行命令过程中发了变化，PFADD 返回 1，否则返回 0，如果指定的 key 不存在，这个命令会自动创建一个空的 HyperLogLog 结构（指定长度和编码的字符串）。 如果在调用该命令时仅提供变量名而不指定元素也是可以的，如果这个变量名存在，则不会有任何操作，如果不存在，则会创建一个数据结构。

#### 返回值

如果 HyperLoglog 的内部被修改了，那么返回 1，否则返回 0。

### PFCOUNT

#### 语法

```
PFCOUNT key [key ...]
```

#### 说明

当参数为一个 key 时，返回存储在 HyperLogLog 结构体的该变量的近似基数，如果该变量不存在，则返回 0。当参数为多个 key 时，返回这些 HyperLogLog 并集的近似基数，这个值是将所给定的所有 key 的 HyperLoglog 结构合并到一个临时的 HyperLogLog 结构中计算而得到的。

HyperLogLog 可以使用固定且很少的内存（每个 HyperLogLog 结构需要 12K 字节再加上 key 本身的几个字节）来存储集合的唯一元素。返回的可见集合基数并不是精确值， 而是一个带有 0.81% 标准错误（standard error）的近似值。

#### 返回值

PFADD 添加的唯一元素的近似数量。

### PFMERGE

#### 语法

```
PFMERGE destkey sourcekey [sourcekey ...]
```

#### 说明

将多个 HyperLogLog 合并（merge）为一个 HyperLogLog，合并后的 HyperLogLog 的基数接近于所有输入 HyperLogLog 的可见集合（observed set）的并集。合并得出的 HyperLogLog 会被储存在目标变量（第一个参数）里面， 如果该键并不存在，那么命令在执行之前，会先为该键创建一个空的。

#### 返回值

这个命令只会返回 OK。

## 案例

### pfadd

我们可以使用 pfadd 添加元素，具体过程如下：

![31_redis hyperloglog.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-134928.png)

我们使用了 pfadd 命令添加了五个元素到键 haicoder.net 中。

### pfcount

我们可以使用 pfcount 返回基数的个数，具体过程如下：

![32_redis hyperloglog.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-134931.png)

我们首先使用了 PFADD 添加了五个元素，接着，我们使用 PFCOUNT 查看基数的个数此时为 5，接着，我们再次使用 PFADD 添加一个元素，此时返回了 6，最后，我们添加一个已经存在的元素，此时基数的个数并未增加。

### pfmerge

我们可以使用 pfadd 添加元素，具体过程如下：

![33_redis hyperloglog.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-134934.png)

我们可以看出，使用 pfmerge 合并两个键时，重复的元素只会被算一次。

## Redis HyperLoglog应用

### 说明

1. 基数不大，数据量不大就用不上，会有点大材小用浪费空间。
2. 有局限性，就是只能统计基数数量，而没办法去知道具体的内容是什么。
3. 和 bitmap 相比，属于两种特定统计情况，简单来说，HyperLogLog 去重比 bitmap 方便很多。
4. 一般可以 bitmap 和 hyperloglog 配合使用，bitmap 标识哪些用户活跃，hyperloglog 计数。

### 一般使用

1. 统计注册 IP 数
2. 统计每日访问 IP 数
3. 统计页面实时 UV 数
4. 统计在线用户数
5. 统计用户每天搜索不同词条的个数