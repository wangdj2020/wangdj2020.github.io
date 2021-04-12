---
title: Redis哨兵模式
date:  2021-04-12 22:10:38
toc: true
tags: 
- redis
- 2021
- redis 进阶
categories:
- 知识体系
---

原文：https://haicoder.net/note/redis-interview/redis-interview-redis-sentinel.html

## 什么是Redis哨兵模式

Redis Sentinel 是一个分布式系统， 你可以在一个架构中运行多个 Sentinel 进程（progress）， 这些进程使用流言协议（gossip protocols)来接收关于主服务器是否下线的信息，并使用投票协议（agreement protocols）来决定是否执行自动故障迁移，以及选择哪个从服务器作为新的主服务器。

虽然 Redis Sentinel 释出为一个单独的可执行文件 redis-sentinel ， 但实际上它只是一个运行在特殊模式下的 **[Redis](https://haicoder.net/redis/redis-tutorial.html)** 服务器，你可以在启动一个普通 Redis 服务器时通过给定 `--sentinel` 选项来启动 Redis Sentinel 。
<!-- more -->

## 哨兵模式简介

Sentinel(哨兵)是用于监控 redis 集群中 Master 状态的工具，是 Redis 的高可用性解决方案，sentinel 哨兵模式已经被集成在 redis2.4 之后的版本中。sentinel 是 redis 高可用的解决方案，sentinel 系统可以监视一个或者多个 redis master 服务，以及这些 master 服务的所有从服务；当某个 master 服务下线时，自动将该 master 下的某个从服务升级为 master 服务替代已下线的 master 服务继续处理请求。

sentinel 可以让 redis 实现主从复制，当一个集群中的 master 失效之后，sentinel 可以选举出一个新的 master 用于自动接替 master 的工作，集群中的其他 redis 服务器自动指向新的 master 同步数据。一般建议 sentinel 采取奇数台，防止某一台 sentinel 无法连接到 master 导致误切换。

## Redis Sentinel作用

Sentinel 系统用于管理多个 Redis 服务器（instance）， 该系统执行以下三个任务：

1. 监控（Monitoring）： Sentinel 会不断地检查你的主服务器和从服务器是否运作正常。
2. 提醒（Notification）： 当被监控的某个 Redis 服务器出现问题时， Sentinel 可以通过 API 向管理员或者其他应用程序发送通知。
3. 自动故障迁移（Automatic failover）： 当一个主服务器不能正常工作时，Sentinel 会开始一次自动故障迁移操作，它会将失效主服务器的其中一个从服务器升级为新的主服务器，并让失效主服务器的其他从服务器改为复制新的主服务器；当客户端试图连接失效的主服务器时，集群也会向客户端返回新主服务器的地址， 使得集群可以使用新主服务器代替失效服务器。

## Sentinel的工作方式

1. 每个 Sentinel 以每秒钟一次的频率向它所知的 Master，Slave 以及其他 Sentinel 实例发送一个 PING 命令。
2. 如果一个实例（instance）距离最后一次有效回复 PING 命令的时间超过 down-after-milliseconds 选项所指定的值，则这个实例会被 Sentinel 标记为主观下线。
3. 如果一个 Master 被标记为主观下线，则正在监视这个 Master 的所有 Sentinel 要以每秒一次的频率确认 Master 的确进入了主观下线状态。
4. 当有足够数量的 Sentinel（大于等于配置文件指定的值）在指定的时间范围内确认 Master 的确进入了主观下线状态，则 Master 会被标记为客观下线。
5. 在一般情况下，每个 Sentinel 会以每 10 秒一次的频率向它已知的所有 Master，Slave 发送 INFO 命令。
6. 当 Master 被 Sentinel 标记为客观下线时，Sentinel 向下线的 Master 的所有 Slave 发送 INFO 命令的频率会从 10 秒一次改为每秒一次。
7. 若没有足够数量的 Sentinel 同意 Master 已经下线，Master 的客观下线状态就会被移除。
8. 若 Master 重新向 Sentinel 的 PING 命令返回有效回复，Master 的主观下线状态就会被移除。

## Redis Sentinel优缺点

### 优点

1. 监控主数据库和从数据库是否正常运行
2. 主数据库出现故障时，可以自动将从数据库转换为主数据库，实现自动切换
3. 如果 redis 服务出现问题，会发送通知

### 缺点

1. 主数据库出现故障时，选举切换的时候容易出现瞬间断线现象
2. 不能自动扩容

## Redis Sentinel原理

首先， 哨兵模式是一种特殊的模式，它是 Redis 高可用的一种实现方案。首先哨兵是一个独立的进程， 可以实现对 Redis 实例的监控、通知、自动故障转移。

实际上，每个哨兵节点每秒通过 ping 去进行心跳监测（包括所有 redis 实例和 sentinel 同伴），并根据回复判断节点是否在线。

如果某个 sentinel 线程发现主库没有在给定时间（ down-after-milliseconds）内响应这个 PING，则这个 sentinel 线程认为主库是不可用的，这种情况叫 “主观失效”（即SDOWN）；这种情况一般不会引起马上的故障自动转移，但是当多个 sentinel 线程确实发现主库是不可用并超过 sentinel.conf 里面的配置项 sentinel monitor mymaster `#ip` `#port` `#number` 中的 #number 时候（这里实际上采用了流言协议），一般其余 sentinel 线程会通过 RAFT 算法推举领导的 sentinel 线程负责主库的客观下线并同时负责故障自动转移，这种情况叫 “客观失效”（即 ODOWN）。

具体流程如下图所示：

![48_redis哨兵模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135201.png)

## 哨兵模式的配置项

| 配置项                           | 参数类型                     | 作用                                                         |
| -------------------------------- | ---------------------------- | ------------------------------------------------------------ |
| port                             | 整数                         | 启动哨兵进程端口                                             |
| dir                              | 文件夹目录                   | 哨兵进程服务临时文件夹，默认为/tmp，要保证有可写入的权限     |
| sentinel down-after-milliseconds | <服务名称><毫秒数（整数）>   | 指定哨兵在监控Redis服务时，当Redis服务在一个默认毫秒数内都无法回答时，单个哨兵认为的主观下线时间，默认为30000（30秒） |
| sentinel parallel-syncs          | <服务名称><服务器数（整数）> | 指定可以有多少个Redis服务同步新的主机，一般而言，这个数字越小同步时间越长，而越大，则对网络资源要求越高 |
| sentinel failover-timeout        | <服务名称><毫秒数（整数）>   | 指定故障切换允许的毫秒数，超过这个时间，就认为故障切换失败，默认为3分钟 |
| sentinel notification-script     | <服务名称><脚本路径>         | 指定sentinel检测到该监控的redis实例指向的实例异常时，调用的报警脚本。该配置项可选，比较常用 |

## Redis哨兵模式配置

### 说明

Redis 三主三从可以最完整的保证数据的完整性，但是所需要的服务器资源也是最多的。在一般情况，统筹兼顾数据完整性和方案经济性，一般最优解是采用一主两从三哨兵的模式，我们使用的配置如下所示：

| 实例          | IP             | 端口  | 备注     |
| ------------- | -------------- | ----- | -------- |
| Redis（主）   | 192.168.33.135 | 9500  |          |
| Redis（从）   | 192.168.33.136 | 9501  |          |
| Redis（从）   | 192.168.33.133 | 9502  |          |
| Sentinel（1） | 192.168.33.135 | 26379 | 默认端口 |
| Sentinel（2） | 192.168.33.136 | 26379 | 默认端口 |
| Sentinel（3） | 192.168.33.133 | 26379 | 默认端口 |

### 创建目录

首先，我们在 135 机器上，创建配置存放的目录，命令如下：

```
mkdir -p /usr/local/redis/master
mkdir -p /usr/local/redis/sentinel
```

创建完毕，如下图所示：

![49_redis哨兵模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135205.png)

接着，我们在 136 机器上，创建类似的目录，命令如下：

```
mkdir -p /usr/local/redis/slave
mkdir -p /usr/local/redis/sentinel
```

创建完毕，如下图所示：

![50_redis哨兵模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135209.png)

最后，我们在 133 机器上，创建目录，命令如下：

```
mkdir -p /usr/local/redis/slave
mkdir -p /usr/local/redis/sentinel
```

创建完毕，如下图所示：

![51_redis哨兵模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135213.png)

至此，所有的目录都创建完毕。

### 创建主从配置

我们首先，在 135 机器上，创建 master 的配置，使用 vim 创建对应的配置文件，具体命令如下：

```
vim /usr/local/redis/master/redis-master.conf
```

接着，我们写入如下配置内容：

```
bind 0.0.0.0
port 9500
logfile "9500.log"
dbfilename "dump-9500.rdb"
daemonize yes
rdbcompression yes
```

接着，我们在 136 机器上，配置从的配置，使用 vim 创建对应的配置文件，具体命令如下：

```
vim /usr/local/redis/slave/redis-slave.conf
```

接着，我们写入如下配置内容：

```
bind 0.0.0.0
port 9501
logfile "9501.log"
dbfilename "dump-9501.rdb"
daemonize yes
rdbcompression yes
slaveof 192.168.33.135 9500
```

我们再次配置 133 机器上的从配置，使用 vim 创建对应的配置文件，具体命令如下：

```
vim /usr/local/redis/slave/redis-slave.conf
```

接着，我们写入如下配置内容：

```
bind 0.0.0.0
port 9502
logfile "9502.log"
dbfilename "dump-9502.rdb"
daemonize yes
rdbcompression yes
slaveof 192.168.33.135 9502
```

至此，我们的主从配置已经配置完毕了。

### 创建sentinel配置

我们首先，在 135 机器上，创建 sentinel 的配置，使用 vim 创建对应的配置文件，具体命令如下：

```
vim /usr/local/redis/sentinel/sentinel.conf
```

接着，我们写入如下配置内容：

```
port 26379
logfile "26379.log"
daemonize yes

# 这里定义主库的IP和端口，还有最后的2表示要达到2台sentinel认同才认为主库已经挂掉
sentinel monitor mymaster 192.168.33.135 9500 2

# 主库在30000毫秒（即30秒）内没有反应就认为主库挂掉（即主观失效）  
sentinel down-after-milliseconds mymaster 30000

# 若新主库当选后，允许最大可以同时从新主库同步数据的从库数  
sentinel parallel-syncs mymaster 1    

# 若在指定时间（即180000毫秒，即180秒）内没有实现故障转移，则会自动再发起一次  
sentinel failover-timeout mymaster 180000
```

接着，在 136 和 133 机器创建同样的配置文件，写入一模一样的配置内容。

### 启动

我们首先，在 135 机器启动 Redis 主，具体命令如下：

```
redis-server /usr/local/redis/master/redis-master.conf
```

接着，我们在 136 机器启动 Redis 从，具体命令如下：

```
redis-server /usr/local/redis/slave/redis-slave.conf
```

同样，我们在 133 机器启动 Redis 从，具体命令如下：

```
redis-server /usr/local/redis/slave/redis-slave.conf
```

至此，我们的主从已经启动完毕，现在，我们启动哨兵，首先在 135 机器启动，具体命令如下：

```
redis-server /usr/local/redis/sentinel/sentinel.conf --sentinel
```

接着，在 133 和 136 输入相同的命令启动即可。注意，这里我们直接使用了 redis-server 命令启动了 sentinel，也可以直接使用 redis 提供的 redis-sentinel 工具直接启动。全部启动完毕之后，我们可以使用 ps 命令，查看，具体命令如下：

```
ps -ef | grep redis-server
```

全部启动成功，则输出如下：

![52_redis哨兵模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135219.png)

### 主从数据同步

我们首先，使用 redis-cli 登录 redis master，即 135 机器的 9500 端口，具体命令如下：

```
redis-cli -p 9500
```

接着，我们使用 GET 命令，查看键 URL 的内容，具体命令如下：

```
GET URL
```

执行完毕后，如下图所示：

![53_redis哨兵模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135225.png)

同时，我们在 136 机器的 slave 上即 9501 端口，同样查看 URL 的值，执行完毕后，如下图所示：

![54_redis哨兵模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135228.png)

最后，我们同样在 133 的 slave 上即 9502 端口查看 URL 的值，执行完毕后，如下图所示：

![55_redis哨兵模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135233.png)

我们看到，此时三个机器上的 URL 都为空，现在，我们在 135 机器的 9500 端口也就是 redis master 上设置 URL 的值，具体命令如下：

```
SET URL www.haicoder.net
```

执行完毕后，如下图所示：

![56_redis哨兵模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135236.png)

现在，我们可以在两台 slave 上，再次查看 URL 的值，我们发现，这两台 slave 都有对应的值了，如下图所示：

![57_redis哨兵模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135240.png)

即，我们的主从配置完毕了。

### 高可用主从切换

现在，我们验证高可用，也就是能够实现自动的主动切换，我们首先停掉 master，也就是 135 机器的 9500 端口，我们执行如下命令即可：

```
shutdown
```

执行完毕后，如下图所示：

![58_redis哨兵模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135243.png)

此时，我们模拟了主节点宕机了，现在，我们分别查看两个 slave 节点的配置，我们分别登录 133 和 136 机器的 slave，执行如下命令：

```
INFO Replication
```

在 9501 端口执行后，输出如下：

![59_redis哨兵模式.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135246.png)

我们看到，此时原来是 slave 的已经自动切换为了 master，这就是哨兵在起作用，实现了故障后的主备切换，如果这时候我们在新的 9501 的 master 上设置数据，并在 9502 端口查看数据，此时也是可以同步数据的。