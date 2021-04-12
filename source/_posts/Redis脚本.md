---
title: Redis脚本
date:  2021-04-12 22:07:24
toc: true
tags: 
- redis
- 2021
- redis 进阶
categories:
- 知识体系
---

原文：https://haicoder.net/note/redis-interview/redis-interview-redis-lua-script.html

## Redis为什么引入Lua

**[Redis](https://haicoder.net/redis/redis-tutorial.html)** 是高性能的 key-value 内存数据库，在部分场景下，是对关系数据库的良好补充。Redis 提供了非常丰富的指令集，官网上提供了 200 多个命令。但是某些特定领域，需要扩充若干指令原子性执行时，仅使用原生命令便无法完成。Redis 意识到上述问题后，在 2.6 版本推出了 lua 脚本功能，允许开发者使用 Lua 语言编写脚本传到 Redis 中执行。

用户可以向 Redis 服务器发送 lua 脚本来执行自定义动作，获取脚本的响应数据。Redis 服务器会单线程原子性执行 lua 脚本，保证 lua 脚本在处理的过程中不会被任意其它请求打断。
<!-- more -->

## 使用Lua脚本好处

减少网络开销：可以将多个请求通过脚本的形式一次发送，减少网络时延。

原子操作：Redis 会将整个脚本作为一个整体执行，中间不会被其他请求插入。因此在脚本运行过程中无需担心会出现竞态条件，无需使用事务。

复用：客户端发送的脚本会永久存在 redis 中，这样其他客户端可以复用这一脚本，而不需要使用代码完成相同的逻辑。

可嵌入性：可嵌入 **[JAVA](https://haicoder.net/java/java-development.html)**，C# 等多种编程语言，支持不同操作系统跨平台交互。

## 什么是Lua

Lua 是一种轻量小巧的脚本语言，用标准 **[C 语言](https://haicoder.net/c/c-tutorial.html)** 编写并以源代码形式开放。其设计目的就是为了嵌入应用程序中，从而为应用程序提供灵活的扩展和定制功能。因为广泛的应用于：游戏开发、独立应用脚本、Web 应用脚本、扩展和数据库插件等。

比如：Lua 脚本用在很多游戏上，主要是 Lua 脚本可以嵌入到其他程序中运行，游戏升级的时候，可以直接升级脚本，而不用重新安装游戏。

## Redis Lua相关命令

| 命令          | 描述                                                   |
| ------------- | ------------------------------------------------------ |
| EVAL          | 执行 Lua 脚本                                          |
| EVALSHA       | 执行 Lua 脚本                                          |
| SCRIPT EXISTS | 查看指定的脚本是否已经被保存在缓存当中                 |
| SCRIPT FLUSH  | 从脚本缓存中移除所有脚本                               |
| SCRIPT KILL   | 杀死当前正在运行的 Lua 脚本                            |
| SCRIPT LOAD   | 将脚本 script 添加到脚本缓存中，但并不立即执行这个脚本 |

### EVAL命令

#### 语法

```bash
EVAL script numkeys key [key …] arg [arg …]
```

#### 参数

| 命令        | 描述                                                         |
| ----------- | ------------------------------------------------------------ |
| script      | 参数是一段 Lua5.1 脚本程序。脚本不必(也不应该 [^1] )定义为一个 Lua 函数 |
| numkeys     | 指定后续参数有几个 key，即：key [key …] 中 key 的个数。如没有 key，则为 0 |
| key [key …] | 从 EVAL 的第三个参数开始算起，表示在脚本中所用到的那些 Redis 键(key)。在 Lua 脚本中通过 KEYS[1], KEYS[2] 获取 |
| arg [arg …] | 附加参数。在 Lua 脚本中通过 ARGV[1], ARGV[2] 获取。          |

#### 案例

案例一：

```bash
# 例1：numkeys=1，keys数组只有1个元素key1，arg数组无元素
127.0.0.1:6379> EVAL "return KEYS[1]" 1 key1
"key1"
```

案例二：

```bash
# 例2：numkeys=0，keys数组无元素，arg数组元素中有1个元素value1
127.0.0.1:6379> EVAL "return ARGV[1]" 0 value1
"value1"
```

案例三：

```bash
# 例3：numkeys=2，keys数组有两个元素key1和key2，arg数组元素中有两个元素first和second 
#      其实{KEYS[1],KEYS[2],ARGV[1],ARGV[2]}表示的是Lua语法中“使用默认索引”的table表，
#      相当于java中的map中存放四条数据。Key分别为：1、2、3、4，而对应的value才是：KEYS[1]、KEYS[2]、ARGV[1]、ARGV[2]
#      举此例子仅为说明eval命令中参数的如何使用。项目中编写Lua脚本最好遵从key、arg的规范。
127.0.0.1:6379> eval "return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}" 2 key1 key2 first second 
1) "key1"
2) "key2"
3) "first"
4) "second"
```

案例四：

```bash
# 例4：使用了redis为lua内置的redis.call函数
#      脚本内容为：先执行SET命令，在执行EXPIRE命令
#      numkeys=1，keys数组有一个元素userAge（代表redis的key）
#      arg数组元素中有两个元素：10（代表userAge对应的value）和60（代表redis的存活时间）
127.0.0.1:6379> EVAL "redis.call('SET', KEYS[1], ARGV[1]);redis.call('EXPIRE', KEYS[1], ARGV[2]); return 1;" 1 userAge 10 60
(integer) 1
127.0.0.1:6379> get userAge
"10"
127.0.0.1:6379> ttl userAge
(integer) 44
```

通过上面的例 4，我们可以发现，脚本中使用 redis.call() 去调用 redis 的命令。在 Lua 脚本中，可以使用两个不同函数来执行 Redis 命令，它们分别是： redis.call() 和 redis.pcall()。

这两个函数的唯一区别在于它们使用不同的方式处理执行命令所产生的错误，差别为，当 redis.call() 在执行命令的过程中发生错误时，脚本会停止执行，并返回一个脚本错误，错误的输出信息会说明错误造成的原因：

```bash
127.0.0.1:6379> lpush foo a
(integer) 1
127.0.0.1:6379> eval "return redis.call('get', 'foo')" 0
(error) ERR Error running script (call to f_282297a0228f48cd3fc6a55de6316f31422f5d17): ERR Operation against a key holding the wrong kind of value
```

和 redis.call() 不同， redis.pcall() 出错时并不引发(raise)错误，而是返回一个带 err 域的 Lua 表(table)，用于表示错误：

```bash
127.0.0.1:6379> EVAL "return redis.pcall('get', 'foo')" 0
(error) ERR Operation against a key holding the wrong kind of value
```

### SCRIPT LOAD命令和EVALSHA命令

#### SCRIPT LOAD命令语法

```bash
SCRIPT LOAD script
```

#### SCRIPT EVALSHA命令语法

```bash
EVALSHA sha1 numkeys key [key …] arg [arg …]
```

这两个命令放在一起讲的原因是：EVALSHA 命令中的 sha1 参数，就是 SCRIPT LOAD 命令执行的结果。SCRIPT LOAD 将脚本 script 添加到 Redis 服务器的脚本缓存中，并不立即执行这个脚本，而是会立即对输入的脚本进行求值。并返回给定脚本的 SHA1 校验和。如果给定的脚本已经在缓存里面了，那么不执行任何操作。

在脚本被加入到缓存之后，在任何客户端通过 EVALSHA 命令，可以使用脚本的 SHA1 校验和来调用这个脚本。脚本可以在缓存中保留无限长的时间，直到执行 SCRIPT FLUSH 为止。

#### 案例

```bash
## SCRIPT LOAD加载脚本，并得到sha1值
127.0.0.1:6379> SCRIPT LOAD "redis.call('SET', KEYS[1], ARGV[1]);redis.call('EXPIRE', KEYS[1], ARGV[2]); return 1;"
"6aeea4b3e96171ef835a78178fceadf1a5dbe345"

## EVALSHA使用sha1值，并拼装和EVAL类似的numkeys和key数组、arg数组，调用脚本。
127.0.0.1:6379> EVALSHA 6aeea4b3e96171ef835a78178fceadf1a5dbe345 1 userAge 10 60
(integer) 1
127.0.0.1:6379> get userAge
"10"
127.0.0.1:6379> ttl userAge
(integer) 43
```

### SCRIPT EXISTS命令

#### 语法

```bash
SCRIPT EXISTS sha1 [sha1 …]
```

#### 说明

给定一个或多个脚本的 SHA1 校验和，返回一个包含 0 和 1 的列表，表示校验和所指定的脚本是否已经被保存在缓存当中。

#### 案例

```bash
127.0.0.1:6379> SCRIPT EXISTS 6aeea4b3e96171ef835a78178fceadf1a5dbe345
1) (integer) 1
127.0.0.1:6379> SCRIPT EXISTS 6aeea4b3e96171ef835a78178fceadf1a5dbe346
1) (integer) 0
127.0.0.1:6379> SCRIPT EXISTS 6aeea4b3e96171ef835a78178fceadf1a5dbe345 6aeea4b3e96171ef835a78178fceadf1a5dbe366
1) (integer) 1
2) (integer) 0
```

### SCRIPT FLUSH命令

#### 语法

```bash
SCRIPT FLUSH
```

#### 说明

清除 Redis 服务端所有 Lua 脚本缓存。

#### 案例

```bash
127.0.0.1:6379> SCRIPT EXISTS 6aeea4b3e96171ef835a78178fceadf1a5dbe345
1) (integer) 1
127.0.0.1:6379> SCRIPT FLUSH
OK
127.0.0.1:6379> SCRIPT EXISTS 6aeea4b3e96171ef835a78178fceadf1a5dbe345
1) (integer) 0
```

### SCRIPT KILL命令

#### 语法

```bash
SCRIPT KILL
```

#### 说明

杀死当前正在运行的 Lua 脚本，当且仅当这个脚本没有执行过任何写操作时，这个命令才生效。 这个命令主要用于终止运行时间过长的脚本，比如一个因为 BUG 而发生无限 loop 的脚本，诸如此类。

假如当前正在运行的脚本已经执行过写操作，那么即使执行 SCRIPT KILL，也无法将它杀死，因为这是违反 Lua 脚本的原子性执行原则的。在这种情况下，唯一可行的办法是使用 SHUTDOWN NOSAVE 命令，通过停止整个 Redis 进程来停止脚本的运行，并防止不完整(half-written)的信息被写入数据库中。

## Redis执行Lua文件

### 编写Lua脚本文件

```bash
local key = KEYS[1]
local val = redis.call("GET", key);
if val == ARGV[1]
then
        redis.call('SET', KEYS[1], ARGV[2])
        return 1
else
        return 0
end
```

### 执行Lua脚本文件

```bash
# 执行命令： redis-cli -a 密码 --eval Lua脚本路径 key [key …] ,  arg [arg …] 
如：redis-cli -a 123456 --eval ./Redis_CompareAndSet.lua userName , zhangsan lisi 
```

“–eval” 而不是命令模式中的 “eval”，一定要有前端的两个 `-`，脚本路径后紧跟 key [key …]，相比命令行模式，少了 numkeys 这个 key 数量值。

key [key …] 和 arg [arg …] 之间的 “ , ”，英文逗号前后必须有空格，否则死活都报错。

```bash
## Redis客户端执行
127.0.0.1:6379> set userName zhangsan 
OK
127.0.0.1:6379> get userName
"zhangsan"

## linux服务器执行
## 第一次执行：compareAndSet成功，返回1
## 第二次执行：compareAndSet失败，返回0
[root@vm01 learn_lua]# redis-cli -a 123456 --eval Redis_CompareAndSet.lua userName , zhangsan lisi
(integer) 1
[root@vm01 learn_lua]# redis-cli -a 123456 --eval Redis_CompareAndSet.lua userName , zhangsan lisi
(integer) 0
```

## 脚本超时

Redis 的配置文件中提供了如下配置项来规定最大执行时长：

```bash
# Lua脚本最大执行时间，默认5秒
Lua-time-limit 5000
```

但这里有个坑，当一个脚本达到最大执行时长的时候，Redis 并不会强制停止脚本的运行，仅仅在日志里打印个警告，告知有脚本超时。为什么不能直接停掉呢？

因为 Redis 必须保证脚本执行的原子性，中途停止可能导致内存的数据集上只修改了部分数据。如果时长达到 Lua-time-limit 规定的最大执行时间，Redis 只会做这几件事情：

- 日志记录有脚本运行超时。
- 开始允许接受其他客户端请求，但仅限于 SCRIPT KILL 和 SHUTDOWN NOSAVE 两个命令，其他请求仍返回 busy 错误。

## 脚本死循环怎么办

Redis 的指令执行是个单线程，这个单线程还要执行来自客户端的 lua 脚本。如果 lua 脚本中来一个死循环，是不是 Redis 就完蛋了？Redis 为了解决这个问题，它提供了 script kill 指令用于动态杀死一个执行时间超时的 lua 脚本。

不过 script kill 的执行有一个重要的前提，那就是当前正在执行的脚本没有对 Redis 的内部数据状态进行修改，因为 Redis 不允许 script kill 破坏脚本执行的原子性。比如脚本内部使用了 redis.call(“set”, key, value) 修改了内部的数据，那么 script kill 执行时服务器会返回错误。

### Script Kill的原理

lua 脚本引擎功能太强大了，它提供了各式各样的钩子函数，它允许在内部虚拟机执行指令时运行钩子代码。比如每执行 N 条指令执行一次某个钩子函数，Redis 正是使用了这个钩子函数。

## 脚本的安全性

如生成随机数这一命令，如果在 master 上执行完后，再在 slave 上执行会不一样，这就破坏了主从节点的一致性。为了解决这个问题， Redis 对 Lua 环境所能执行的脚本做了一个严格的限制，所有脚本都必须是无副作用的纯函数（pure function）。所有刚才说的那种情况压根不存在。Redis 对 Lua 环境做了一些列相应的措施：

- 不提供访问系统状态状态的库（比如系统时间库）。
- 禁止使用 loadfile 函数。
- 如果脚本在执行带有随机性质的命令（比如 RANDOMKEY ），或者带有副作用的命令（比如 TIME ）之后，试图执行一个写入命令（比如 SET ），那么 Redis 将阻止这个脚本继续运行，并返回一个错误。
- 如果脚本执行了带有随机性质的读命令（比如 SMEMBERS ），那么在脚本的输出返回给 Redis 之前，会先被执行一个自动的字典序排序，从而确保输出结果是有序的。
- 用 Redis 自己定义的随机生成函数，替换 Lua 环境中 math 表原有的 math.random 函数和 math.randomseed 函数，新的函数具有这样的性质：每次执行 Lua 脚本时，除非显式地调用 math.randomseed ，否则 math.random 生成的伪随机数序列总是相同的。

## Redis脚本应用举例

在我们项目中，有一个两对玩家进行 PK 的功能，这时候，我们需要存储每个玩家的 Id 与当前 PK 状态的映射关系，因为每组玩家都有好几个，同时，我们还要存储 PK 房间与 PK 的详细信息的映射，这些信息都是存储在 Redis 里面的，并且都需要是原子操作，因此，我们使用了 Lua 脚本来实现的。