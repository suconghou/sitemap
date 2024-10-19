import strutils, httpClient

proc req(kv: openArray[tuple[key: string, val: string]], refer: string = ""): HttpHeaders =
    var headers = newHttpHeaders(kv)
    if not refer.isEmptyOrWhitespace:
        headers.add("Referer", refer)
    return headers

proc get*(url: string, timeout: int, ua: string = "", refer: string = ""): Response =
    let client = newHttpClient(userAgent = ua, timeout = timeout, headers = req([], refer)) # 如果ua为空，发出去的HTTP请求无User-Agent字段
    return client.request(url, HttpGet)

proc gets*(url: string, timeout: int, ua: string = "", refer: string = ""): (HttpCode, string) =
    let resp = get(url, timeout, ua, refer)
    return (resp.code, resp.body)
