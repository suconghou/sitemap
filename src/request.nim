import strutils, httpClient, os

type Cli* = object
    cli: HttpClient


proc req(kv: openArray[tuple[key: string, val: string]], refer: string = ""): HttpHeaders =
    var headers = newHttpHeaders(kv)
    if not refer.isEmptyOrWhitespace:
        headers.add("Referer", refer)
    return headers


proc newCli*(timeout: int, ua: string = "", refer: string = ""): Cli =
    result.cli = newHttpClient(userAgent = ua, timeout = timeout, headers = req([], refer)) # 如果ua为空，发出去的HTTP请求无User-Agent字段

proc get*(self: Cli, url: string): Response =
    return self.cli.request(url, HttpGet)


proc download*(self: Cli, url: string, name: string) =
    if fileExists(name):
        return
    var fname = name&".tmp"
    self.cli.downloadFile(url, fname)
    moveFile(fname, name)
