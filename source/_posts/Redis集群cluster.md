---
title: Redis集群cluster
date:  2021-04-12 21:56:34
toc: true
tags: 
- redis
- 2021
- redis 进阶
categories:
- 知识体系
---

原文：https://haicoder.net/note/redis-interview/redis-interview-redis-cluster.html

## 什么是Redis cluster

Redis cluster 是 **[Redis](https://haicoder.net/redis/redis-tutorial.html)** 官方提供的分布式解决方案，在 3.0 版本后推出的，有效地解决了 Redis 分布式的需求，当一个 Redis 节点挂了可以快速的切换到另一个节点。当遇到单机内存、并发等瓶颈时，可以采用分布式方案要解决问题。
<!-- more -->

## Redis cluster集群背景

Redis 最开始使用 **[主从模式](https://haicoder.net/note/redis-interview/redis-interview-redis-master-slave.html)** 做集群，若 master 宕机需要手动配置 slave 转为 master；后来为了高可用提出来哨兵模式，该模式下有一个哨兵监视 master 和 slave，若 master 宕机可自动将 slave 转为 master，但它也有一个问题，就是不能动态扩充；所以在 3.x 提出 cluster 集群模式。

## Redis Cluster集群问题

尽管属于无中心化架构一类的分布式系统，但不同产品的细节实现和代码质量还是有不少差异的，就比如 Redis Cluster 有些地方的设计看起来就有一些 “奇葩” 和简陋：

1. 不能自动发现：无 Auto Discovery 功能。集群建立时以及运行中新增结点时，都要通过手动执行 MEET 命令或 redis-trib.rb 脚本添加到集群中。
2. 不能自动 Resharding：不仅不自动，连 Resharding 算法都没有，要自己计算从哪些结点上迁移多少 Slot，然后还是得通过 redis-trib.rb 操作。
3. 严重依赖外部 redis-trib：如上所述，像集群健康状况检查、结点加入、Resharding 等等功能全都抽离到一个 Ruby 脚本中了。还不清楚上面提到的缺失功能未来是要继续加到这个脚本里还是会集成到集群结点中？redis-trib 也许要变成 Codis 中 Dashboard 的角色。
4. 无监控管理UI：即便未来加了 UI，像迁移进度这种信息在无中心化设计中很难得到。
5. 只保证最终一致性：写 Master 成功后立即返回，如需强一致性，自行通过 WAIT 命令实现。但对于 “脑裂” 问题，目前 Redis 没提供网络恢复后的 Merge 功能，“脑裂” 期间的更新可能丢失。

## Redis Cluster优缺点

### 优点

1. 集群模式是一个无中心的架构模式，将数据进行分片，分布到对应的槽中，每个节点存储不同的数据内容，通过路由能够找到对应的节点负责存储的槽，能够实现高效率的查询。
2. 并且集群模式增加了横向和纵向的扩展能力，实现节点加入和收缩，集群模式是哨兵的升级版，哨兵的优点集群都有。

### 缺点

1. 缓存的最大问题就是带来数据一致性问题，在平衡数据一致性的问题时，兼顾性能与业务要求，大多数都是以最终一致性的方案进行解决，而不是强一致性。
2. 并且集群模式带来节点数量的剧增，一个集群模式最少要 6 台机，因为要满足半数原则的选举方式，所以也带来了架构的复杂性。
3. slave 只充当冷备，并不能缓解 master 的读的压力。
4. 批量操作限制，目前只支持具有相同 slot 值的 key 执行批量操作，对 mset、mget、sunion 等操作支持不友好。
5. key 事务操作支持有线，只支持多 key 在同一节点的事务操作，多 key 分布不同节点时无法使用事务功能。
6. 不支持多数据库空间，单机 redis 可以支持 16 个 db，集群模式下只能使用一个，即 db 0。

## Redis集群原理

### 架构图

Redis-cluster 集群的架构图如下图所示：

![60_redis集群cluster.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135125.png)

我们可以看到：

1. 所有的 Redis 节点彼此互联(PING-PONG 机制)，内部使用二进制协议优化传输速度和带宽。
2. 节点的 fail 是通过集群中超过半数的节点检测失效时才生效。
3. 客户端与 Redis 节点直连，不需要中间 proxy 层。客户端不需要连接集群所有节点，连接集群中任何一个可用节点即可。
4. Redis-cluster 把所有的物理节点映射到 [0-16383] slot 上，cluster 负责维护 node<->slot<->value。

Redis 集群中内置了 16384 个哈希槽，当需要在 Redis 集群中放置一个 key-value 时，redis 先对 key 使用 crc16 算法算出一个结果，然后把结果对 16384 求余数，这样每个 key 都会对应一个编号在 0-16383 之间的哈希槽，redis 会根据节点数量大致均等的将哈希槽映射到不同的节点。

### redis-cluster投票

Redis-cluster 投票架构图如下图所示：

![61_redis集群cluster.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135128.png)

也就是说：

1. 投票过程是集群中所有 master 参与，如果半数以上 master 节点与 master 节点通信超时(cluster-node-timeout)，认为当前 master 节点挂掉。
2. 什么时候整个集群不可用(cluster_state:fail)
   1. 如果集群任意 master 挂掉，且当前 master 没有 slave。集群进入 fail 状态，也可以理解成集群的 slot 映射 [0-16383] 不完整时进入 fail 状态。
   2. 如果集群超过半数以上 master 挂掉，无论是否有 slave，集群进入 fail 状态。

## Redis集群搭建

### 安装Ruby环境

```
yum -y install ruby
yum -y install rubygems
```

### redis配置文件修改

现在已经准备好了，6 份干净的 redis，如下所示：

```
[root@localhost redis-cluster]# pwd
/usr/local/redis/redis-cluster
[root@localhost redis-cluster]# ll
total 72
drwxr-xr-x 2 root root  4096 Nov  2 00:17 redis1
drwxr-xr-x 2 root root  4096 Nov  2 00:25 redis2
drwxr-xr-x 2 root root  4096 Nov  2 00:25 redis3
drwxr-xr-x 2 root root  4096 Nov  2 00:25 redis4
drwxr-xr-x 2 root root  4096 Nov  2 00:25 redis5
drwxr-xr-x 2 root root  4096 Nov  2 00:25 redis6
-rwxr-xr-x 1 root root 48141 Nov  2 00:16 redis-trib.rb
[root@localhost redis-cluster]# 
```

将 redis 源文件 src 目录下的 redis-trib.rb 文件拷贝过来了。 redis-trib.rb 这个文件是 redis 集群的管理文件，ruby 脚本。我们将要设置的节点的 redis.conf 配置文件按照如下进行修改：

```
################################ GENERAL  #####################################
 
# By default Redis does not run as a daemon. Use 'yes' if you need it.
# Note that Redis will write a pid file in /var/run/redis.pid when daemonized.
daemonize yes
 
# Accept connections on the specified port, default is 6379.
# If port 0 is specified Redis will not listen on a TCP socket.
port *
 
################################ REDIS CLUSTER  ###############################
#
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# WARNING EXPERIMENTAL: Redis Cluster is considered to be stable code, however
# in order to mark it as "mature" we need to wait for a non trivial percentage
# of users to deploy it in production.
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# Normal Redis instances can't be part of a Redis Cluster; only nodes that are
# started as cluster nodes can. In order to start a Redis instance as a
# cluster node enable the cluster support uncommenting the following:
#
cluster-enabled yes
```

端口号如果是同一台主机的话，必须不同。不同主机可以相同。我这里是使用一台主机，所以我将六个节点的端口号修改为 7001-7006。

### 启动脚本start-all.sh

```
cd redis1
./redis-server redis.conf
cd ..
cd redis2
./redis-server redis.conf
cd ..
cd redis3
./redis-server redis.conf
cd ..
cd redis4
./redis-server redis.conf
cd ..
cd redis5
./redis-server redis.conf
cd ..
cd redis6
./redis-server redis.conf
cd ..
```

### 停止脚本

```
./redis1/redis-cli -p 7001 shutdown
./redis1/redis-cli -p 7002 shutdown
./redis1/redis-cli -p 7003 shutdown
./redis1/redis-cli -p 7004 shutdown
./redis1/redis-cli -p 7005 shutdown
./redis1/redis-cli -p 7006 shutdown
```

两个脚本都放在如下所属目录:

```
[root@localhost redis-cluster]# pwd
/usr/local/redis/redis-cluster
[root@localhost redis-cluster]# ll
total 80
drwxr-xr-x 2 root root  4096 Nov  2 00:52 redis1
drwxr-xr-x 2 root root  4096 Nov  2 00:51 redis2
drwxr-xr-x 2 root root  4096 Nov  2 00:53 redis3
drwxr-xr-x 2 root root  4096 Nov  2 00:53 redis4
drwxr-xr-x 2 root root  4096 Nov  2 00:53 redis5
drwxr-xr-x 2 root root  4096 Nov  2 00:53 redis6
-rwxr-xr-x 1 root root 48141 Nov  2 00:16 redis-trib.rb
-rw-r--r-- 1 root root   252 Nov  2 00:55 start-all.sh
-rw-r--r-- 1 root root   216 Nov  2 00:57 stop-all.sh
[root@localhost redis-cluster]# 
```

### 修改权限

```
[root@localhost redis-cluster]# chmod -u+x start-all.sh stop-all.sh
```

### 启动节点

```
[root@localhost redis-cluster]# ./start-all.sh 
[root@localhost redis-cluster]# ps aux | grep redis
root      2924  0.8  0.1  33932  2048 ?        Ssl  Nov01   3:53 ./redis-server *:6379 [cluster]
root     11924  0.0  0.1  33936  1948 ?        Ssl  01:01   0:00 ./redis-server *:7001 [cluster]
root     11928  0.0  0.1  33936  1952 ?        Ssl  01:01   0:00 ./redis-server *:7002 [cluster]
root     11932  0.0  0.1  33936  1948 ?        Ssl  01:01   0:00 ./redis-server *:7003 [cluster]
root     11936  0.0  0.1  33936  1952 ?        Ssl  01:01   0:00 ./redis-server *:7004 [cluster]
root     11940  0.0  0.1  33936  1952 ?        Ssl  01:01   0:00 ./redis-server *:7005 [cluster]
root     11944  0.0  0.1  33936  1948 ?        Ssl  01:01   0:00 ./redis-server *:7006 [cluster]
root     11948  0.0  0.0   4360   748 pts/2    S+   01:01   0:00 grep redis
[root@localhost redis-cluster]# 
```

### 执行创建集群命令

```
[root@localhost redis-cluster]# pwd
/usr/local/redis/redis-cluster
[root@localhost redis-cluster]# ./redis-trib.rb create --replicas 1 192.168.37.131:7001 192.168.37.131:7002 192.168.37.131:7003 192.168.37.131:7004 192.168.37.131:7005  192.168.37.131:7006
```