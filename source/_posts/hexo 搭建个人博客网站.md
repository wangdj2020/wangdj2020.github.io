---
title: Hexo 搭建个人博客网站
date: 2020-08-30 11:10:21
toc: true
cover:
thumbnail: https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2020-08-30-040528.png!1000px
tags: 
- hexo
categories:
- 生命在于学习
- Blog


---

最近想好好整一整个人博客，搜索一番，比较火的有三种方式：`Jekyll`、`Hugo`、`Hexo`。最终优秀的主题、中文文档成了我选择 `Hexo` 的主要原因。

[<u>【hexo 官方网站】</u>](https://hexo.io/zh-cn/)        [<u>【icarus 主题】</u>](https://github.com/ppoffice/hexo-theme-icarus)        [<u>【next 主题】</u>](https://github.com/next-theme/hexo-theme-next)

<!-- more -->

## 搭建步骤

分三步：安装、配置、部署。

### 【安装】

```bash
# 安装 hexo
npm install hexo-cli -g

# 第一种方案，下载主题代码
git clone https://github.com/ppoffice/hexo-theme-icarus.git -b site
cd hexo-theme-icarus
cnpm install
# 安装时发现某些依赖不满足，package.json中没有声明，需要自行安装
cnpm install canvas@^2.5.0
cnpm install

hexo clean
hexo server

```



### 【 配置】

参考[【icarus主题配置】](https://blog.zhangruipeng.me/hexo-theme-icarus/Configuration/icarus%E7%94%A8%E6%88%B7%E6%8C%87%E5%8D%97-%E4%B8%BB%E9%A2%98%E9%85%8D%E7%BD%AE/#more)

主要在 _config.yml 、 _config.icarus.yml 、 _config.post.yml

#### _config.yml

```yaml
# Hexo Configuration
## Docs: http://hexo.io/docs/configuration.html
## Source: https://github.com/hexojs/hexo/

# Site
title: Learn & Record
subtitle: 
description: 王东杰的个人博客
keywords: blog,wangdongjie,wdj
author: 王东杰
language: zh-CN
timezone: Asia/Shanghai

# URL
## If your site is put in a subdirectory, set url as 'http://yoursite.com/child' and root as '/child/'
url: https://coolwdj.github.io/
root: /
permalink: :category/:post_title/
permalink_defaults:

# Directory
source_dir: source
public_dir: docs
tag_dir: tags
archive_dir: archives
category_dir: categories
code_dir: downloads/code
i18n_dir: :lang
skip_render:

# Writing
new_post_name: :title.md # File name of new posts
default_layout: post
titlecase: false # Transform title into titlecase
external_link: # Open external links in new tab
  enable: true
  field: post
filename_case: 0
render_drafts: false
post_asset_folder: false
relative_link: false
future: true
highlight:
  enable: true
  line_number: true
  tab_replace:

# Category & Tag
default_category: uncategorized
category_map:
tag_map:

# Date / Time format
## Hexo uses Moment.js to parse and display date
## You can customize the date format as defined in
## http://momentjs.com/docs/#/displaying/format/
date_format: YYYY-MM-DD
time_format: HH:mm:ss
updated_option: 'empty'

# Pagination
## Set per_page to 0 to disable pagination
per_page: 10
pagination_dir: page

index_generator:
  per_page: 10

archive_generator:
  per_page: 20
  yearly: true
  monthly: true

category_generator:
  per_page: 10

tag_generator:
  per_page: 10

# Extensions
## Plugins: https://github.com/hexojs/hexo/wiki/Plugins
## Themes: https://github.com/hexojs/hexo/wiki/Themes
theme: icarus

# Deployment
## Docs: http://hexo.io/docs/deployment.html
# deploy:
#   type: git
#   repository: https://github.com/ppoffice/hexo-theme-icarus.git
#   branch: gh-pages

marked:
  gfm: false

githubEmojis:
  className: not-gallery-item

# 有空再搞这个搜索
# algolia:
#   applicationID: T0CJF4ZB1O
#   apiKey: bcbeb94d417749ab5c65b082fce32333
#   indexName: hexo-icarus

```

#### _config.icarus.yml

```yaml
# Version of the configuration file
version: 4.0.0
# Icarus theme variant, can be "default" or "cyberpunk"
variant: default
# Path or URL to the website's logo
# logo: /img/logo.svg
logo:
    text: Learn & Record
# Page metadata configurations
head:
    # URL or path to the website's icon
    favicon: /img/favicon.svg
    # Open Graph metadata
    # https://hexo.io/docs/helpers.html#open-graph
    open_graph:
        # Page title (og:title) (optional)
        # You should leave this blank for most of the time
        title: 
        # Page type (og:type) (optional)
        # You should leave this blank for most of the time
        type: blog
        # Page URL (og:url) (optional)
        # You should leave this blank for most of the time
        url: 
        # Page cover (og:image) (optional) Default to the Open Graph image or thumbnail of the page
        # You should leave this blank for most of the time
        image: 
        # Site name (og:site_name) (optional)
        # You should leave this blank for most of the time
        site_name: 
        # Page author (article:author) (optional)
        # You should leave this blank for most of the time
        author: 
        # Page description (og:description) (optional)
        # You should leave this blank for most of the time
        description: 
        # Twitter card type (twitter:card)
        twitter_card: 
        # Twitter ID (twitter:creator)
        twitter_id: 
        # Twitter ID (twitter:creator)
        twitter_site: 
        # Google+ profile link (deprecated)
        google_plus: 
        # Facebook admin ID
        fb_admins: 
        # Facebook App ID
        fb_app_id: 
    # Structured data of the page
    # https://developers.google.com/search/docs/guides/intro-structured-data
    structured_data:
        # Page title (optional)
        # You should leave this blank for most of the time
        title: 
        # Page description (optional)
        # You should leave this blank for most of the time
        description: 
        # Page URL (optional)
        # You should leave this blank for most of the time
        url: 
        # Page author (article:author) (optional)
        # You should leave this blank for most of the time
        author: 
        # Page images (optional) Default to the Open Graph image or thumbnail of the page
        # You should leave this blank for most of the time
        image: 
    # Additional HTML meta tags in an array
    meta:
        # Meta tag specified in <attribute>=<value> style
        # E.g., name=theme-color;content=#123456 => <meta name="theme-color" content="#123456">
    # URL or path to the website's RSS atom.xml
    rss: 
# Page top navigation bar configurations
navbar:
    # Naviagtion menu items
    menu:
        首页: /
        归档: /archives
        分类: /categories
        标签: /tags
        关于: /about
    # # Links to be shown on the right of the navigation bar
    # links:
    #     Download on GitHub:
    #         icon: fab fa-github
    #         url: 'https://github.com/ppoffice/hexo-theme-icarus'
# # Page footer configurations
# footer:
#     # Links to be shown on the right of the footer section
#     links:
#         Creative Commons:
#             icon: fab fa-creative-commons
#             url: 'https://creativecommons.org/'
#         Attribution 4.0 International:
#             icon: fab fa-creative-commons-by
#             url: 'https://creativecommons.org/licenses/by/4.0/'
#         Download on GitHub:
#             icon: fab fa-github
#             url: 'https://github.com/ppoffice/hexo-theme-icarus'
# Article related configurations
article:
    # Code highlight settings
    highlight:
        # Code highlight themes
        # https://github.com/highlightjs/highlight.js/tree/master/src/styles
        theme: atom-one-light
        # Show copy code button
        clipboard: true
        # Default folding status of the code blocks. Can be "", "folded", "unfolded"
        fold: unfolded
    # Whether to show estimated article reading time
    readtime: true
    # Article licensing block
    # licenses:
    #     Creative Commons:
    #         icon: fab fa-creative-commons
    #         url: 'https://creativecommons.org/'
    #     Attribution:
    #         icon: fab fa-creative-commons-by
    #         url: 'https://creativecommons.org/licenses/by/4.0/'
    #     Noncommercial:
    #         icon: fab fa-creative-commons-nc
    #         url: 'https://creativecommons.org/licenses/by-nc/4.0/'
# Search plugin configurations
# https://ppoffice.github.io/hexo-theme-icarus/categories/Plugins/Search/
search:
    type: insight
# Comment plugin configurations
# https://ppoffice.github.io/hexo-theme-icarus/categories/Plugins/Comment/
# comment:
# Donate plugin configurations
# https://ppoffice.github.io/hexo-theme-icarus/categories/Plugins/Donation/
# donates:
#     # Alipay donate button configurations
#     -
#         type: alipay
#         # Alipay qrcode image URL
#         qrcode: ''
#     # "Buy me a coffee" donate button configurations
#     -
#         type: buymeacoffee
#         # URL to the "Buy me a coffee" page
#         url: ''
#     # Patreon donate button configurations
#     -
#         type: patreon
#         # URL to the Patreon page
#         url: ''
#     # Paypal donate button configurations
#     -
#         type: paypal
#         # Paypal business ID or email address
#         business: ''
#         # Currency code
#         currency_code: USD
#     # Wechat donate button configurations
#     -
#         type: wechat
#         # Wechat qrcode image URL
#         qrcode: ''

# # Share plugin configurations
# # https://ppoffice.github.io/hexo-theme-icarus/categories/Plugins/Share/
# share:
#     type: sharethis
#     # URL to the ShareThis share plugin script
#     install_url: //platform-api.sharethis.com/js/sharethis.js#property=5ab6f60ace89f00013641890&product=inline-share-buttons

# Sidebar configurations.
# Please be noted that a sidebar is only visible when it has at least one widget
sidebar:
    # Left sidebar configurations
    left:
        # Whether the sidebar sticks to the top when page scrolls
        sticky: true
    # Right sidebar configurations
    right:
        # Whether the sidebar sticks to the top when page scrolls
        sticky: false
# Sidebar widget configurations
# http://ppoffice.github.io/hexo-theme-icarus/categories/Widgets/
widgets:
    # Profile widget configurations
    -
        # Where should the widget be placed, left sidebar or right sidebar
        position: left
        type: profile
        # Author name
        author: 王东杰
        # Author title
        author_title: Stay hungry, Stay foolish
        # Author's current location
        location: 中国 北京
        # URL or path to the avatar image
        avatar: https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2020-08-29-125257.jpg
        # Whether show the rounded avatar image
        avatar_rounded: true
        # Email address for the Gravatar
        gravatar: 
        # URL or path for the follow button
        follow_link: 'https://github.com/coolwdj/'
        # Links to be shown on the bottom of the profile widget
        social_links:
            Github:
                icon: fab fa-github
                url: 'https://github.com/coolwdj/'
            # Facebook:
            #     icon: fab fa-facebook
            #     url: 'https://facebook.com'
            # Twitter:
            #     icon: fab fa-twitter
            #     url: 'https://twitter.com'
            # Dribbble:
            #     icon: fab fa-dribbble
            #     url: 'https://dribbble.com'
            # RSS:
            #     icon: fas fa-rss
            #     url: /
    # Table of contents widget configurations
    -
        # Where should the widget be placed, left sidebar or right sidebar
        position: left
        type: toc
    # Recommendation links widget configurations
    # -
    #     # Where should the widget be placed, left sidebar or right sidebar
    #     position: left
    #     type: links
    #     # Names and URLs of the sites
    #     links:
    #         Hexo: 'https://hexo.io'
    #         Bulma: 'https://bulma.io'
    # Categories widget configurations
    -
        # Where should the widget be placed, left sidebar or right sidebar
        position: left
        type: categories
    # Recent posts widget configurations
    -
        # Where should the widget be placed, left sidebar or right sidebar
        position: right
        type: recent_posts
    # Archives widget configurations
    -
        # Where should the widget be placed, left sidebar or right sidebar
        position: right
        type: archives
    # Tags widget configurations
    -
        # Where should the widget be placed, left sidebar or right sidebar
        position: right
        type: tags
    # Google FeedBurner email subscription widget configurations
    # -
    #     # Where should the widget be placed, left sidebar or right sidebar
    #     position: left
    #     type: subscribe_email
    #     # Hint text under the email input
    #     description: 
    #     # Feedburner ID
    #     feedburner_id: ''
    # Google AdSense unit configurations
    # -
    #     # Where should the widget be placed, left sidebar or right sidebar
    #     position: left
    #     type: adsense
    #     # AdSense client ID
    #     client_id: ''
    #     # AdSense AD unit ID
    #     slot_id: ''
# Plugin configurations
# https://ppoffice.github.io/hexo-theme-icarus/categories/Plugins/
plugins:
    # Enable page startup animations
    animejs: true
    # Show the "back to top" button
    back_to_top: true
    # Baidu Analytics plugin settings
    # https://tongji.baidu.com
    baidu_analytics:
        # Baidu Analytics tracking ID
        tracking_id: 
    # BuSuanZi site/page view counter
    # https://busuanzi.ibruce.info
    busuanzi: false
    # CNZZ statistics
    # https://www.umeng.com/web
    cnzz:
        # CNZZ tracker id
        id: 
        # CNZZ website id
        web_id: 
    # Enable the lightGallery and Justified Gallery plugins
    # https://ppoffice.github.io/hexo-theme-icarus/Plugins/General/gallery-plugin/
    gallery: true
    # Google Analytics plugin settings
    # https://analytics.google.com
    # google_analytics:
    #     # Google Analytics tracking ID
    #     tracking_id: UA-72437521-5
    # Hotjar user feedback plugin
    # https://www.hotjar.com/
    hotjar:
        # Hotjar site id
        site_id: 
    # Enable the KaTeX math typesetting supprot
    # https://katex.org/
    katex: false
    # Enable the MathJax math typesetting support
    # https://www.mathjax.org/
    mathjax: false
    # Enable the Outdated Browser plugin
    # http://outdatedbrowser.com/
    outdated_browser: true
    # Show a progress bar at top of the page on page loading
    progressbar: true
# CDN provider settings
# https://ppoffice.github.io/hexo-theme-icarus/Configuration/Theme/speed-up-your-site-with-custom-cdn/
providers:
    # Name or URL template of the JavaScript and/or stylesheet CDN provider
    cdn: jsdelivr
    # Name or URL template of the webfont CDN provider
    fontcdn: google
    # Name or URL of the fontawesome icon font CDN provider
    iconcdn: loli

```

#### _config.post.yml

_config.post.yml 文件中的配置是对 博客页面的细分配置

```yaml
sidebar:
    # Left sidebar configurations
    left:
        # Whether the sidebar sticks to the top when page scrolls
        sticky: true
    # Right sidebar configurations
    right:
        # Whether the sidebar sticks to the top when page scrolls
        sticky: false
# Sidebar widget configurations
# http://ppoffice.github.io/hexo-theme-icarus/categories/Widgets/
widgets:
    # Profile widget configurations
    -
        # Where should the widget be placed, left sidebar or right sidebar
        position: left
        type: profile
        # Author name
        author: 王东杰
        # Author title
        author_title: Stay hungry, Stay foolish
        # Author's current location
        location: 中国 北京
        # URL or path to the avatar image
        avatar: https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2020-08-29-125257.jpg
        # Whether show the rounded avatar image
        avatar_rounded: true
        # Email address for the Gravatar
        gravatar: 
        # URL or path for the follow button
        follow_link: 'https://github.com/coolwdj/'
        # Links to be shown on the bottom of the profile widget
        social_links:
            Github:
                icon: fab fa-github
                url: 'https://github.com/coolwdj/'
            # Facebook:
            #     icon: fab fa-facebook
            #     url: 'https://facebook.com'
            # Twitter:
            #     icon: fab fa-twitter
            #     url: 'https://twitter.com'
            # Dribbble:
            #     icon: fab fa-dribbble
            #     url: 'https://dribbble.com'
            # RSS:
            #     icon: fas fa-rss
            #     url: /
    # Table of contents widget configurations
    -
        # Where should the widget be placed, left sidebar or right sidebar
        position: left
        type: toc
    # Recommendation links widget configurations
    # -
    #     # Where should the widget be placed, left sidebar or right sidebar
    #     position: left
    #     type: links
    #     # Names and URLs of the sites
    #     links:
    #         Hexo: 'https://hexo.io'
    #         Bulma: 'https://bulma.io'
    # Categories widget configurations
    -
        # Where should the widget be placed, left sidebar or right sidebar
        position: left
        type: categories
    # Recent posts widget configurations
    -
        # Where should the widget be placed, left sidebar or right sidebar
        position: right
        type: recent_posts
    # Archives widget configurations
    -
        # Where should the widget be placed, left sidebar or right sidebar
        position: right
        type: archives
    # Tags widget configurations
    -
        # Where should the widget be placed, left sidebar or right sidebar
        position: right
        type: tags
    # Google FeedBurner email subscription widget configurations
    # -
    #     # Where should the widget be placed, left sidebar or right sidebar
    #     position: left
    #     type: subscribe_email
    #     # Hint text under the email input
    #     description: 
    #     # Feedburner ID
    #     feedburner_id: ''
    # Google AdSense unit configurations
    # -
    #     # Where should the widget be placed, left sidebar or right sidebar
    #     position: left
    #     type: adsense
    #     # AdSense client ID
    #     client_id: ''
    #     # AdSense AD unit ID
    #     slot_id: ''
```



### 【部署】

部署方面我是用了 [【Github Pages】](https://pages.github.com/)

如何在 Github 上建立自己的个人博客，请自行搜索。

我采用的策略是，将 `master` 分支的 `/docs` 文件夹作为博客根目录。

这样的话只需要将生成的静态文件输出到 `/docs` 文件夹，再提交代码就能达到更新的效果。

上面的 `_config.yml` 配置文件中已经将输出目录变更为 `/docs`

整个目录结构大致如下：

```bash
$ tree
.
├── README.md
├── _config.icarus.yml
├── _config.post.yml
├── _config.yml
├── db.json
├── package.json
├── push.sh
├── node_modules/···
├── scaffolds
│   ├── draft.md
│   ├── page.md
│   └── post.md
├── scripts
│   └── tab.js
└── source
    ├── _posts
    │   ├── helloworld.md
    ├── about
    │   └── index.md
    └── gallery
```

最后写一个发布脚本，即 push.sh （记得加执行权限 `chmod +x push.sh`）

```bash
git pull
hexo clean
hexo generate
git restore docs/_config.yml
git add .
git commit -m "commit"
git push
```



## 写作相关说明

### 新建文章（ 默认使用 post.md 模板）

```bash
hexo new "hello world"
```

### 文章头部

```
---
title: Hexo 搭建个人博客网站
date: 2020-08-30 11:10:21
toc: true
cover:
thumbnail: https://wdj-1252419878.cos.ap-beijing.myqcloud.com/blog/2020-08-30-040528.png!1000px
tags: 
- hexo
categories:
- 生命在于学习
- Blog
---
```

1. title：文章标题
2. date：发布时间
3. toc：是否显示目录
4. cover：封面图
5. thumbnail：缩略图
6. tags：标签
7. categories：类别

### 阅读更多

在文章中添加

```html
 <!-- more --> 
```

