---
title: 查看Redis内存使用
date:  2021-04-12 21:56:15
toc: true
tags: 
- redis
- 2021
- redis 进阶
categories:
- 知识体系
---


原文： https://haicoder.net/note/redis-interview/redis-interview-redis-memory.html

## 查看Redis内存使用

在 **[Redis](https://haicoder.net/redis/redis-tutorial.html)** 使用过程中，如果我们需要查看 Redis 的内存使用情况，我们可以使用 **[INFO](https://haicoder.net/redis/redis-info.html)** 命令，具体命令如下：

```
INFO
```
<!-- more -->

执行完毕后，如下图所示：

![64_redis内存使用查看.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-134640.png)

我们可以看到，此时输出了所有的 Redis 的使用信息，如果我们仅仅需要查看内存的使用，我们还可以使用如下命令：

```
INFO Memory
```

执行完毕后，如下图所示：

![65_redis内存使用查看.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-134644.png)

其中，具体每项解释如下：

| 字段                      | 说明                                                         |
| ------------------------- | ------------------------------------------------------------ |
| used_memory               | 由 redis 分配器分配的内存总量，以字节为单位                  |
| used_memory_human         | 易读方式                                                     |
| used_memory_rss           | 从操作系统的角度，返回 redis 已分配的内存总量(俗称常驻集大小) |
| used_memory_rss_human     | 易读方式                                                     |
| used_memory_peak          | redis 的内存消耗峰值(以字节为单位)                           |
| used_memory_peak_human    | 易读方式                                                     |
| total_system_memory       | 系统内存总量                                                 |
| total_system_memory_human | 易读方式                                                     |
| used_memory_lua           | Lua 引擎使用的字节量                                         |
| used_memory_lua_human     | 易读方式                                                     |
| maxmemory                 | 配置设置的最大可使用内存值                                   |
| maxmemory_human           | 易读方式                                                     |
| maxmemory_policy          | 内存淘汰策略                                                 |
| mem_fragmentation_ratio   | used_memory_rss 和 used_memory 之间的比率                    |
| mem_allocator             | 在编译时指定的， Redis 所使用的内存分配器。可以是 libc 、 jemalloc 或者 tcmalloc |

在理想情况下， used_memory_rss 的值应该只比 used_memory 稍微高一点儿。当 rss > used ，且两者的值相差较大时，表示存在（内部或外部的）内存碎片。内存碎片的比率可以通过 mem_fragmentation_ratio 的值看出。

当 used > rss 时，表示 Redis 的部分内存被操作系统换出到交换空间了，在这种情况下，操作可能会产生明显的延迟。当 Redis 释放内存时，分配器可能会，也可能不会，将内存返还给操作系统。

如果 Redis 释放了内存，却没有将内存返还给操作系统，那么 used_memory 的值可能和操作系统显示的 Redis 内存占用并不一致。查看 used_memory_peak 的值可以验证这种情况是否发生。