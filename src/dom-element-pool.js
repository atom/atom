module.exports =
class DOMElementPool {
  constructor () {
    this.freeElementsByTagName = {}
    this.freedElements = new Set()
  }

  clear () {
    this.freedElements.clear()
    for (let tagName in this.freeElementsByTagName) {
      const freeElements = this.freeElementsByTagName[tagName]
      freeElements.length = 0
    }
  }

  build (tagName, factory, reset) {
    let element = this.freeElementsByTagName[tagName] ? this.freeElementsByTagName[tagName].pop() : null
    if (!element) { element = factory() }
    reset(element)
    this.freedElements.delete(element)
    return element
  }

  buildElement (tagName, className) {
    const factory = () => document.createElement(tagName)
    const reset = function (element) {
      for (let dataId in element.dataset) { delete element.dataset[dataId] }
      element.removeAttribute('style')
      if (className != null) {
        element.className = className
      } else {
        element.removeAttribute('class')
      }
    }
    return this.build(tagName, factory, reset)
  }

  buildText (textContent) {
    const factory = () => document.createTextNode(textContent)
    const reset = element => { element.textContent = textContent }
    return this.build('#text', factory, reset)
  }

  freeElementAndDescendants (element) {
    this.free(element)
    return this.freeDescendants(element)
  }

  freeDescendants (element) {
    for (let i = element.childNodes.length - 1; i >= 0; i--) {
      const descendant = element.childNodes[i]
      this.free(descendant)
      this.freeDescendants(descendant)
    }
  }

  free (element) {
    if (element == null) { throw new Error('The element cannot be null or undefined.') }
    if (this.freedElements.has(element)) { throw new Error('The element has already been freed!') }

    const tagName = element.nodeName.toLowerCase()
    if (this.freeElementsByTagName[tagName] == null) { this.freeElementsByTagName[tagName] = [] }
    this.freeElementsByTagName[tagName].push(element)
    this.freedElements.add(element)

    return element.remove()
  }
}
