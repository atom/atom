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

  buildElement (tagName, className) {
    let element = this.freeElementsByTagName[tagName] ? this.freeElementsByTagName[tagName].pop() : null
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
    let element = this.freeElementsByTagName['#text'] ? this.freeElementsByTagName['#text'].pop() : null
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
