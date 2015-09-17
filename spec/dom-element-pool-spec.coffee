DOMElementPool = require '../src/dom-element-pool'

describe "DOMElementPool", ->
  domElementPool = null

  beforeEach ->
    domElementPool = new DOMElementPool

  it "builds DOM nodes, recycling them when they are freed", ->
    [div, span1, span2, span3, span4, span5] = elements = [
      domElementPool.build("div")
      domElementPool.build("span")
      domElementPool.build("span")
      domElementPool.build("span")
      domElementPool.build("span")
      domElementPool.build("span")
    ]

    div.appendChild(span1)
    span1.appendChild(span2)
    div.appendChild(span3)
    span3.appendChild(span4)

    domElementPool.freeElementAndDescendants(div)
    domElementPool.freeElementAndDescendants(span5)

    expect(elements).toContain(domElementPool.build("div"))
    expect(elements).toContain(domElementPool.build("span"))
    expect(elements).toContain(domElementPool.build("span"))
    expect(elements).toContain(domElementPool.build("span"))
    expect(elements).toContain(domElementPool.build("span"))
    expect(elements).toContain(domElementPool.build("span"))

    expect(elements).not.toContain(domElementPool.build("div"))
    expect(elements).not.toContain(domElementPool.build("span"))

  it "forgets free nodes after being cleared", ->
    span = domElementPool.build("span")
    div = domElementPool.build("div")
    domElementPool.freeElementAndDescendants(span)
    domElementPool.freeElementAndDescendants(div)

    domElementPool.clear()

    expect(domElementPool.build("span")).not.toBe(span)
    expect(domElementPool.build("div")).not.toBe(div)

  it "throws an error when trying to free the same node twice", ->
    div = domElementPool.build("div")
    domElementPool.freeElementAndDescendants(div)
    expect(-> domElementPool.freeElementAndDescendants(div)).toThrow()

  it "throws an error when trying to free an invalid element", ->
    expect(-> domElementPool.freeElementAndDescendants(null)).toThrow()
    expect(-> domElementPool.freeElementAndDescendants(undefined)).toThrow()
