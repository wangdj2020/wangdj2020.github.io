---
title: Redis主从模式
date:  2021-04-12 21:56:44
toc: true
tags: 
- redis
- 2021
- redis 进阶
categories:
- 知识体系
---

原文： https://haicoder.net/note/redis-interview/redis-interview-redis-master-slave.html

## 什么是Redis主从模式

使用一个 **[Redis](https://haicoder.net/redis/redis-tutorial.html)** 实例作为主机，其余的作为备份机。主机和备份机的数据完全一致，主机支持数据的写入和读取等各项操作，而从机则只支持与主机数据的同步和读取。也就是说，客户端可以将数据写入到主机，由主机自动将数据的写入操作同步到从机。

主从模式很好的解决了数据备份问题，并且由于主从服务数据几乎是一致的，因而可以将写入数据的命令发送给主机执行，而读取数据的命令发送给不同的从机执行，从而达到读写分离的目的。

Redis 的主从复制功能非常强大，一个 master 可以拥有多个 slave，而一个 slave 又可以拥有多个 slave，如此下去，形成了强大的多级服务器集群架构。
<!-- more -->

## 主从模式架构

Redis 主从模式的架构图如下图所示：

![36_redis主从模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135449.png)

我们可以看到，在主从模式中，只有一个是主机，其他的都是从机，并且从机下面还可以有任意多个从机。

## Redis主从复制注意点

1. 默认配置下，master 节点可以进行读和写，slave 节点只能进行读操作，写操作被禁止。
2. 不要修改配置让 slave 节点支持写操作，没有意义，因为，首先写入的数据不会被同步到其他节点，其次，当 master 节点修改同一条数据后，slave 节点的数据会被覆盖掉。
3. master 节点挂了以后，redis 就不会对外提供写服务了，因为剩下的 slave 节点不会成为 master。
4. master 节点挂了以后，不影响 slave 节点的读，master 节点启动后 Redis 将重新对外提供写服务。
5. slave 节点挂了不影响其他 slave 节点的读和 master 节点的读和写，重新启动后会将数据从 master 节点同步过来。

## 主从复制优缺点

### 优点

1. 读写分离，提高效率
2. 数据热备份，提供多个副本

### 缺点

1. 主节点故障，集群则无法进行工作，可用性比较低，从节点升主节点需要人工手动干预
2. 单点容易造成性能低下
3. 主节点的存储能力受到限制
4. 主节点的写受到限制（只有一个主节点）
5. 全量同步可能会造成毫秒或者秒级的卡顿现象

### 特点

只能 master 到 slave，单向的

## Redis主从模式配置

我们首先使用 vim 创建 master 的配置文件，具体命令如下：

```
vim redis/master-6739.conf
```

如下图所示：

![37_redis主从模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135454.png)

我们写入如下配置：

```
bind 0.0.0.0
port 6379
logfile "6379.log"
dbfilename "dump-6379.rdb"
daemonize yes
rdbcompression yes
```

即，我们配置了主节点的端口为 6379，现在，我们再次创建 slave1 节点的配置，具体命令如下：

```
vim redis/slave1-6380.conf
```

我们写入如下配置：

```
bind 0.0.0.0
port 6380
logfile "6380.log"
dbfilename "dump-6380.rdb"
daemonize yes
rdbcompression yes
slaveof 192.168.33.133 6379
```

即，我们配置了第一个从节点的端口为 6380，同时，我们通过 slaveof 配置指定了该从节点的主节点是什么，现在，我们再次创建 slave2 节点的配置，具体命令如下：

```
vim redis/slave2-6381.conf
```

我们写入如下配置：

```
bind 0.0.0.0
port 6381
logfile "6381.log"
dbfilename "dump-6381.rdb"
daemonize yes
rdbcompression yes
slaveof 192.168.33.133 6379
```

我们指定了 slave2 节点的端口为 6381，并且指定了其主节点为 6379 的配置，现在，我们分别启动三个服务器，具体命令如下：

```
redis-server redis/master-6739.conf
redis-server redis/slave1-6380.conf
redis-server redis/slave2-6381.conf
```

启动完毕之后，我们使用 ps 命令查看所有的 redis-server 服务，具体命令如下：

```
ps -ef | grep redis-server
```

执行完毕后，如下图所示：

![38_redis主从模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135458.png)

至此，我们的所有配置都已经完成了，并且服务都已经启动成功了，现在，我们分别登录到 master 和两个 slave 查看键 name 是否存在，具体命令如下：

```
get name
```

执行完毕后，如下图所示：

![39_redis主从模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135501.png)

我们看到，此时三个节点都没有 name 键，现在，我们在 master 上设置 name 的值，具体命令如下：

```
set name haicoder
```

执行完毕后，我们再次分别在 master 和两个 slave 获取数据，如下图所示：

![40_redis主从模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135504.png)

我们可以看出，我们在 master 上设置了一个键，最后在两个 slave 都获取到了这个键的值，即，master 的数据会自动同步到 slave 节点。现在，我们尝试在 slave 设置键，具体命令如下：

```
set name1 haicoder1
```

执行完毕后，如下图所示：

![41_redis主从模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135507.png)

我们看到，此时提示我们不能在 slave 写入数据，即 master 可以读写数据，但 slave 只能读取数据。

注意，使用主从模式时应注意 matser 节点的持久化操作，matser 节点在未使用持久化的情况详情下如果宕机，并自动重新拉起服务，从服务器会出现丢失数据的情况。因为 master 服务挂了之后，重启服务后，slave 节点会与 master 节点进行一次完整的重同步操作，所以由于 master 节点没有持久化，就导致 slave 节点上的数据也会丢失掉。所以在配置了 Redis 的主从模式的时候，应该打开主服务器的持久化功能。

## 查看主从节点

我们要查看当前节点是 master 节点还是 slave 节点，我们可以使用 info 命令，具体命令如下：

```
info
```

我们在 master 上执行如下图所示：

![42_redis主从模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135511.png)

我们可以看到，此时显示的 Replication 配置项下面的 role 为 master，现在，我们再次在 slave 节点下查看，执行如下图所示：

![43_redis主从模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135514.png)

我们看到，此时显示的是 slave，同时，我们还可以直接使用 info 加要查看的节点，来查看具体的配置，具体命令如下：

```
info Replication
```

我们首先在 master 上查看，输出如下：

![44_redis主从模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135517.png)

我们看到，此时直接显示了 Replication 节点的信息，现在，我们再次查看 slave 节点的信息，输出如下：

![45_redis主从模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135520.png)

我们看到，此时就显示了是 slave 节点了。

## 主从复制原理

### 流程

当启动一个 slave node 的时候，它会发送一个 PSYNC 命令给 master node。

如果这是 slave node 初次连接到 master node，那么会触发一次 full resynchronization 全量复制。此时 master 会启动一个后台线程，开始生成一份 RDB 快照文件，同时还会将从客户端 client 新收到的所有写命令缓存在内存中。

RDB 文件生成完毕后， master 会将这个 RDB 发送给 slave，slave 会先写入本地磁盘，然后再从本地磁盘加载到内存中，接着 master 会将内存中缓存的写命令发送到 slave，slave 也会同步这些数据。

slave node 如果跟 master node 有网络故障，断开了连接，会自动重连，连接之后 master node 仅会复制给 slave 部分缺少的数据。

![46_redis主从模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135523.png)

### 主从复制的断点续传

从 Redis2.8 开始，就支持主从复制的断点续传，如果主从复制过程中，网络连接断掉了，那么可以接着上次复制的地方，继续复制下去，而不是从头开始复制一份。

master node 会在内存中维护一个 backlog，master 和 slave 都会保存一个 replica offset 还有一个 master run id，offset 就是保存在 backlog 中的。如果 master 和 slave 网络连接断掉了，slave 会让 master 从上次 replica offset 开始继续复制，如果没有找到对应的 offset，那么就会执行一次 resynchronization。

### 无磁盘化复制

master 在内存中直接创建 RDB ，然后发送给 slave，不会在自己本地落地磁盘了。只需要在配置文件中开启 repl-diskless-sync yes 即可。具体配置如下：

```
repl-diskless-sync yes

# 等待 5s 后再开始复制，因为要等更多 slave 重新连接过来
repl-diskless-sync-delay 5
```

### 过期key处理

slave 不会过期 key，只会等待 master 过期 key。如果 master 过期了一个 key，或者通过 LRU 淘汰了一个 key，那么会模拟一条 del 命令发送给 slave。

## 主从复制的完整流程

### 流程

slave node 启动时，会在自己本地保存 master node 的信息，包括 master node 的 host 和 ip ，但是复制流程没开始。

slave node 内部有个定时任务，每秒检查是否有新的 master node 要连接和复制，如果发现，就跟 master node 建立 socket 网络连接。然后 slave node 发送 ping 命令给 master node。

如果 master 设置了 requirepass，那么 slave node 必须发送 masterauth 的口令过去进行认证。master node 第一次执行全量复制，将所有数据发给 slave node。而在后续，master node 持续将写命令，异步复制给 slave node。

![47_redis主从模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135530.png)

### 全量复制

1. master 执行 bgsave ，在本地生成一份 rdb 快照文件。

2. master node 将 rdb 快照文件发送给 slave node，如果 rdb 复制时间超过 60 秒（repl-timeout），那么 slave node 就会认为复制失败，可以适当调大这个参数(对于千兆网卡的机器，一般每秒传输 100MB，6G 文件，很可能超过 60s)

3. master node 在生成 rdb 时，会将所有新的写命令缓存在内存中，在 slave node 保存了 rdb 之后，再将新的写命令复制给 slave node。

4. 如果在复制期间，内存缓冲区持续消耗超过 64MB，或者一次性超过 256MB，那么停止复制，复制失败。

   ```
   client-output-buffer-limit slave 256MB 64MB 60
   ```

5. slave node 接收到 rdb 之后，清空自己的旧数据，然后重新加载 rdb 到自己的内存中，同时基于旧的数据版本对外提供服务。

6. 如果 slave node 开启了 AOF，那么会立即执行 BGREWRITEAOF，重写 AOF。

### 增量复制

1. 如果全量复制过程中，master-slave 网络连接断掉，那么 slave 重新连接 master 时，会触发增量复制。
2. master 直接从自己的 backlog 中获取部分丢失的数据，发送给 slave node，默认 backlog 就是 1MB。
3. master 就是根据 slave 发送的 psync 中的 offset 来从 backlog 中获取数据的。

### heartbeat

主从节点互相都会发送 heartbeat 信息。

master 默认每隔 10 秒发送一次 heartbeat，slave node 每隔 1 秒发送一个 heartbeat。

### 异步复制

master 每次接收到写命令之后，先在内部写入数据，然后异步发送给 slave node。