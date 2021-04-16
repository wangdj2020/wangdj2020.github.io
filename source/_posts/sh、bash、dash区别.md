---
title: linux中的sh、dash、bash的区别
date:  2021-04-16 14:47:41
toc: true
tags: 
- linux
- 2021
- shell
categories:
- 知识体系
---
## 一、常见shell类型

#### 1. Bourne shell (sh)

UNIX 最初使用，且在每种 UNIX 上都可以使用。在 shell 编程方面相当优秀，但在处理与用户的交互方面做得不如其他几种shell。

#### 2. C shell (csh)

csh, the C shell, is a command interpreter with a syntax similar to the C programming language.一个语法上接近于C语言的shell。
<!-- more -->
#### 3. Korn shell (ksh)

完全向上兼容 Bourne shell 并包含了 C shell 的很多特性。

#### 4. Bourne Again shell (bash)

因为Linux 操作系统缺省的 shell。即 bash 是 Bourne shell 的扩展，与 Bourne shell 完全向后兼容。在 Bourne shell 的基础上增加、增强了很多特性。可以提供如命令补全、命令编辑和命令历史表等功能。包含了很多 C shell 和 Korn shell 中的优点，有灵活和强大的编程接口，同时又有很友好的用户界面。

#### 5. Debian Almquist Shell(dash)

原来bash是GNU/Linux 操作系统中的 /bin/sh 的符号连接，但由于bash过于复杂，有人把 bash 从 NetBSD 移植到 Linux 并更名为 dash，且/bin/sh符号连接到dash。Dash Shell 比 Bash Shell 小的多（ubuntu16.04上，bash大概1M，dash只有150K），符合POSIX标准。Ubuntu 6.10开始默认是Dash。

![image-20210415174053709](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-15-094053.png)

把sh改为指向bash的方法：

- 方法一：`ln -s /bin/bash /bin/sh`；

- 方法二：配置shell`sudo dpkg-reconfigure dash`

## 二、shell 相关命令

查看当前系统可用的 shell `cat /etc/shells`

![](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-15-014006.png)

查看当前使用的 shell，随便打一个错误命令，会有提示。

![image-20210415180040827](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-15-100041.png)

查看用户登录后默认的 shell `cat /etc/passwd |grep 用户名`

![image-20210415181647374](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-15-101647.png)

## 三、规范和建议

每个脚本开头都使用"#!"，#!实际上是一个2字节魔法数字，这是指定一个文件类型的特殊标记，在这种情况下，指的就是一个可执行的脚本。在#!之后，接一个路径名，这个路径名指定了一个解释脚本命令的程序，这个程序可以是shell，程序语言或者任意一个通用程序。

标记为 “#!/bin/sh” 的脚本不应使用任何 POSIX 没有规定的特性 (如 let 等命令, 但 “#!/bin/bash” 可以)。bash支持的写法比dash（ubuntu中的sh）多很多。想要支持 sh xx.sh 运行的，必须遵照 POSIX 规范去写。**想要脚本写法多样化，不需要考虑效率的，可以将文件头定义为 #!/bin/bash , 而且不要使用 sh xx.sh 这种运行方式**

## 四、bash和dash区别

语法上的主要的区别有:

#### 1. 定义函数

bash: function在bash中为关键字
dash: dash中没有function这个关键字

#### 2. select var in list; do command; done

bash:支持
dash:不支持, 替代方法:采用while+read+case来实现

#### 3. echo {0..10}

bash:支持{n..m}展开
dash:不支持，替代方法, 采用seq外部命令

#### 4. here string

bash:支持here string
dash:不支持, 替代方法:可采用here documents

#### 5. >&word重定向标准输出和标准错误

bash: 当word为非数字时，>&word变成重定向标准错误和标准输出到文件word
dash: >&word, word不支持非数字, 替代方法: >word 2>&1; 常见用法 >/dev/null 2>&1

#### 6. 数组

bash: 支持数组, bash4支持关联数组
dash: 不支持数组，替代方法, 采用变量名+序号来实现类似的效果

#### 7. 子字符串扩展

bash: 支持parameter:offset:length,parameter:offset:length,{parameter:offset}
dash: 不支持， 替代方法:采用expr或cut外部命令代替

#### 8. 大小写转换

bash: 支持parameterpattern,parameterpattern,{parameter^^pattern},parameter,pattern,parameter,pattern,{parameter,,pattern}
dash: 不支持，替代方法:采用tr/sed/awk等外部命令转换

#### 9. 进程替换<(command), >(command)

bash: 支持进程替换
dash: 不支持, 替代方法, 通过临时文件中转

#### 10. [ string1 = string2 ] 和 [ string1 == string2 ]

bash: 支持两者
dash: 只支持=

#### 11. [[ 加强版test

bash: 支持[[ ]], 可实现正则匹配等强大功能
dash: 不支持[[ ]], 替代方法，采用外部命令

#### 12. for (( expr1 ; expr2 ; expr3 )) ; do list ; done

bash: 支持C语言格式的for循环
dash: 不支持该格式的for, 替代方法，用while+((expression))实现13.let命令和((expression))bash:有内置命令let,也支持((expression))方式dash:不支持，替代方法，采用((expression))实现13.let命令和((expression))bash:有内置命令let,也支持((expression))方式dash:不支持，替代方法，采用((expression))或者外部命令做计算

#### 14. $((expression))

bash: 支持id++,id–,++id,–id这样到表达式
dash: 不支持++,–, 替代方法:id+=1,id-=1, id=id+1,id=id-1

#### 15. 其它常用命令

bash: 支持 echo -e, 支持 declare
dash: 不支持。



原文：https://blog.csdn.net/weixin_39212776/article/details/81079727