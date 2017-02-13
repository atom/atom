module.exports =
class DOMElementPool {
  constructor () {
    this.freeElementsByTagName = new Map()
    this.freedElements = new Set()
  }

  clear () {
    this.freedElements.clear()
    this.freeElementsByTagName.clear()
  }

  buildElement (tagName, className) {
    const elements = this.freeElementsByTagName.get(tagName)
    let element = elements ? elements.pop() : null
    if (element) {
      for (let dataId in element.dataset) { delete element.dataset[dataId] }
      element.removeAttribute('style')
      if (className != null) {
        element.className = className
      } else {
        element.removeAttribute('class')
      }
      this.freedElements.delete(element)
    } else {
      element = document.createElement(tagName)
    }
    return element
  }

  buildText (textContent) {
    const elements = this.freeElementsByTagName.get('#text')
    let element = elements ? elements.pop() : null
    if (element) {
      element.textContent = textContent
      this.freedElements.delete(element)
    } else {
      element = document.createTextNode(textContent)
    }
    return element
  }

  freeElementAndDescendants (element) {
    this.free(element)
    this.freeDescendants(element)
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
    let elements = this.freeElementsByTagName.get(tagName)
    if (!elements) {
      elements = []
      this.freeElementsByTagName.set(tagName, elements)
    }
    elements.push(element)
    this.freedElements.add(element)

    element.remove()
  }
}
