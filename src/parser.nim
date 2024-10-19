import css3selectors, chame/minidom, streams, sets, sugar, strutils, tables


type HTMLParser = object
    doc: Document


proc document(s: Stream): HTMLParser =
    result.doc = parseHTML(s)


proc attr_value(d: HTMLParser, s: string): HashSet[string] =
    let t = strip(s.rsplit("]", 1)[0].rsplit("[", 1)[1])
    var attr = newStringOfCap(t.len)
    for x in t:
        if x in IdentChars:
            attr.add(x)
        else:
            break
    let a = d.doc.querySelectorAll(s)
    result = collect(initHashSet()):
        for x in a:
            let v = x.getAttr(attr).strip()
            if not v.isEmptyOrWhitespace:
                {v}


type PageProcessor* = object
    attrs*: TableRef[string, HashSet[string]]


proc newPageProcessor*(): PageProcessor =
    result.attrs = newTable[string, initHashSet[string]()]()

# a 标签提取器
proc process*(p: PageProcessor, u: string, s: Stream, attrs: HashSet[string]): HashSet[string] =
    let d = document(s)
    result = d.attr_value("a[href]")
    for item in attrs:
        p.attrs[item] = union(p.attrs.getOrDefault(item, initHashSet[string]()), try: d.attr_value(item) except: initHashSet[string]())
