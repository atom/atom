DomElementsPool = require '../src/dom-elements-pool'

describe "DomElementsPool", ->
  domElementsPool = null

  beforeEach ->
    domElementsPool = new DomElementsPool

  it "builds DOM nodes, recycling them when they are freed", ->
    [div, span1, span2, span3, span4] = elements = [
      domElementsPool.build("div")
      domElementsPool.build("span")
      domElementsPool.build("span")
      domElementsPool.build("span")
      domElementsPool.build("span")
    ]

    div.appendChild(span1)
    span1.appendChild(span2)
    div.appendChild(span3)
    span3.appendChild(span4)

    domElementsPool.freeElementAndDescendants(div)

    expect(elements).toContain(domElementsPool.build("div"))
    expect(elements).toContain(domElementsPool.build("span"))
    expect(elements).toContain(domElementsPool.build("span"))
    expect(elements).toContain(domElementsPool.build("span"))
    expect(elements).toContain(domElementsPool.build("span"))

    expect(elements).not.toContain(domElementsPool.build("span"))

  it "throws an error when trying to free the same node twice", ->
    div = domElementsPool.build("div")
    domElementsPool.freeElementAndDescendants(div)
    expect(-> domElementsPool.freeElementAndDescendants(div)).toThrow()

  it "throws an error when trying to free an invalid element", ->
    expect(-> domElementsPool.freeElementAndDescendants(null)).toThrow()
    expect(-> domElementsPool.freeElementAndDescendants(undefined)).toThrow()
