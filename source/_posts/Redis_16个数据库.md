---
title: Redis 16个数据库
date:  2021-04-12 21:56:23
toc: true
tags: 
- redis
- 2021
- redis 进阶
categories:
- 知识体系
---

原文： https://haicoder.net/note/redis-interview/redis-interview-redis-database.html

## 描述

在实际项目中 **[Redis](https://haicoder.net/redis/redis-tutorial.html)** 常被应用于做缓存，分布式锁、消息队列等。但是在搭建配置好 Redis 服务器后很多朋友应该会发现和有这样的疑问，为什么 Redis 默认建立了 16 个数据库。
<!-- more -->

## 查看Redis数据库

我们在使用 **[redis-cli](https://haicoder.net/redis/redis-cli.html)** 连接到 Redis 服务器时，可以使用 SELECT 命令切换 Redis 的库，比如我们切换到第 16 号库，具体命令如下：

```
SELECT 15
```

执行完毕后，终端输出如下：

![02_Redis数据库.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-134955.png)

我们看到，Redis 的提示符前面显示 `[15]` 表明我们已经切换到了第 16 号库，现在，我们再次切换到第 10 号库，具体命令如下：

```
SELECT 11
```

执行完毕后，终端输出如下：

![03_Redis数据库.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-134958.png)

我们看到，现在我们切换到了第 11 号库，我们切换一个不存在的库，执行完毕后，终端输出如下：

![04_Redis数据库.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135001.png)

我们看到，此时提示我们数据库不存在。

## 16个数据库的由来

Redis 是一个字典结构的存储服务器，一个 Redis 实例提供了多个用来存储数据的字典，客户端可以指定将数据存储在哪个字典中。这与在一个关系数据库实例中可以创建多个数据库类似，所以可以将其中的每个字典都理解成一个独立的数据库。

Redis 默认支持 16 个数据库，可以通过调整 Redis 的配置文件 **[redis.conf](https://haicoder.net/redis/redis-config-get.html)** 中的 databases 来修改这一个值，设置完毕后重启 Redis 便完成配置，具体配置如下：

![05_Redis数据库.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135006.png)

客户端与 Redis 建立连接后会默认选择 0 号数据库，不过可以随时使用 SELECT 命令更换数据库如上操作所示。

## Redis的“数据库”概念

由于 Redis 不支持自定义数据库的名字，所以每个数据库都以编号命名。开发者则需要自己记录存储的数据与数据库的对应关系。另外 Redis 也不支持为每个数据库设置不同的访问密码，所以一个客户端要么可以访问全部数据库，要么全部数据库都没有权限访问。但是，要正确地理解 Redis 的 “数据库” 概念这里不得不提到一个命令：

```
# 清空一个Redis实例中所有数据库中的数据
redis 127.0.0.1:6379> FLUSHALL 
```

该命令可以清空实例下的所有数据库数据，这与我们所熟知的关系型数据库所不同。关系型数据库多个库常用于存储不同应用程序的数据 ，且没有方式可以同时清空实例下的所有库数据。

所以对于 Redis 来说这些 db 更像是一种命名空间，且不适宜存储不同应用程序的数据。比如可以使用 0 号数据库存储某个应用生产环境中的数据，使用 1 号数据库存储测试环境中的数据，但不适宜使用 0 号数据库存储 A 应用的数据而使用 1 号数据库 B 应用的数据，不同的应用应该使用不同的 Redis 实例存储数据。Redis 非常轻量级，一个空 Redis 实例占用的内在只有 1M 左右，所以不用担心多个 Redis 实例会额外占用很多内存。

## 集群

要注意以上所说的都是基于单体 Redis 的情况。而在集群的情况下不支持使用 SELECT 命令来切换 db，因为 Redis 集群模式下只有一个 db0。再扩展一些集群与单机 Reids 的区别：

- KEY 批量操作支持有限：例如 mget、mset 必须在一个 slot
- KEY 事务和 Lua 支持有限：操作的 KEY 必须在一个节点
- KEY 是数据分区的最小粒度：不支持 bigkey 分区
- 不支持多个数据库：集群模式下只有一个 db0
- 复制只支持一层：不支持树形复制结构

## 总结

Redis 实例默认建立了 16 个db，由于不支持自主进行数据库命名所以以 dbX 的方式命名。默认数据库数量可以修改配置文件的 database 值来设定。

对于 db 正确的理解应为 “命名空间”，多个应用程序不应使用同一个 Redis 不同库，而应一个应用程序对应一个 Redis 实例，不同的数据库可用于存储不同环境的数据。最后要注意，Redis 集群下只有 db0，不支持多 db。