---
title: Redis集群Twemproxy与Codis
date:  2021-04-12 21:56:35
toc: true
tags: 
- redis
- 2021
- redis 进阶
categories:
- 知识体系
---

原文：https://haicoder.net/note/redis-interview/redis-interview-redis-twemproxy-codis.html

## Redis常见集群技术

长期以来，**[Redis](https://haicoder.net/redis/redis-tutorial.html)** 本身仅支持单实例，内存一般最多 10~20GB。这无法支撑大型线上业务系统的需求。而且也造成资源的利用率过低——毕竟现在服务器内存动辄 100~200GB。

为解决单机承载能力不足的问题，各大互联网企业纷纷出手，“自助式” 地实现了集群机制。在这些非官方集群解决方案中，物理上把数据 “分片”（sharding）存储在多个 Redis 实例，一般情况下，每一 “片” 是一个 Redis 实例。

包括官方推出的 **Redis Cluster**，Redis 集群有三种实现机制，分别介绍如下，希望对大家选型有所帮助。
<!-- more -->

### 客户端分片

这种方案将分片工作放在业务程序端，程序代码根据预先设置的路由规则，直接对多个 Redis 实例进行分布式访问。这样的好处是，不依赖于第三方分布式中间件，实现方法和代码都自己掌控，可随时调整，不用担心踩到坑。

这实际上是一种静态分片技术。Redis 实例的增减，都得手工调整分片程序。基于此分片机制的开源产品，现在仍不多见。

这种分片机制的性能比代理式更好（少了一个中间分发环节）。但缺点是升级麻烦，对研发人员的个人依赖性强——需要有较强的程序开发能力做后盾。如果主力程序员离职，可能新的负责人，会选择重写一遍。

所以，这种方式下，可运维性较差。出现故障，定位和解决都得研发和运维配合着解决，故障时间变长。这种方案，难以进行标准化运维，不太适合中小公司（除非有足够的 DevOPS）。

### 代理分片

这种方案，将分片工作交给专门的代理程序来做。代理程序接收到来自业务程序的数据请求，根据路由规则，将这些请求分发给正确的 Redis 实例并返回给业务程序。

这种机制下，一般会选用第三方代理程序（而不是自己研发），因为后端有多个 Redis 实例，所以这类程序又称为分布式中间件。

这样的好处是，业务程序不用关心后端 Redis 实例，运维起来也方便。虽然会因此带来些性能损耗，但对于 Redis 这种内存读写型应用，相对而言是能容忍的。

这是我们推荐的集群实现方案。像基于该机制的开源产品 Twemproxy，便是其中代表之一，应用非常广泛。

### Redis Cluster

在这种机制下，没有中心节点（和代理模式的重要不同之处）。所以，一切开心和不开心的事情，都将基于此而展开。

Redis Cluster 将所有 Key 映射到 16384 个 Slot 中，集群中每个 Redis 实例负责一部分，业务程序通过集成的 Redis Cluster 客户端进行操作。客户端可以向任一实例发出请求，如果所需数据不在该实例中，则该实例引导客户端自动去对应实例读写数据。

Redis Cluster 的成员管理（节点名称、IP、端口、状态、角色）等，都通过节点之间两两通讯，定期交换并更新。由此可见，这是一种非常 “重” 的方案。已经不是 Redis 单实例的 “简单、可依赖” 了。可能这也是延期多年之后，才近期发布的原因之一。

这令人想起一段历史。因为 **[Memcache](https://haicoder.net/memcached/memcached-tutorial.html)** 不支持持久化，所以有人写了一个 Membase，后来改名叫 Couchbase，说是支持 Auto Rebalance，好几年了，至今都没多少家公司在使用。这是个令人忧心忡忡的方案。为解决仲裁等集群管理的问题，Oracle RAC 还会使用存储设备的一块空间。而 Redis Cluster，是一种完全的去中心化。本方案目前不推荐使用，从了解的情况来看，线上业务的实际应用也并不多见。

## Twemproxy集群

### 概念

Twemproxy 是一种代理分片机制，由 Twitter 开源。Twemproxy 作为代理，可接受来自多个程序的访问，按照路由规则，转发给后台的各个 Redis 服务器，再原路返回。这个方案顺理成章地解决了单个 Redis 实例承载能力的问题。当然，Twemproxy 本身也是单点，需要用 Keepalived 做高可用方案。

我想很多人都应该感谢 Twemproxy，这么些年来，应用范围最广、稳定性最高、最久经考验的分布式中间件，应该就是它了。只是，他还有诸多不方便之处。Twemproxy 最大的痛点在于，无法平滑地扩容/缩容。

这样导致运维同学非常痛苦：业务量突增，需增加 Redis 服务器；业务量萎缩，需要减少 Redis 服务器。但对 Twemproxy 而言，基本上都很难操作（那是一种锥心的、纠结的痛……）。或者说，Twemproxy 更加像服务器端静态 sharding。有时为了规避业务量突增导致的扩容需求，甚至被迫新开一个基于 Twemproxy 的 Redis 集群。

Twemproxy 另一个痛点是，运维不友好，甚至没有控制面板。Codis 刚好击中 Twemproxy 的这两大痛点，并且提供诸多其他令人激赏的特性。

### 架构

![62_redis集群.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135137.png)

### 特性

Twemproxy 搭建 redis 集群有以下的优势：

1. 快速 – 据测试，直连 twenproxy 和直连 redis 相比几乎没有性能损失，读写分离后更是能够极大地提高集群响应能力。
2. 轻量级 – Twemproxy 通过透明连接池、内存零拷贝以及 epoll 模型实现了足够的快速和轻量化，源码较为简洁精炼。
3. 降低负载 – 透明连接池保持前端的连接数，减少后端的连接数，让后端的 redis 节点负载大为降低。
4. 分片 – Twemproxy 通过一致性 hash 算法将数据进行分片，从而实现 redis 集群的高速缓存，降低负载。
5. 多协议 – 同时支持 redis 与 memcache 集群的搭建。
6. 多算法 – 支持多种算法实现一致性哈希分片，包括 crc32，crc16，MD5 等。
7. 配置简单 - 配置非常简单，易上手。
8. 监控报警丰富 – 虽然他提供的原生监控功能一般较少使用，但其提供的统计信息，如发送了多少读写命令还是有很大的价值的。

### 缺点

Twemproxy 也有着明显的缺点：

1. 单点 – Twemproxy 只实现了静态分片的功能，本身不具备集群功能，但可以通过 keepalive 来解决。
2. 运维不友好 – 没有提供控制面板。
3. 无法平滑地扩容/缩容 – 这是一个非常大的缺陷，虽然我们可以通过技术手段和方案来尽量避免，但对于运维人员来说仍然是有很大压力的。

## Codis集群

### 概念

Codis 由豌豆荚于 2014 年 11 月开源，基于 **Go 语言** 和 **C 语言** 开发，是近期涌现的、国人开发的优秀开源软件之一。现已广泛用于豌豆荚的各种 Redis 业务场景。

从 3 个月的各种压力测试来看，稳定性符合高效运维的要求。性能更是改善很多，最初比 Twemproxy 慢 20%；现在比 Twemproxy 快近100%（条件：多实例，一般 Value 长度）。

### 体系架构

Codis 引入了 Group 的概念，每个 Group 包括 1 个 Redis Master 及至少 1 个 Redis Slave，这是和 Twemproxy 的区别之一。这样做的好处是，如果当前 Master 有问题，则运维人员可通过 Dashboard “自助式” 切换到 Slave，而不需要小心翼翼地修改程序配置文件。

为支持数据热迁移（Auto Rebalance），出品方修改了 Redis Server 源码，并称之为 Codis Server。

Codis 采用预先分片（Pre-Sharding）机制，事先规定好了，分成 1024 个 slots（也就是说，最多能支持后端 1024 个 Codis Server），这些路由信息保存在 ZooKeeper 中。ZooKeeper 还维护 Codis Server Group 信息，并提供分布式锁等服务。

### 性能对比测试

Codis 目前仍被精益求精地改进中。其性能，从最初的比 Twemproxy 慢 20%（虽然这对于内存型应用而言，并不明显），到现在远远超过 Twemproxy 性能（一定条件下）。

我们进行了长达 3 个月的测试。测试基于 redis-benchmark，分别针对 Codis 和 Twemproxy，测试 Value 长度从 16B~10MB 时的性能和稳定性，并进行多轮测试。

一共有 4 台物理服务器参与测试，其中一台分别部署 codis 和 twemproxy，另外三台分别部署 codis server 和 redis server，以形成两个集群。

从测试结果来看，就 Set 操作而言，在 Value 长度 <888B 时，Codis 性能优越优于 Twemproxy（这在一般业务的 Value 长度范围之内）。就 Get 操作而言，Codis 性能一直优于 Twemproxy。

### 架构图

![63_redis集群.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135142.png)

### Codis的优势

Codis 有着以下优点：

1. 数据热迁移 – 这是 Redis 最大的优势，这也是他被广为使用的最大原因。
2. 运维界面友好 – 提供 slot 状态、Proxy 状态、group 状态、lock、action 等的丰富监控和显示。
3. 故障处理灵活 – 本身只监控和报告故障，提供 API 对故障进行处理，从而让运维能够实现灵活的故障处理方案。
4. 架构清晰 – 如上图所示，整个架构清晰，组件高度内聚，故障的发现和处理变得更为容易。
5. 除此以外，Codis 还提供了从 Twemproxy 到 Codis 的一键迁移工具。

目前来说，国内对 Codis 的使用非常普遍，也是对其优点的群众认可吧。

### Codis的缺点

Codis 也具有以下明显的缺点：

1. 版本滞后 – 因为在 redis 源码基础上进行二次开发，所以很难跟上最新版 redis 的脚步，目前最新的 Codis-3.2 基于 Redis-3.2.8 版本。
2. 部署复杂 – 部署过程至少要进行 codis-dashboard、codis-proxy、codis-server、codis-fe 四个组件的部署和启动。
3. 单节点性能低 – 如果仅有一个 codis-server，性能低于原生 redis 20% 左右。
4. 更新频率低

## codis和twemproxy区别

codis 和 twemproxy 最大的区别有两个：

1. codis 支持动态水平扩展，对 client 完全透明不影响服务的情况下可以完成增减 redis 实例的操作；
2. codis 是用 go 语言写的并支持多线程，twemproxy 用 C 并只用单线程。 后者又意味着：codis 在多核机器上的性能会好于 twemproxy；codis 的最坏响应时间可能会因为 GC 的 STW 而变大。