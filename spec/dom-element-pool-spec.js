const DOMElementPool = require ('../src/dom-element-pool')

describe('DOMElementPool', function () {
  let domElementPool

  beforeEach(() => { domElementPool = new DOMElementPool() })

  it('builds DOM nodes, recycling them when they are freed', function () {
    let elements
    const [div, span1, span2, span3, span4, span5, textNode] = Array.from(elements = [
      domElementPool.buildElement('div'),
      domElementPool.buildElement('span'),
      domElementPool.buildElement('span'),
      domElementPool.buildElement('span'),
      domElementPool.buildElement('span'),
      domElementPool.buildElement('span'),
      domElementPool.buildText('Hello world!')
    ])

    div.appendChild(span1)
    span1.appendChild(span2)
    div.appendChild(span3)
    span3.appendChild(span4)
    span4.appendChild(textNode)

    domElementPool.freeElementAndDescendants(div)
    domElementPool.freeElementAndDescendants(span5)

    expect(elements.includes(domElementPool.buildElement('div'))).toBe(true)
    expect(elements.includes(domElementPool.buildElement('span'))).toBe(true)
    expect(elements.includes(domElementPool.buildElement('span'))).toBe(true)
    expect(elements.includes(domElementPool.buildElement('span'))).toBe(true)
    expect(elements.includes(domElementPool.buildElement('span'))).toBe(true)
    expect(elements.includes(domElementPool.buildElement('span'))).toBe(true)
    expect(elements.includes(domElementPool.buildText('another text'))).toBe(true)

    expect(elements.includes(domElementPool.buildElement('div'))).toBe(false)
    expect(elements.includes(domElementPool.buildElement('span'))).toBe(false)
    expect(elements.includes(domElementPool.buildText('unexisting'))).toBe(false)
  })

  it('forgets free nodes after being cleared', function () {
    const span = domElementPool.buildElement('span')
    const div = domElementPool.buildElement('div')
    domElementPool.freeElementAndDescendants(span)
    domElementPool.freeElementAndDescendants(div)

    domElementPool.clear()

    expect(domElementPool.buildElement('span')).not.toBe(span)
    expect(domElementPool.buildElement('div')).not.toBe(div)
  })

  it('throws an error when trying to free the same node twice', function () {
    const div = domElementPool.buildElement('div')
    domElementPool.freeElementAndDescendants(div)
    expect(() => domElementPool.freeElementAndDescendants(div)).toThrow()
  })

  it('throws an error when trying to free an invalid element', function () {
    expect(() => domElementPool.freeElementAndDescendants(null)).toThrow()
    expect(() => domElementPool.freeElementAndDescendants(undefined)).toThrow()
  })
})
