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

proc post(url: string, timeout: int, body: string, ua: string = "", refer: string = ""): bool =
    let client = newHttpClient(userAgent = ua, timeout = timeout, headers = req({"Content-Type": "application/json"}, refer))
    let resp = client.request(url, HttpPost, body)
    if resp.code == Http200 or resp.code == Http204:
        return true
    return false

proc report*(url: string, body: string, ua: string = "", refer: string = ""): bool =
    try:
        return post(url, timeout = 5000, body, ua, refer)
    except Exception:
        return false

proc notify*(body: string, tokens: openArray[string], timeout = 5000): seq[bool] =
    var res: seq[bool]
    for token in tokens:
        let url = "https://oapi.dingtalk.com/robot/send?access_token="&token
        let r = post(url, timeout, body)
        res.add(r)
    return res
