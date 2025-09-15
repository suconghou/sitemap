import util, request, tables, sets, sequtils, streams, strutils, parser, json, algorithm, httpClient, os

type URLParser = object
    c: Config
    base: string                                 # 根地址,协议、域名、端口
    hits: HashSet[string]
    internal: TableRef[Natural, HashSet[string]] # 内链
    external: HashSet[string]                    # 外链
    others: HashSet[string]                      # 其他
    processor: PageProcessor
    pageFn: proc(u: string): (Stream, int)

var stopit = false

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
    if (not self.c.match.isEmptyOrWhitespace) and (not u.contains(self.c.match)):
        return nil # 有关键词匹配但未匹配上则直接跳过处理
    try:
        let (stream, statuscode) = self.pageFn(u)
        self.internal.mgetOrPut(statuscode, initHashSet[string]()).incl(u)
        return stream
    except:
        self.internal.mgetOrPut(0, initHashSet[string]()).incl(u)
        return nil

proc valid(self: var URLParser, links: HashSet[string], curr: string, found: var HashSet[string]) =
    for u in links:
        var (x, utype) = uri_ok(self.base, curr, u)
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
        s.close()
        self.valid(links, u, found)
        echo u
        if stopit:
            found.clear()
            return

proc `%`(n: HashSet[string]): JsonNode =
    result = %(n.toSeq().sorted())

proc `%`(n: TableRef[Natural, HashSet[string]]): JsonNode =
    result = newJObject()
    for k, v in n:
        result.add(k.intToStr, %v)

proc save(self: URLParser) =
    discard put(self.c.file, self.internal.getOrDefault(200, initHashSet[string]()))
    let info = %* {"internal": self.internal, "external": self.external, "others": self.others}
    for k, v in self.processor.attrs:
        info.add(k, %v)
    let data = $info
    discard put(self.c.file.replace(".xml", ".json"), data)


proc getfile(cli: Cli, u: string, stdout: bool) =
    if not ishttp(u):
        return
    if stdout:
        cli.download(u, "/dev/stdout")
        return
    let t = u.rsplit('#')[0].rsplit('?')[0].rsplit('/', 1)
    var name = t[t.high]
    if name.isEmptyOrWhitespace:
        name = fnv1a32(u)
    try:
        echo u
        cli.download(u, name)
    except:
        discard

proc download(cli: Cli, j: JsonNode, attrs: HashSet[string], stdout: bool) =
    for a in attrs:
        let v = j[a]
        if v.kind == JArray:
            for item in v:
                cli.getfile(item.getStr, stdout)
                if stopit:
                    return
        elif v.kind == JString:
            cli.getfile(v.getStr, stdout)
        if stopit:
            return

proc download(cli: Cli, f: File|string, stdout: bool) =
    for line in f.lines:
        cli.getfile(line.strip(), stdout)
        if stopit:
            return

proc process(c: sink Config) =
    if c.host.isEmptyOrWhitespace and c.urls.len < 1:
        let cli = newCli(c.timeout.int, c.ua, c.refer)
        if c.file.isEmptyOrWhitespace or c.attrs.len < 1:
            cli.download(stdin, c.cache == "stdout" or c.cache == "-")
        else:
            let j = parseJson(readFile(c.file))
            cli.download(j, c.attrs, c.cache == "stdout" or c.cache == "-")
        return
    let h = if c.urls.len < 1: [c.host].toHashSet() else: c.urls
    let base = baseURL(if c.host.isEmptyOrWhitespace: h.one else: c.host)
    if base.isEmptyOrWhitespace:
        raise newException(ValueError, "Invalid base URL")
    let cli = newCli(c.timeout.int, c.ua, if c.refer.isEmptyOrWhitespace: base else: c.refer)
    let d = c.cache.strip()
    let pageFn = if d.dir_ok:
        proc(u: string): (Stream, int) =
            let f = (d / fnv1a32(u)) & ".html"
            if f.fileExists:
                return (f.openFileStream, 200)
            sleep(int(c.sleep))
            let resp = cli.get(u)
            let statuscode = resp.status[0 .. 2].parseInt # same as resp.code
            let s = resp.body()
            if statuscode in 200..299:
                try: f.writeFile(s) except: discard
            return (newStringStream(s), statuscode)
    else:
        proc(u: string): (Stream, int) =
            sleep(int(c.sleep))
            let resp = cli.get(u)
            let statuscode = resp.status[0 .. 2].parseInt # same as resp.code
            return (resp.bodyStream, statuscode)
    var p = URLParser(c: c, base: base, pageFn: pageFn, internal: newTable[Natural, initHashSet[string]()](), processor: newPageProcessor())
    var found = h.map(pretty)
    while found.len > 0:
        p.run(found)
    p.save()

try:
    proc ctrlc() {.noconv.} =
        stopit = true
    setControlCHook(ctrlc)
    let c = cmd()
    process(c)
except Exception:
    stderr.writeLine(getCurrentExceptionMsg())
    quit(1)

