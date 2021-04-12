---
title: Redis数据持久化RDB与AOF
date:  2021-04-12 21:56:39
toc: true
tags: 
- redis
- 2021
- redis 进阶
categories:
- 知识体系
---

原文：https://haicoder.net/note/redis-interview/redis-interview-redis-rdb-aof.html

## Redis数据持久化

**[Redis](https://haicoder.net/redis/redis-tutorial.html)** 作为一个内存数据库，数据是以内存为载体存储的，那么一旦 Redis 服务器进程退出，服务器中的数据也会消失。为了解决这个问题，Redis 提供了持久化机制，也就是把内存中的数据保存到磁盘当中，避免数据意外丢失。

Redis 提供了两种持久化方案：RDB 持久化和 AOF 持久化，一个是快照的方式，一个是类似日志追加的方式。
<!-- more -->

## RDB快照持久化

### 概念

RDB 持久化是通过快照的方式，即在指定的时间间隔内将内存中的数据集快照写入磁盘。在创建快照之后，用户可以备份该快照，可以将快照复制到其他服务器以创建相同数据的服务器副本，或者在重启服务器后恢复数据。RDB 是 Redis 默认的持久化方式。

### 快照持久化

RDB 持久化会生成 RDB 文件，该文件是一个压缩过的二进制文件，可以通过该文件还原快照时的数据库状态，即生成该 RDB 文件时的服务器数据。RDB 文件默认为当前工作目录下的 dump.rdb，可以根据配置文件中的 dbfilename 和 dir 设置 RDB 的文件名和文件位置，具体配置如下：

```
# 设置dump的文件名
dbfilename dump.rdb

# 工作目录
# 例如上面的dbfilename只指定了文件名，但是它会写入到这个目录下。这个配置项一定是个目录，而不能是文件名。
dir ./
```

### 相关配置

```
# RDB自动持久化规则
# 当 900 秒内有至少有 1 个键被改动时，自动进行数据集保存操作
save 900 1
# 当 300 秒内有至少有 10 个键被改动时，自动进行数据集保存操作
save 300 10
# 当 60 秒内有至少有 10000 个键被改动时，自动进行数据集保存操作
save 60 10000

# RDB持久化文件名
dbfilename dump-<port>.rdb

# 数据持久化文件存储目录
dir /var/lib/redis

# bgsave发生错误时是否停止写入，通常为yes
stop-writes-on-bgsave-error yes

# rdb文件是否使用压缩格式
rdbcompression yes

# 是否对rdb文件进行校验和检验，通常为yes
rdbchecksum yes
```

### 触发快照的时机

- 执行 save 和 bgsave 命令
- 配置文件设置 `save <seconds> <changes>` 规则，自动间隔性执行 bgsave 命令
- 主从复制时，从库全量复制同步主库数据，主库会执行 bgsave
- 执行 flushall 命令清空服务器数据
- 执行 shutdown 命令关闭 Redis 时，会执行 save 命令

### save和bgsave命令区别

执行 save 和 bgsave 命令，可以手动触发快照，生成 RDB 文件，两者的区别为使用 save 命令会阻塞 Redis 服务器进程，服务器进程在 RDB 文件创建完成之前是不能处理任何的命令请求：

```
127.0.0.1:6379> save
OK
```

而使用 bgsave 命令不同的是，bgsave 命令会 fork 一个子进程，然后该子进程会负责创建 RDB 文件，而服务器进程会继续处理命令请求：

```
127.0.0.1:6379> bgsave
Background saving started
```

其中，fork() 是由操作系统提供的函数，作用是创建当前进程的一个副本作为子进程，具体流程如下：

![07_Redis持久化RDB和AOF.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135252.png)

fork 一个子进程，子进程会把数据集先写入临时文件，写入成功之后，再替换之前的 RDB 文件，用二进制压缩存储，这样可以保证 RDB 文件始终存储的是完整的持久化内容。

### 自动间隔触发

在配置文件中设置 `save <seconds> <changes>` 规则，可以自动间隔性执行 bgsave 命令，具体配置如下：

```
################################ SNAPSHOTTING  ################################
#
# Save the DB on disk:
#
#   save <seconds> <changes>
#
#   Will save the DB if both the given number of seconds and the given
#   number of write operations against the DB occurred.
#
#   In the example below the behaviour will be to save:
#   after 900 sec (15 min) if at least 1 key changed
#   after 300 sec (5 min) if at least 10 keys changed
#   after 60 sec if at least 10000 keys changed
#
#   Note: you can disable saving completely by commenting out all "save" lines.
#
#   It is also possible to remove all the previously configured save
#   points by adding a save directive with a single empty string argument
#   like in the following example:
#
#   save ""
save 900 1
save 300 10
save 60 10000
```

`save <seconds> <changes>` 表示在 seconds 秒内，至少有 changes 次变化，就会自动触发 bgsave 命令，具体配置解释如下：

| 配置          | 描述                                                         |
| ------------- | ------------------------------------------------------------ |
| save 900 1    | 当时间到900秒时，如果至少有1个key发生变化，就会自动触发bgsave命令创建快照 |
| save 300 10   | 当时间到300秒时，如果至少有10个key发生变化，就会自动触发bgsave命令创建快照 |
| save 60 10000 | 当时间到60秒时，如果至少有10000个key发生变化，就会自动触发bgsave命令创建快照 |

### save与bgsave

| 命令   | save               | bgsave                             |
| ------ | ------------------ | ---------------------------------- |
| IO类型 | 同步               | 异步                               |
| 阻塞？ | 是                 | 是（阻塞发生在fock()，通常非常快） |
| 复杂度 | O(n)               | O(n)                               |
| 优点   | 不会消耗额外的内存 | 不阻塞客户端命令                   |
| 缺点   | 阻塞客户端命令     | 需要fock子进程，消耗内存           |

## AOF持久化

### 概念

除了 RDB 持久化，Redis 还提供了 AOF（Append Only File）持久化功能，AOF 持久化会把被执行的写命令写到 AOF 文件的末尾，记录数据的变化。默认情况下，Redis 是没有开启 AOF 持久化的，开启后，每执行一条更改 Redis 数据的命令，都会把该命令追加到 AOF 文件中，这是会降低 Redis 的性能，但大部分情况下这个影响是能够接受的，另外使用较快的硬盘可以提高 AOF 的性能。

### 配置

可以通过配置 redis.conf 文件开启 AOF 持久化，关于 AOF 的配置如下：

```
# appendonly参数开启AOF持久化
appendonly no

# AOF持久化的文件名，默认是appendonly.aof
appendfilename "appendonly.aof"

# AOF文件的保存位置和RDB文件的位置相同，都是通过dir参数设置的
dir ./

# 同步策略
# appendfsync always
appendfsync everysec
# appendfsync no

# aof重写期间是否同步
no-appendfsync-on-rewrite no

# 重写触发配置
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# 加载aof出错如何处理
aof-load-truncated yes

# 文件重写策略
aof-rewrite-incremental-fsync yes
```

### AOF的实现

AOF 需要记录 Redis 的每个写命令，步骤为：命令追加（append）、文件写入（write）和文件同步（sync）。

#### 命令追加

开启 AOF 持久化功能后，服务器每执行一个写命令，都会把该命令以协议格式先追加到 aof_buf 缓存区的末尾，而不是直接写入文件，避免每次有命令都直接写入硬盘，减少硬盘 IO 次数。

#### 文件写入和同步

对于何时把 aof_buf 缓冲区的内容写入保存在 AOF 文件中，Redis 提供了多种策略：

| 配置                 | 描述                                                         |
| -------------------- | ------------------------------------------------------------ |
| appendfsync always   | 将 aof_buf 缓冲区的所有内容写入并同步到 AOF 文件，每个写命令同步写入磁盘 |
| appendfsync everysec | 将 aof_buf 缓存区的内容写入 AOF 文件，每秒同步一次，该操作由一个线程专门负责 |
| appendfsync no       | 将 aof_buf 缓存区的内容写入 AOF 文件，什么时候同步由操作系统来决定 |

appendfsync 选项的默认配置为 everysec，即每秒执行一次同步，关于 AOF 的同步策略是涉及到操作系统的 write 函数和 fsync 函数的，在 `《Redis设计与实现》` 中是这样说明的：

为了提高文件写入效率，在现代操作系统中，当用户调用 write 函数，将一些数据写入文件时，操作系统通常会将数据暂存到一个内存缓冲区里，当缓冲区的空间被填满或超过了指定时限后，才真正将缓冲区的数据写入到磁盘里。

这样的操作虽然提高了效率，但也为数据写入带来了安全问题：如果计算机停机，内存缓冲区中的数据会丢失。为此，系统提供了 fsync、fdatasync 同步函数，可以强制操作系统立刻将缓冲区中的数据写入到硬盘里，从而确保写入数据的安全性。

从上面的介绍我们知道，我们写入的数据，操作系统并不一定会马上同步到磁盘，所以 Redis 才提供了 appendfsync 的选项配置。当该选项时为 always 时，数据安全性是最高的，但是会对磁盘进行大量的写入，Redis 处理命令的速度会受到磁盘性能的限制；appendfsync everysec 选项则兼顾了数据安全和写入性能，以每秒一次的频率同步 AOF 文件，即便出现系统崩溃，最多只会丢失一秒内产生的数据；如果是 appendfsync no 选项，Redis 不会对 AOF 文件执行同步操作，而是有操作系统决定何时同步，不会对 Redis 的性能带来影响，但假如系统崩溃，可能会丢失不定数量的数据。

#### always、everysec、no对比

| 命令     | 优点                             | 缺点                              |
| -------- | -------------------------------- | --------------------------------- |
| always   | 不丢失数据                       | IO开销大，一般SATA磁盘只有几百TPS |
| everysec | 每秒进行与fsync，最多丢失1秒数据 | 可能丢失1秒数据                   |
| no       | 不用管                           | 不可控                            |

### AOF重写(rewrite)

在了解 AOF 重写之前，我们先来看看 AOF 文件中存储的内容是啥，先执行两个写操作：

```
127.0.0.1:6379> set s1 hello
OK
127.0.0.1:6379> set s2 world
OK
```

然后我们打开 appendonly.aof 文件，可以看到如下内容：

```
*3
$3
set
$2
s1
$5
hello
*3
$3
set
$2
s2
$5
world
```

该命令格式为 Redis 的序列化协议（RESP）。`*3` 代表这个命令有三个参数，`$3` 表示该参数长度为 3，看了上面的 AOP 文件的内容，我们应该能想象，随着时间的推移，Redis 执行的写命令会越来越多，AOF 文件也会越来越大，过大的 AOF 文件可能会对 Redis 服务器造成影响，如果使用 AOF 文件来进行数据还原所需时间也会越长。

时间长了，AOF 文件中通常会有一些冗余命令，比如：过期数据的命令、无效的命令（重复设置、删除）、多个命令可合并为一个命令（批处理命令）。所以 AOF 文件是有精简压缩的空间的。

AOF 重写的目的就是减小 AOF 文件的体积，不过值得注意的是：AOF 文件重写并不需要对现有的 AOF 文件进行任何读取、分享和写入操作，而是通过读取服务器当前的数据库状态来实现的，文件重写可分为手动触发和自动触发，手动触发执行 bgrewriteaof 命令，该命令的执行跟 bgsave 触发快照时类似的，都是先 fork 一个子进程做具体的工作：

```
127.0.0.1:6379> bgrewriteaof
Background append only file rewriting started
```

自动触发会根据 auto-aof-rewrite-percentage 和 auto-aof-rewrite-min-size 64mb 配置来自动执行 bgrewriteaof 命令：

```
# 表示当AOF文件的体积大于64MB，且AOF文件的体积比上一次重写后的体积大了一倍（100%）时，会执行`bgrewriteaof`命令
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
```

下面看一下执行 bgrewriteaof 命令，重写的流程：

![08_Redis持久化RDB和AOF.png](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-12-135259.png)

说明如下：

1. 重写会有大量的写入操作，所以服务器进程会 fork 一个子进程来创建一个新的 AOF 文件
2. 在重写期间，服务器进程继续处理命令请求，如果有写入的命令，追加到 aof_buf 的同时，还会追加到 aof_rewrite_buf AOF 重写缓冲区
3. 当子进程完成重写之后，会给父进程一个信号，然后父进程会把 AOF 重写缓冲区的内容写进新的 AOF 临时文件中，再对新的 AOF 文件改名完成替换，这样可以保证新的 AOF 文件与当前数据库数据的一致性

### AOF重写配置

| 配置名                      | 含义                          |
| --------------------------- | ----------------------------- |
| auto-aof-rewrite-min-size   | 触发AOF文件执行重写的最小尺寸 |
| auto-aof-rewrite-percentage | 触发AOF文件执行重写的增长率   |

| 统计名           | 含义                                  |
| ---------------- | ------------------------------------- |
| aof_current_size | AOF文件当前尺寸（字节）               |
| aof_base_size    | AOF文件上次启动和重写时的尺寸（字节） |

AOF重写自动触发机制，需要同时满足下面两个条件：

```
aof_current_size > auto-aof-rewrite-min-size
(aof_current_size - aof_base_size) * 100 / aof_base_size > auto-aof-rewrite-percentage
```

假设 Redis 的配置项为：

```
auto-aof-rewrite-min-size 64mb
auto-aof-rewrite-percentage 100
```

当 AOF 文件的体积大于 64Mb，并且 AOF 文件的体积比上一次重写之久的体积大了至少一倍（100%）时，Redis 将执行 bgrewriteaof 命令进行重写。

### AOF重写原理

当 AOF 文件的大小超过所设定的阈值时，redis 就会启动 AOF 文件的内容压缩，只保留可以恢复数据的最小指令集。假如我们调用了 100 次 **INCR** 指令，在 AOF 文件中就要存储 100 条指令，但这明显是很低效的，完全可以把这 100 条指令合并成一条 SET 指令，这就是重写机制的原理。

在进行 AOF 重写时，仍然是采用先写临时文件，全部完成后再替换的流程，所以断电、磁盘满等问题都不会影响 AOF 文件的可用性。

AOF 方式的另一个好处，我们通过一个 “场景再现” 来说明。某同学在操作 redis 时，不小心执行了 flushall，导致 redis 内存中的数据全部被清空了，只要 redis 配置了 AOF 持久化方式，且 AOF 文件还没有被重写（rewrite），我们就可以用最快的速度暂停 redis 并编辑 AOF 文件，将最后一行的 FLUSHALL 命令删除，然后重启 redis，就可以恢复 redis 的所有数据到 FLUSHALL 之前的状态了。但是如果 AOF 文件已经被重写了，那就无法通过这种方法来恢复数据了。

## 数据恢复

Redis4.0 开始支持 RDB 和 AOF 的混合持久化（可以通过配置项 aof-use-rdb-preamble 开启）

- 如果是 redis 进程挂掉，那么重启 redis 进程即可，直接基于 AOF 日志文件恢复数据
- 如果是 redis 进程所在机器挂掉，那么重启机器后，尝试重启 redis 进程，尝试直接基于 AOF 日志文件进行数据恢复，如果 AOF 文件破损，那么用 redis-check-aof fix 命令修复
- 如果没有 AOF 文件，会去加载 RDB 文件
- 如果 redis 当前最新的 AOF 和 RDB 文件出现了丢失/损坏，那么可以尝试基于该机器上当前的某个最新的 RDB 数据副本进行数据恢复

## RDB优缺点

### 优点

- RDB 快照是一个压缩过的非常紧凑的文件，保存着某个时间点的数据集，适合做数据的备份，灾难恢复
- 可以最大化 Redis 的性能，在保存 RDB 文件，服务器进程只需 fork 一个子进程来完成 RDB 文件的创建，父进程不需要做 IO 操作
- 与 AOF 相比，恢复大数据集的时候会更快

### 缺点

- RDB 的数据安全性是不如 AOF 的，保存整个数据集的过程是比繁重的，根据配置可能要几分钟才快照一次，如果服务器宕机，那么就可能丢失几分钟的数据
- Redis 数据集较大时，fork 的子进程要完成快照会比较耗CPU、耗时

## AOF优缺点

### 优点

- 数据更完整，安全性更高，秒级数据丢失（取决 fsync 策略，如果是 everysec，最多丢失1秒的数据）
- AOF 文件是一个只进行追加的日志文件，且写入操作是以 Redis 协议的格式保存的，内容是可读的，适合误删紧急恢复

### 缺点

- 对于相同的数据集，AOF 文件的体积要大于 RDB 文件，数据恢复也会比较慢
- 根据所使用的 fsync 策略，AOF 的速度可能会慢于 RDB。 不过在一般情况下， 每秒 fsync 的性能依然非常高

## RDB和AOF选择

- 如果是数据不那么敏感，且可以从其他地方重新生成补回的，那么可以关闭持久化
- 如果是数据比较重要，不想再从其他地方获取，且可以承受数分钟的数据丢失，比如缓存等，那么可以只使用 RDB
- 如果是用做内存数据库，要使用 Redis 的持久化，建议是 RDB 和 AOF 都开启，或者定期执行 bgsave 做快照备份，RDB 方式更适合做数据的备份，AOF 可以保证数据的不丢失

## 总结

RDB 是将某一时刻的数据持久化到磁盘中，是一种快照的方式。redis 在进行数据持久化的过程中，会先将数据写入到一个临时文件中，待持久化过程都结束了，才会用这个临时文件替换上次持久化好的文件。正是这种特性，让我们可以随时来进行备份，即使 redis 处于运行状态。

生成 RDB 文件有两种方式，即手动触发与自动触发。

AOF 方式是将执行过的写指令记录下来，在数据恢复时按照从前到后的顺序再将指令都执行一遍。同样数据集的情况下，AOF 文件要比RDB文件的体积大。而且，AOF 方式的恢复速度也要慢于 RDB 方式。

如果在追加日志时，恰好遇到磁盘空间满、inode 满或断电等情况导致日志写入不完整，redis 提供了 redis-check-aof 工 具，可以用来进行日志修复。