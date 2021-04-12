---
title: Redis分布式锁
date:  2021-04-12 21:56:32
toc: true
tags: 
- redis
- 2021
- redis 进阶
categories:
- 知识体系
---

原文：https://haicoder.net/note/redis-interview/redis-interview-redis-dislock.html

## 什么是分布式锁

要介绍分布式锁，首先要提到与分布式锁相对应的是线程锁、进程锁。

线程锁：主要用来给方法、代码块加锁。当某个方法或代码使用锁，在同一时刻仅有一个线程执行该方法或该代码段。线程锁只在同一 **[JVM](https://haicoder.net/jvm/jvm-tutorial.html)** 中有效果，因为线程锁的实现在根本上是依靠线程之间共享内存实现的，比如 synchronized 是共享对象头，显示锁 Lock 是共享某个变量（state）。

进程锁：为了控制同一操作系统中多个进程访问某个共享资源，因为进程具有独立性，各个进程无法访问其他进程的资源，因此无法通过 synchronized 等线程锁实现进程锁。

分布式锁：当多个进程不在同一个系统中，用分布式锁控制多个进程对资源的访问。
<!-- more -->

## 分布式锁的使用场景

线程间并发问题和进程间并发问题都是可以通过分布式锁解决的，但是强烈不建议这样做！因为采用分布式锁解决这些小问题是非常消耗资源的！分布式锁应该用来解决分布式情况下的多进程并发问题才是最合适的。

有这样一个情境，线程 A 和线程 B 都共享某个变量 X。如果是单机情况下（单 JVM），线程之间共享内存，只要使用线程锁就可以解决并发问题。如果是分布式情况下（多 JVM），线程 A 和线程 B 很可能不是在同一 JVM 中，这样线程锁就无法起到作用了，这时候就要用到分布式锁来解决。

## 分布式锁实现

### 说明

分布式锁一般有三种实现方式即，数据库乐观锁、基于 **[Redis](https://haicoder.net/redis/redis-tutorial.html)** 的分布式锁和基于 ZooKeeper 的分布式锁。

### 可靠性

首先，为了确保分布式锁可用，我们至少要确保锁的实现同时满足以下四个条件：

1. 互斥性。在任意时刻，只有一个客户端能持有锁。
2. 不会发生死锁。即使有一个客户端在持有锁的期间崩溃而没有主动解锁，也能保证后续其他客户端能加锁。
3. 具有容错性。只要大部分的 Redis 节点正常运行，客户端就可以加锁和解锁。
4. 解铃还须系铃人。加锁和解锁必须是同一个客户端，客户端自己不能把别人加的锁给解了。

## 代码实现

### 组件依赖

首先我们要通过 Maven 引入 Jedis 开源组件，在 pom.xml 文件加入下面的代码：

```
<dependency>
    <groupId>redis.clients</groupId>
    <artifactId>jedis</artifactId>
    <version>2.9.0</version>
</dependency>
```

### 加锁代码

#### 正确姿势

Talk is cheap, show me the code。先展示代码，再带大家慢慢解释为什么这样实现：

```
public class RedisTool {
    private static final String LOCK_SUCCESS = "OK";
    private static final String SET_IF_NOT_EXIST = "NX";
    private static final String SET_WITH_EXPIRE_TIME = "PX";
    /**
     * 尝试获取分布式锁
     * @param jedis Redis客户端
     * @param lockKey 锁
     * @param requestId 请求标识
     * @param expireTime 超期时间
     * @return 是否获取成功
     */
    public static boolean tryGetDistributedLock(Jedis jedis, String lockKey, String requestId, int expireTime) {
        String result = jedis.set(lockKey, requestId, SET_IF_NOT_EXIST, SET_WITH_EXPIRE_TIME, expireTime);
        if (LOCK_SUCCESS.equals(result)) {
            return true;
        }
        return false;
    }
}
```

可以看到，我们加锁就一行代码：

```
jedis.set(String key, String value, String nxxx, String expx, int time)
```

这个 set() 方法一共有五个形参：

1. 第一个为 key，我们使用 key 来当锁，因为 key 是唯一的。
2. 第二个为 value，我们传的是 requestId，很多童鞋可能不明白，有 key 作为锁不就够了吗，为什么还要用到 value？原因就是我们在上面讲到可靠性时，分布式锁要满足第四个条件解铃还须系铃人，通过给 value 赋值为 requestId，我们就知道这把锁是哪个请求加的了，在解锁的时候就可以有依据。requestId 可以使用 UUID.randomUUID().toString() 方法生成。
3. 第三个为 nxxx，这个参数我们填的是 NX，意思是 SET IF NOT EXIST，即当 key 不存在时，我们进行 set 操作；若 key 已经存在，则不做任何操作；
4. 第四个为 expx，这个参数我们传的是 PX，意思是我们要给这个 key 加一个过期的设置，具体时间由第五个参数决定。
5. 第五个为 time，与第四个参数相呼应，代表 key 的过期时间。

总的来说，执行上面的 set() 方法就只会导致两种结果：

1. 当前没有锁（key 不存在），那么就进行加锁操作，并对锁设置个有效期，同时 value 表示加锁的客户端。
2. 已有锁存在，不做任何操作。

心细的童鞋就会发现了，我们的加锁代码满足我们可靠性里描述的三个条件。首先，set() 加入了 NX 参数，可以保证如果已有 key 存在，则函数不会调用成功，也就是只有一个客户端能持有锁，满足互斥性。

其次，由于我们对锁设置了过期时间，即使锁的持有者后续发生崩溃而没有解锁，锁也会因为到了过期时间而自动解锁（即 key 被删除），不会发生死锁。

最后，因为我们将 value 赋值为 requestId，代表加锁的客户端请求标识，那么在客户端在解锁的时候就可以进行校验是否是同一个客户端。由于我们只考虑 Redis 单机部署的场景，所以容错性我们暂不考虑。

#### 错误示例1

比较常见的错误示例就是使用 jedis.setnx() 和 jedis.expire() 组合实现加锁，代码如下：

```
public static void wrongGetLock1(Jedis jedis, String lockKey, String requestId, int expireTime) {
    Long result = jedis.setnx(lockKey, requestId);
    if (result == 1) {
        // 若在这里程序突然崩溃，则无法设置过期时间，将发生死锁
        jedis.expire(lockKey, expireTime);
    }
}
```

setnx() 方法作用就是 SET IF NOT EXIST，expire() 方法就是给锁加一个过期时间。乍一看好像和前面的 set() 方法结果一样，然而由于这是两条 Redis 命令，不具有原子性，如果程序在执行完 setnx() 之后突然崩溃，导致锁没有设置过期时间。那么将会发生死锁。网上之所以有人这样实现，是因为低版本的 jedis 并不支持多参数的 set() 方法。

#### 错误示例2

这一种错误示例就比较难以发现问题，而且实现也比较复杂。实现思路：使用 jedis.setnx() 命令实现加锁，其中key 是锁，value 是锁的过期时间。执行过程：

1. 通过 setnx() 方法尝试加锁，如果当前锁不存在，返回加锁成功。
2. 如果锁已经存在则获取锁的过期时间，和当前时间比较，如果锁已经过期，则设置新的过期时间，返回加锁成功。

代码如下：

```
public static boolean wrongGetLock2(Jedis jedis, String lockKey, int expireTime) {
    long expires = System.currentTimeMillis() + expireTime;
    String expiresStr = String.valueOf(expires);
    // 如果当前锁不存在，返回加锁成功
    if (jedis.setnx(lockKey, expiresStr) == 1) {
        return true;
    }
    // 如果锁存在，获取锁的过期时间
    String currentValueStr = jedis.get(lockKey);
    if (currentValueStr != null && Long.parseLong(currentValueStr) < System.currentTimeMillis()) {
        // 锁已过期，获取上一个锁的过期时间，并设置现在锁的过期时间
        String oldValueStr = jedis.getSet(lockKey, expiresStr);
        if (oldValueStr != null && oldValueStr.equals(currentValueStr)) {
            // 考虑多线程并发的情况，只有一个线程的设置值和当前值相同，它才有权利加锁
            return true;
        }
    }
    // 其他情况，一律返回加锁失败
    return false;
}
```

那么这段代码问题在哪里？

1. 由于是客户端自己生成过期时间，所以需要强制要求分布式下每个客户端的时间必须同步。
2. 当锁过期的时候，如果多个客户端同时执行 jedis.getSet() 方法，那么虽然最终只有一个客户端可以加锁，但是这个客户端的锁的过期时间可能被其他客户端覆盖。
3. 锁不具备拥有者标识，即任何客户端都可以解锁。

### 解锁代码

#### 正确姿势

还是先展示代码，再带大家慢慢解释为什么这样实现：

```
public class RedisTool {
    private static final Long RELEASE_SUCCESS = 1L;
    /**
     * 释放分布式锁
     * @param jedis Redis客户端
     * @param lockKey 锁
     * @param requestId 请求标识
     * @return 是否释放成功
     */
    public static boolean releaseDistributedLock(Jedis jedis, String lockKey, String requestId) {
        String script = "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end";
        Object result = jedis.eval(script, Collections.singletonList(lockKey), Collections.singletonList(requestId));
        if (RELEASE_SUCCESS.equals(result)) {
            return true;
        }
        return false;
    }
}
```

可以看到，我们解锁只需要两行代码就搞定了！第一行代码，我们写了一个简单的 Lua 脚本代码。第二行代码，我们将 Lua 代码传到 jedis.eval() 方法里，并使参数 KEYS[1] 赋值为 lockKey，ARGV[1] 赋值为 requestId。eval() 方法是将 Lua 代码交给 Redis 服务端执行。

那么这段 Lua 代码的功能是什么呢？其实很简单，首先获取锁对应的 value 值，检查是否与 requestId 相等，如果相等则删除锁（解锁）。那么为什么要使用 Lua 语言来实现呢？因为要确保上述操作是原子性的。那么为什么执行 eval() 方法可以确保原子性，源于 Redis 的特性，下面是官网对 eval 命令的部分解释：

简单来说，就是在 eval 命令执行 Lua 代码的时候，Lua 代码将被当成一个命令去执行，并且直到 eval 命令执行完成，Redis 才会执行其他命令。

#### 错误示例1

最常见的解锁代码就是直接使用 jedis.del() 方法删除锁，这种不先判断锁的拥有者而直接解锁的方式，会导致任何客户端都可以随时进行解锁，即使这把锁不是它的。

```
public static void wrongReleaseLock1(Jedis jedis, String lockKey) {
    jedis.del(lockKey);
}
```

#### 错误示例2

这种解锁代码乍一看也是没问题，甚至我之前也差点这样实现，与正确姿势差不多，唯一区别的是分成两条命令去执行，代码如下：

```
public static void wrongReleaseLock2(Jedis jedis, String lockKey, String requestId) {
    // 判断加锁与解锁是不是同一个客户端
    if (requestId.equals(jedis.get(lockKey))) {
        // 若在此时，这把锁突然不是这个客户端的，则会误解锁
        jedis.del(lockKey);
    }
}
```

如代码注释，问题在于如果调用 jedis.del() 方法的时候，这把锁已经不属于当前客户端的时候会解除他人加的锁。那么是否真的有这种场景？

答案是肯定的，比如客户端 A 加锁，一段时间之后客户端 A 解锁，在执行 jedis.del() 之前，锁突然过期了，此时客户端B尝试加锁成功，然后客户端 A 再执行 del() 方法，则将客户端 B 的锁给解除了。