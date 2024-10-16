import util, request, tables, sets, sequtils, streams, strutils, parser

type URLParser = object
    c: Config
    base: string                                        # 根地址,协议、域名、端口
    hits: HashSet[string]
    internal: OrderedTableRef[Natural, HashSet[string]] # 内链
    external: HashSet[string]                           # 外链
    others: HashSet[string]                             # 其他
    processor: PageProcessor

type URLType = enum
    Internal
    External
    Other


# 在绝对http链接中，去掉锚点、无参数的?等
proc clean(uri: var string) =
    let m = uri.find('#')
    if m >= 0:
        uri.setLen(m)
    for i in countdown(uri.high, 0):
        if uri[i] in Whitespace or uri[i] == '?':
            uri.setLen(i)
        else:
            break

proc pretty(uri: string): string =
    result = uri;
    result.clean()

proc one[T](items: HashSet[T]): T =
    assert items.len >= 1
    for item in items:
        return item

# 获取协议域名端口号
proc baseURL(uri: string): string =
    var u = uri.toLower()
    if len(u) < 8 or (u[0..6] != "http://" and u[0..7] != "https://"):
        raise newException(ValueError, "invalid URL "&uri)
    let i = u.find("://")+3
    let f = u[i]
    if not (f in {'a'..'z', '0'..'9'}): # 域名不能以数字或符号开头
        raise newException(ValueError, "invalid URL "&uri)
    var d = 0 # 域名和端口号部分,不支持IPV6
    for x in u[i..^1]:
        if x in {'a'..'z', '0'..'9', '-', '.', ':'}: # 域名的合法字符，数字，字母，中划杠，英文逗号
            d+=1
            continue;
        elif x == '/':
            u.setLen(i+d)
            return u
        else:
            raise newException(ValueError, "invalid URL "&uri)
    if u[^1] == '.':
        u.setLen(u.len-1)
        return u
    elif u[^1] in {'-', ':'}: # 结尾必须是字母或数字; 域名结尾有.其实是合法的 https://imququ.com/post/domain-public-suffix-list.html
        raise newException(ValueError, "invalid URL "&uri)
    return u

# 不区分大小写比较
proc `~=` (a, b: string): bool =
    return cmpIgnoreCase(a, b) == 0

# 获取html里的所有a标签

proc fetch(self: var URLParser, u: string): Stream =
    self.hits.incl(u)
    # TODO 异常处理
    echo "fetching ", u
    let resp = get(u, self.c.timeout.int, self.c.ua, if self.c.refer.isEmptyOrWhitespace: u else: self.c.refer)
    let statuscode = resp.status[0 .. 2].parseInt # same as resp.code
    self.internal.mgetOrPut(statuscode, initHashSet[string]()).incl(u)
    return resp.bodyStream

# 非外链，并且是合法的http地址, 如果是相对地址，则转化为绝对地址
proc uri_ok(self: var URLParser, u: string): (string, URLType) =
    if len(u) > 8 and (u[0..6] ~= "http://" or u[0..7] ~= "https://"):
        # 是http绝对地址，则获取域名, TODO 是否忽略协议不一致
        let x = baseURL(u)
        if x == self.base:
            return (u, Internal)
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
            elif x == '/':
                break
            else: # 域名非法, TODO log
                return (u, Other)
        if d.len < 1 or d[^1] in {'-', ':'}:
            # 域名非法,不能以符号结尾 TODO log
            return (u, Other)
        if d[^1] == '.': # 域名结尾有.其实是合法的 https://imququ.com/post/domain-public-suffix-list.html
            d.setLen(d.len-1)
        if self.base.endsWith(d.toLower()):
            let n = self.base.find("://")
            # TODO 后续统一去除域名最后的.
            return (self.base[0..n] & u, Internal)
        return (u, External) # 域名不匹配，可能是外链
    else:
        # 是相对地址，或非法字符串
        # TODO 过滤 javascript: mailto:
        if u.startsWith("javascript:") or u.startsWith("mailto:"):
            return (u, Other)
        return (self.base & '/' & u.strip(true, false, {'/'}), Internal)


proc valid(self: var URLParser, links: HashSet[string], found: var HashSet[string]) =
    for u in links:
        var (x, utype) = self.uri_ok(u)
        if x.isEmptyOrWhitespace:
            continue;
        x.clean
        if utype == Internal:
            found.incl(x)
        elif utype == External:
            self.external.incl(x)
        else:
            self.others.incl(x)

proc run(self: var URLParser, found: var HashSet[string]) =
    let urls = found.toSeq()
    found.clear()
    for u in urls:
        if self.hits.contains(u):
            continue
        let s = self.fetch(u)
        if s.isNil:
            continue
        let links = self.processor.process(u, s)
        self.valid(links, found)

proc save(self: var URLParser) =
    discard put(self.c.file, self.internal.getOrDefault(200, initHashSet[string]()))

proc process(c: Config) =
    if c.host.isEmptyOrWhitespace and c.urls.len < 1:
        raise newException(ValueError, "Invalid configuration")
    let h = if c.urls.len < 1: [c.host].toHashSet() else: c.urls
    var p = URLParser(c: c, base: baseURL(h.one), internal: newOrderedTable[Natural, initHashSet[string](64)](64))
    var found = h.map(pretty)
    while found.len > 0:
        p.run(found)
    for code in p.internal.keys:
        echo "Code: ", code, " ", p.internal[code].len, " URLs"
        for u in p.internal[code]:
            echo "  ", u
    for u in p.external:
        echo "External: ", u
    for o in p.others:
        echo "Other: ", o
    p.save()

try:
    let c = cmd()
    process(c)
except Exception:
    raise
    stderr.writeLine(getCurrentExceptionMsg())
    quit(1)

