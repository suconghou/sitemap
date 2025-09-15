import strutils, httpClient, os, streams

type Cli* = object
    cli: HttpClient


proc req(kv: openArray[tuple[key: string, val: string]], refer: string = ""): HttpHeaders =
    var headers = newHttpHeaders(kv)
    if not refer.isEmptyOrWhitespace:
        headers.add("Referer", refer)
    for key, val in envPairs():
        if key.startsWith("HEADER_"):
            let hName = key[7..^1] # 移除"HEADER_"前缀
            if not hName.isEmptyOrWhitespace and not val.isEmptyOrWhitespace:
                headers.add(hName, val)
    return headers


proc newCli*(timeout: int, ua: string = "", refer: string = ""): Cli =
    result.cli = newHttpClient(userAgent = ua, timeout = timeout, headers = req([], refer)) # 如果ua为空，发出去的HTTP请求无User-Agent字段

proc get*(self: Cli, url: string): Response =
    return self.cli.request(url, HttpGet)


proc copyStream(input: Stream, output: File) =
    var buf: array[4096, char]
    while not input.atEnd:
        let bytesRead = input.readData(addr buf[0], buf.len)
        if bytesRead > 0:
            discard output.writeBuffer(addr buf[0], bytesRead)

proc download*(self: Cli, url: string, name: string) =
    if name == "/dev/stdout" or name == "-":
        let resp = self.cli.get(url)
        copyStream(resp.bodyStream, stdout)
        return
    if fileExists(name):
        return
    var fname = name&".tmp"
    self.cli.downloadFile(url, fname)
    moveFile(fname, name)
