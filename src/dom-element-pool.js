module.exports =
class DOMElementPool {
  constructor () {
    this.managedElements = new Set()
    this.freeElementsByTagName = new Map()
    this.freedElements = new Set()
  }

  clear () {
    this.managedElements.clear()
    this.freedElements.clear()
    this.freeElementsByTagName.clear()
  }

  buildElement (tagName, className) {
    const elements = this.freeElementsByTagName.get(tagName)
    let element = elements ? elements.pop() : null
    if (element) {
      for (let dataId in element.dataset) { delete element.dataset[dataId] }
      element.removeAttribute('style')
      if (className) {
        element.className = className
      } else {
        element.removeAttribute('class')
      }
      while (element.firstChild) {
        element.removeChild(element.firstChild)
      }
      this.freedElements.delete(element)
    } else {
      element = document.createElement(tagName)
      if (className) {
        element.className = className
      }
      this.managedElements.add(element)
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
      this.managedElements.add(element)
    }
    return element
  }

  freeElementAndDescendants (element) {
    this.free(element)
    element.remove()
  }

  freeDescendants (element) {
    while (element.firstChild) {
      this.free(element.firstChild)
      element.removeChild(element.firstChild)
    }
  }

  free (element) {
    if (element == null) { throw new Error('The element cannot be null or undefined.') }
    if (!this.managedElements.has(element)) return
    if (this.freedElements.has(element)) {
      atom.assert(false, 'The element has already been freed!', {
        content: element instanceof Text ? element.textContent : element.outerHTML.toString()
      })
      return
    }

    const tagName = element.nodeName.toLowerCase()
    let elements = this.freeElementsByTagName.get(tagName)
    if (!elements) {
      elements = []
      this.freeElementsByTagName.set(tagName, elements)
    }
    elements.push(element)
    this.freedElements.add(element)

    for (let i = element.childNodes.length - 1; i >= 0; i--) {
      const descendant = element.childNodes[i]
      this.free(descendant)
    }
  }
}
