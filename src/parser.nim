import css3selectors, chame/minidom, streams, sets, sugar, strutils


type HTMLParser = object
    doc: Document


proc document(s: Stream): HTMLParser =
    result.doc = parseHTML(s)


proc a_href(d: HTMLParser): HashSet[string] =
    let a = d.doc.querySelectorAll("a")
    result = collect(initHashSet()):
        for x in a:
            let href = x.getAttr("href")
            if not href.isEmptyOrWhitespace:
                {href}


type PageProcessor* = object
    parser: HTMLParser


# a 标签提取器
proc process*(p: PageProcessor, u: string, s: Stream): HashSet[string] =
    let d = document(s)
    result = d.a_href()
    # try: TODO 可以附加其他对HTML的分析，例如分析所有image

