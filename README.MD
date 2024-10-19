

a simple sitemap generator


## 参数

`./main options args`

**options**

> ua/u : 配置请求时的User-Agent
>
> refer/r : 配置请求时的Referer,不指定时则为当前页面地址
>
> timeout/t : 超时时间,必须是数字,默认 8000ms,
>
> file/f : 存储的sitemap文件,默认`sitemap.xml`
>
> host/h : 主域名,不指定时自动从入口页面提取，提取协议域名端口号
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
