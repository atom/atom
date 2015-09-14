module.exports =
class DomElementsPool
  constructor: ->
    @freeElementsByTagName = {}

  build: (tagName, className, textContent) ->
    element = @freeElementsByTagName[tagName]?.pop()
    element ?= document.createElement(tagName)
    element.className = className
    element.textContent = textContent
    element.removeAttribute("style")
    element

  free: (element) ->
    element.remove()
    @freeElementsByTagName[element.tagName.toLowerCase()] ?= []
    @freeElementsByTagName[element.tagName.toLowerCase()].push(element)

  freeElementAndDescendants: (element) ->
    @free(element)

    for index in [element.children.length - 1..0] by -1
      child = element.children[index]
      @freeElementAndDescendants(child)
