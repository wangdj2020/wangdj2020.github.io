---
title: Redis内存碎片
date:  2021-04-12 21:56:36
toc: true
tags: 
- redis
- 2021
- redis 进阶
categories:
- 知识体系
---

原文： https://haicoder.net/note/redis-interview/redis-interview-redis-mem-fragme.html

## 查看Redis内存碎片率

在 **[Redis](https://haicoder.net/redis/redis-tutorial.html)** 使用过程中，经常会产生内存碎片，如果我们需要查看 Redis 的内存碎片率，我们可以使用 **[INFO](https://haicoder.net/redis/redis-info.html)** 命令，具体命令如下：

```
INFO Memory
```
<!-- more -->

执行完毕后，如下图所示：

![66_redis内存使用率查看.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135146.png)

其中，mem_fragmentation_ratio 显示的就是内存使用率，其具体的计算公式为：

```
mem_fragmentation_ratio = used_memory_rss / used_memory
```

其中，used_memory_rss 是 Redis 向操作系统申请的内存。used_memory 是 Redis 中的数据占用的内存。

## 内存碎片如何产生的

Redis 内部有自己的内存管理器，为了提高内存使用的效率，来对内存的申请和释放进行管理。Redis 中的值删除的时候，并没有把内存直接释放，交还给操作系统，而是交给了 Redis 内部有内存管理器。

Redis 中申请内存的时候，也是先看自己的内存管理器中是否有足够的内存可用。Redis 的这种机制，提高了内存的使用率，但是会使 Redis 中有部分自己没在用，却不释放的内存，导致了内存碎片的发生。

## 碎片率的意义

mem_fragmentation_ratio 的不同值，说明不同的情况。

1. 大于1：说明内存有碎片，一般在 1 到 1.5 之间是正常的。
2. 大于1.5：说明内存碎片率比较大，需要考虑是否要进行内存碎片清理，要引起重视。
3. 小于1：说明已经开始使用交换内存，也就是使用硬盘了，正常的内存不够用了，需要考虑是否要进行内存的扩容。

## 解决碎片率大的问题

### 低于4.0版本的Redis

如果你的 Redis 版本是 4.0 以下的，Redis 服务器重启后，Redis 会将没用的内存归还给操作系统，碎片率会降下来。

### 高于4.0版本的Redis

Redis 4.0 版本开始，可以在不重启的情况下，线上整理内存碎片。自动碎片清理，只要设置了如下的配置，内存就会自动清理了：

```
config set activedefrag yes
```

如果想把 Redis 的配置，写到配置文件中去：

```
config rewrite
```

如果你对自动清理的效果不满意，可以使用如下命令，直接试下手动碎片清理：

```
memory purge
```