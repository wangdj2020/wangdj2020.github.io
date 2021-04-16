---
title: MAC 终端优化
date:  2021-04-16 14:58:56
toc: true
tags: 
- 2021
- mac
- terminal
categories:
- 知识体系
---

最终效果：

![image-20210416141336051](https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2021-04-16-061336.png)

进行以下步骤前先备份`~/.zshrc`。
 <!-- more -->
## 一、安装 oh-my-zsh

官网 https://ohmyz.sh/

运行以下命令直接安装

```shell
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

## 二、安装 spaceship 主题

官网 https://github.com/denysdovhan/spaceship-prompt

执行下方脚本直接安装

```sh
git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme" 
```

脚本运行之后，需要在 `~/.zshrc` 中找到相应位置并设置 `ZSH_THEME="spaceship"` 

## 三、安装插件

```shell
# 命令高亮
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
# 命令提示
git clone git://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
```

之后在 `~/.zshrc` 中找到相应位置并设置插件 `plugins=(git safe-paste zsh-autosuggestions zsh-syntax-highlighting)`

## 四、iterm2 主题

Preferences -> Profiles -> Colors 右下角导入下面链接的主题

https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/PaleNightHC.itermcolors

Background 设置为 1c223a

## 五、拓展功能

代理开关，在有代理的情况下配置。

```shell
# proxy
function proxy() {
    export http_proxy="http://127.0.0.1:1087"
    export https_proxy=$http_proxy
    echo -e "已开启代理"
}
function proxyOff(){
    unset http_proxy
    unset https_proxy
    echo -e "已关闭代理"
}
```

