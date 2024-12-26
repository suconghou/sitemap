

a simple sitemap generator


## 参数

`./main options args`

**options**

> ua/u : 配置请求时的User-Agent
>
> refer/r : 配置请求时的Referer,不指定时则为域名根目录
>
> timeout/t : 超时时间,必须是数字,默认 8000ms,
>
> file/f : 存储的sitemap文件,默认`sitemap.xml`
>
> host/h : 主域名,不指定时自动从入口页面提取，提取协议域名端口号
>
> match/m : 关键词匹配，url 中包含关键词才读取此url内容继续分析
>
> cache/c : 配置缓存目录，当配置有值时启用缓存
>
> sleep/s : 每次请求的间隔休眠时间，默认0，单位ms
>
**args**

>
> 参数: 入口页面，可以指定多个

```
./main url1 url2
```


**额外功能**

可提取图片等资源地址

> attrs/a : 提取的选择器和属性，例如`img[src]` , 可添加多个, `-a="img[src^=https]" -a="img[src]" -a="script[src]"`

死链检测/404检测

> 存储的json文件可查看404或无法访问等URL

下载模式

当没有配置`args`和`-h`参数时，进入下载模式

`file/f`为读取的json文件

此时的`attrs/a`为json文件里提取url的key

> -a="img[src^=http]" , 可配置多个
>
> -f="sitemap.json"
>

如果没有`-a`参数，还可以从标准输入读取，每行一个url



## 编译

**依赖**

```
nimble install css3selectors
```



**static build**

`apk add openssl-libs-static`

```
nim --mm:arc --threads:off -d:release -d:nimDisableCertificateValidation --passL:"-ffunction-sections -fdata-sections" --passL:"-Wl,--gc-sections" --dynlibOverrideAll --passL:-s --passL:-static --passL:-lssl --passL:-lcrypto -d:ssl --opt:speed c main
```
