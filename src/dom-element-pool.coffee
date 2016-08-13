module.exports =
class DOMElementPool
  constructor: ->
    @freeElementsByTagName = {}
    @freedElements = new Set

  clear: ->
    @freedElements.clear()
    for tagName, freeElements of @freeElementsByTagName
      freeElements.length = 0
    return

  build: (tagName, factory, reset) ->
    element = @freeElementsByTagName[tagName]?.pop()
    element ?= factory()
    reset(element)
    @freedElements.delete(element)
    element

  buildElement: (tagName, className) ->
    factory = -> document.createElement(tagName)
    reset = (element) ->
      delete element.dataset[dataId] for dataId of element.dataset
      element.removeAttribute("style")
      if className?
        element.className = className
      else
        element.removeAttribute("class")
    @build(tagName, factory, reset)

  buildText: (textContent) ->
    factory = -> document.createTextNode(textContent)
    reset = (element) -> element.textContent = textContent
    @build("#text", factory, reset)

  freeElementAndDescendants: (element) ->
    @free(element)
    @freeDescendants(element)

  freeDescendants: (element) ->
    for descendant in element.childNodes by -1
      @free(descendant)
      @freeDescendants(descendant)
    return

  free: (element) ->
    throw new Error("The element cannot be null or undefined.") unless element?
    throw new Error("The element has already been freed!") if @freedElements.has(element)

    tagName = element.nodeName.toLowerCase()
    @freeElementsByTagName[tagName] ?= []
    @freeElementsByTagName[tagName].push(element)
    @freedElements.add(element)

    element.remove()
