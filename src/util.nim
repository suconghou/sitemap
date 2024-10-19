import parseopt, strutils, sets



type Config* = object
    ua*: string
    host*: string
    timeout*: uint
    file*: string
    urls*: HashSet[string]
    refer*: string
    attrs*: HashSet[string]


type URLType* = enum
    Internal
    External
    Other


# 不区分大小写比较
proc `~=` (a, b: string): bool =
    return cmpIgnoreCase(a, b) == 0


# 获取协议域名端口号，输入url不合法则返回空字符串
proc baseURL*(uri: string): string =
    var u = uri.toLower()
    if len(u) < 8 or (u[0..6] != "http://" and u[0..7] != "https://"):
        return ""
    let i = u.find("://")+3
    let f = u[i]
    if f notin {'a'..'z', '0'..'9'}: # 域名不能以符号开头
        return ""
    var d = 0 # 域名和端口号部分,不支持IPV6
    for x in u[i..^1]:
        if x in {'a'..'z', '0'..'9', '-', '.', ':'}: # 域名的合法字符，数字，字母，中划杠，英文逗号
            d+=1
            continue;
        elif x in {'/', '?', '#'}:
            u.setLen(i+d)
            return u
        else:
            return ""
    if u[^1] == '.': # 结尾必须是字母或数字; 域名结尾有.其实是合法的 https://imququ.com/post/domain-public-suffix-list.html
        u.setLen(u.len-1)
    if u[^1] in {'-', '.', ':'}:
        return ""
    return u

# 鉴定是否外链, 如果是相对地址，则转化为绝对地址, 调用方保证了u是strip空格后的
proc uri_ok*(base: string, u: string): (string, URLType) =
    if len(u) > 8 and (u[0..6] ~= "http://" or u[0..7] ~= "https://"):
        # 是http绝对地址，则获取域名, 注意：协议不一致或者带有:80或:443等 此处将识别为外链
        let x = baseURL(u)
        if x == base:
            return (u, Internal)
        elif x == "":
            return (u, Other)
        else:
            return (u, External)
    elif u.startsWith("//"):
        # 自适应协议,我们还需要检验后面有域名，并解析出域名端口号部分
        var d = newStringOfCap(len(u))
        for i in 2..u.high:
            let x = u[i]
            let m = if i == 2: {'a'..'z', '0'..'9', 'A'..'Z'} else: {'a'..'z', '0'..'9', 'A'..'Z', '-', '.', ':'}
            if x in m: # 域名的合法字符，数字，字母，中划杠，英文逗号
                d.add(x)
                continue
            elif x in {'/', '?', '#'}:
                break
            else: # 域名包含非法的字符串
                return (u, Other)
        let l = d.len
        if l < 1 or d[^1] in {'-', ':'}:
            # 域名非法,不能以符号结尾
            return (u, Other)
        if d[^1] == '.': # 域名结尾有.其实是合法的 https://imququ.com/post/domain-public-suffix-list.html
            d.setLen(l-1)
        if base.endsWith(d.toLower()):
            let n = base.find("://")+2 # 截取 协议部分带://
            return (base[0..n] & d & u[l+2..^1], Internal)
        return (u, External) # 域名不匹配，可能是外链
    else: # 是相对地址，或非 http https 协议
        # 过滤 javascript: mailto: 等外部协议
        for x in u:
            if x in {'a'..'z', 'A'..'Z'}:
                continue
            elif x == ':':
                return (u, Other)
            else:
                break
        return (base & '/' & u.strip(true, false, {'/'}), Internal)

proc encode(s: string): string =
    result = s.replace("&amp;", "&").replace("&", "&amp;")

proc put*(file: string, urls: HashSet[string]): bool =
    if urls.len == 0: return false
    const header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">"
    var texts = @[header]
    for url in urls:
        texts.add "  <url>\n    <loc>" & url.encode & "</loc>\n  </url>"
    texts.add "</urlset>"
    writeFile(file, texts.join("\n"))
    return true

proc put*(file: string, data: string): bool =
    writeFile(file, data)
    return true

proc cmd*(): Config =
    var cfg = Config(timeout: 8000, file: "sitemap.xml", )
    for kind, key, val in getopt():
        case kind
        of cmdArgument:
            cfg.urls.incl(key)
        of cmdLongOption, cmdShortOption:
            case key
            of "host", "h": cfg.host = val
            of "timeout", "t": cfg.timeout = try: parseUint(val) except ValueError: 8000
            of "ua", "u": cfg.ua = val
            of "refer", "r": cfg.refer = val
            of "file", "f": cfg.file = val
            of "attrs", "a": cfg.attrs.incl(val)
        of cmdEnd: assert(false) # cannot happen
    return cfg
