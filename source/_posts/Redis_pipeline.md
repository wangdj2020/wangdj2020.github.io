---
title: Redis pipeline
date:  2021-04-12 22:00:29
toc: true
tags: 
- redis
- 2021
- redis 进阶
categories:
- 知识体系
---

原文：https://haicoder.net/note/redis-interview/redis-interview-redis-pipeline.html

## 什么是Redis pipeline

**[Redis](https://haicoder.net/redis/redis-tutorial.html)** 中的 Pipeline 指的是管道技术，指的是客户端允许将多个请求依次发给服务器，过程中而不需要等待请求的回复，在最后再一并读取结果即可。
<!-- more -->

## 为什么需要pipeline

redis 客户端执行一条命令分 4 个过程：

![15_redis pipeline管道.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-134939.png)

这个过程称为 Round trip time(简称 RTT, 往返时间)，Redis 中的 mget 和 mset 有效节约了 RTT，但大部分命令（如 **[hgetall](https://haicoder.net/redis/redis-hgetall.html)**，并没有 mhgetall）不支持批量操作，需要消耗 N 次 RTT ，这个时候需要 pipeline 来解决这个问题。

## pipeline管道性能

如果我们使用正常的一次发送一条命令，具体的流程如下图所示：

![16_redis pipeline管道.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-134942.png)

Redis 通过 **[TCP](https://haicoder.net/tcp/tcpip-tutorial.html)** 来对外提供服务，Client 通过 Socket 连接发起请求，每个请求在命令发出后会阻塞等待 Redis 服务器进行处理，处理完毕后将结果返回给 client。

Redis 的 Client 和 Server 是采用一问一答的形式进行通信，请求一次给一次响应。而这个过程在排除掉 Redis 服务本身做复杂操作时的耗时的话，可以看到最耗时的就是这个网络传输过程。每一个命令都对应了发送、接收两个网络传输，假如一个流程需要 0.1 秒，那么 1 秒最多只能处理 10 个请求，将严重制约 Redis 的性能。

在很多场景下，我们要完成一个业务，可能会对 redis 做连续的多个操作，譬如库存减一、订单加一、余额扣减等等，这有很多个步骤是需要依次连续执行的。

如果我们使用 Redis 的管道 pipeline 来优化上述流程，那么具体的流程图如下图所示：

![17_redis pipeline管道.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-134949.png)

在未使用管道 pipeline 技术时，一个请求会遵循两个步骤，即首先客户端向服务端发送一个查询请求，并监听 Socket 返回，通常是以阻塞模式，等待服务端响应。 最后服务端处理命令，并将结果返回给客户端。

Redis 管道技术可以在服务端未响应时，客户端可以继续向服务端发送请求，并最终一次性读取所有服务端的响应。这样可以最大限度的利用 Redis 的高性能并节省不必要的网络 IO 开销。

## 原生批命令与Pipeline对比

1. 原生批命令是原子性，pipeline 是非原子性（原子性概念：一个事务是一个不可分割的最小工作单位，要么都成功要么都失败。原子操作是指你的一个业务逻辑必须是不可拆分的，处理一件事情要么都成功，要么都失败，原子不可拆分。）
2. 原生批命令一命令多个 key, 但 pipeline 支持多命令（存在事务），非原子性。
3. 原生批命令是服务端实现，而 pipeline 需要服务端与客户端共同完成。

## pipeline原理

管道（pipeline）可以一次性发送多条命令并在执行完后一次性将结果返回，pipeline 通过减少客户端与 redis 的通信次数来实现降低往返延时时间，而且 Pipeline 实现的原理是队列，而队列的原理是时先进先出，这样就保证数据的顺序性。

Pipeline 的默认的同步的个数为 53 个，也就是说 arges 中累加到 53 条数据时会把数据提交。其过程可以理解为 client 可以将多个命令放到一个 tcp 报文一起发送，server 则可以将多条命令的处理结果放到一个 tcp 报文返回。

pipeline “打包命令” 客户端将多个命令缓存起来，缓冲区满了就发送(将多条命令打包发送)；有点像 “请求合并”。服务端接受一组命令集合，切分后逐个执行并一起返回。

## Pipeline使用注意

不过在编码时请注意，pipeline 期间将 “独占” 链接，此期间将不能进行非 “管道” 类型的其他操作，直到 pipeline 关闭；如果你的 pipeline 的指令集很庞大，为了不干扰链接中的其他操作，你可以为 pipeline 操作新建 Client 链接，让 pipeline 和其他正常操作分离在 2 个 client 中。

不过 pipeline 事实上所能容忍的操作个数，和 socket-output 缓冲区大小/返回结果的数据尺寸都有很大的关系；同时也意味着每个 redis-server 同时所能支撑的 pipeline 链接的个数，也是有限的，这将受限于 server 的物理内存或网络接口的缓冲能力。

同时，使用 pipeline 方式打包命令发送，redis 必须在处理完所有命令前先缓存起所有命令的处理结果。打包的命令越多，缓存消耗内存也越多。所以并不是打包的命令越多越好。具体多少合适需要根据具体情况测试。

## pipeline的局限性

pipeline 只能用于执行连续且无相关性的命令，当某个命令的生成需要依赖于前一个命令的返回时(或需要一起执行时)，就无法使用 pipeline 了。通过 scripting 功能，可以规避这一局限性。

有些系统可能对可靠性要求很高，每次操作都需要立马知道这次操作是否成功，是否数据已经写进 redis 了，如 Redis 实现分布式锁等，那这种场景就不适合了。