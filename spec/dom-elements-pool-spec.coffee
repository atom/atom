DomElementsPool = require '../src/dom-elements-pool'

describe "DomElementsPool", ->
  domElementsPool = null

  beforeEach ->
    domElementsPool = new DomElementsPool

  it "creates new nodes until some of them are freed", ->
    span1 = domElementsPool.build("span")
    span2 = domElementsPool.build("span")
    span3 = domElementsPool.build("span")

    expect(span1).not.toBe(span2)
    expect(span2).not.toBe(span3)

    domElementsPool.free(span1)
    domElementsPool.free(span2)

    expect(domElementsPool.build("span")).toBe(span2)
    expect(domElementsPool.build("span")).toBe(span1)

  it "recursively frees a dom tree", ->
    div = domElementsPool.build("div")
    span1 = domElementsPool.build("span")
    span2 = domElementsPool.build("span")
    span3 = domElementsPool.build("span")
    span4 = domElementsPool.build("span")

    div.appendChild(span1)
    span1.appendChild(span2)
    div.appendChild(span3)
    span3.appendChild(span4)

    domElementsPool.freeElementAndDescendants(div)

    expect(domElementsPool.build("div")).toBe(div)
    expect(domElementsPool.build("span")).toBe(span3)
    expect(domElementsPool.build("span")).toBe(span4)
    expect(domElementsPool.build("span")).toBe(span1)
    expect(domElementsPool.build("span")).toBe(span2)
