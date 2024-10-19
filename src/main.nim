import util, request, tables, sets, sequtils, streams, strutils, parser, json

type URLParser = object
    c: Config
    base: string                                 # 根地址,协议、域名、端口
    hits: HashSet[string]
    internal: TableRef[Natural, HashSet[string]] # 内链
    external: HashSet[string]                    # 外链
    others: HashSet[string]                      # 其他
    processor: PageProcessor


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

proc fetch(self: var URLParser, u: string): Stream =
    self.hits.incl(u)
    try:
        let resp = get(u, self.c.timeout.int, self.c.ua, if self.c.refer.isEmptyOrWhitespace: u else: self.c.refer)
        let statuscode = resp.status[0 .. 2].parseInt # same as resp.code
        self.internal.mgetOrPut(statuscode, initHashSet[string]()).incl(u)
        return resp.bodyStream
    except:
        self.internal.mgetOrPut(0, initHashSet[string]()).incl(u)
        return nil

proc valid(self: var URLParser, links: HashSet[string], found: var HashSet[string]) =
    for u in links:
        var (x, utype) = uri_ok(self.base, u)
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
        let links = self.processor.process(u, s, self.c.attrs)
        self.valid(links, found)
        echo u

proc `%`(n: HashSet[string]): JsonNode =
    result = %(n.toSeq())

proc `%`(n: TableRef[Natural, HashSet[string]]): JsonNode =
    result = newJObject()
    for k, v in n:
        result.add(k.intToStr, %v)

proc save(self: var URLParser) =
    discard put(self.c.file, self.internal.getOrDefault(200, initHashSet[string]()))
    let data = $( %* {"internal": self.internal, "external": self.external, "others": self.others, "attrs": self.processor.attrs})
    discard put(self.c.file.replace(".xml", ".json"), data)

proc process(c: Config) =
    if c.host.isEmptyOrWhitespace and c.urls.len < 1:
        raise newException(ValueError, "Invalid configuration")
    let h = if c.urls.len < 1: [c.host].toHashSet() else: c.urls
    let base = baseURL(if c.host.isEmptyOrWhitespace: h.one else: c.host)
    if base.isEmptyOrWhitespace:
        raise newException(ValueError, "Invalid base URL")
    var p = URLParser(c: c, base: base, internal: newTable[Natural, initHashSet[string]()](), processor: newPageProcessor())
    var found = h.map(pretty)
    while found.len > 0:
        p.run(found)
    p.save()

try:
    let c = cmd()
    process(c)
except Exception:
    stderr.writeLine(getCurrentExceptionMsg())
    quit(1)

