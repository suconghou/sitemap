import parseopt, strutils, os, sets



type Config* = object
    ua*: string
    host*: string
    timeout*: uint
    file*: string
    urls*: HashSet[string]
    refer*: string

proc read*(path: string): string =
    if fileExists(path):
        return readFile(path)
    return "0"


proc put*(file: string, urls: HashSet[string]): bool =
    if urls.len == 0: return false
    const header = """<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">"""
    var texts = @[header]
    for url in urls:
        texts.add "<url><loc>" & url & "</loc></url>"
    texts.add "</urlset>"
    writeFile(file, texts.join(""))
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
        of cmdEnd: assert(false) # cannot happen
    return cfg
