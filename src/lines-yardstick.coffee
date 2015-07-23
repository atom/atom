LineHtmlBuilder = require './line-html-builder'
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
rangeForMeasurement = document.createRange()
{Emitter} = require 'event-kit'
{last} = require 'underscore-plus'

module.exports =
class LinesYardstick
  constructor: (@editor, @presenter, hostElement, @syntaxStyleElement) ->
    @initialized = false
    @emitter = new Emitter
    @scopesCache = {}
    @fontSelectors = []
    @linesBuilder = new LineHtmlBuilder(true)
    @defaultStyleNode = document.createElement("style")
    @skinnyStyleNode = document.createElement("style")
    @iframe = document.createElement("iframe")
    @iframe.style.display = "none"
    @iframe.onload = @setupIframe
    @lineNodesByLineId = {}
    @lineNodesByContextIndexAndLineId = {}
    @activeContextIndex = -1

    hostElement.appendChild(@iframe)

  setFont: (fontFamily, fontSize) ->
    @defaultStyleNode.innerHTML = "body { margin: 0; padding: 0; font-size: #{fontSize}; font-family: #{fontFamily}; white-space: pre; }"

  onDidInitialize: (callback) ->
    @emitter.on "did-initialize", callback

  canMeasure: ->
    @initialized

  ensureInitialized: ->
    return if @canMeasure()

    throw new Error("This instance of LinesYardstick hasn't been initialized!")

  createMeasurementContext: ->
    context = document.createElement("div")
    context.style.overflow = "hidden"
    context.style.width = "600px"
    context.style.height = "600px"
    context.style.display = "block"
    context

  setupIframe: =>
    @initialized = true
    @domNode = @iframe.contentDocument.body
    @headNode = @iframe.contentDocument.head

    @rebuildSkinnyStyleNode()
    @headNode.appendChild(@defaultStyleNode)
    @headNode.appendChild(@skinnyStyleNode)

    @linesBuilder.setScopeFilterFn (scope) =>
      return @scopesCache[scope] if @scopesCache.hasOwnProperty(scope)

      cssClasses = scope.split(".")
      for fontSelector in @fontSelectors
        for cssClass in cssClasses
          if fontSelector.indexOf(".#{cssClass}") isnt -1
            @scopesCache[scope] = true
            return true

      @scopesCache[scope] = false
      return false

    @contexts = []
    @contexts.push(@createMeasurementContext()) for i in [0..8] by 1
    @domNode.appendChild(context) for context in @contexts

    @emitter.emit "did-initialize"

  rebuildSkinnyStyleNode: ->
    skinnyCss = ""
    @scopesCache = {}
    @fontSelectors.length = 0

    for style in @syntaxStyleElement.children
      for cssRule in style.sheet.cssRules when @hasFontStyling(cssRule)
        @fontSelectors.push(cssRule.selectorText)
        skinnyCss += cssRule.cssText

    @skinnyStyleNode.innerHTML = skinnyCss

  hasFontStyling: (cssRule) ->
    for styleProperty in cssRule.style
      return true if styleProperty.indexOf("font") isnt -1

    return false

  getNextContextNode: ->
    @activeContextIndex = (@activeContextIndex + 1) % @contexts.length

    [@activeContextIndex, @contexts[@activeContextIndex]]

  lineNodesForContextIndex: (contextIndex) ->
    @lineNodesByContextIndex[contextIndex] ? []

  buildDomNodesForScreenRows: (screenRows) ->
    @ensureInitialized()

    visibleLines = {}
    html = ""
    [contextIndex, contextNode] = @getNextContextNode()

    newLinesIds = []
    screenRows.forEach (screenRow) =>
      line = @editor.tokenizedLineForScreenRow(screenRow)
      return unless line?
      visibleLines[line.id] = true

      unless @lineNodesByLineId.hasOwnProperty(line.id)
        lineState = @presenter.buildLineState(0, screenRow, line)
        html += @linesBuilder.buildLineHTML(false, 1000, lineState)
        newLinesIds.push(line.id)

    for lineId, lineNode of @lineNodesByContextIndexAndLineId[contextIndex]
      continue if visibleLines.hasOwnProperty(lineId)

      lineNode.remove()

      delete @lineNodesByLineId[lineId]
      delete @lineNodesByContextIndexAndLineId[contextIndex][lineId]

    contextNode.insertAdjacentHTML("beforeend", html)

    @lineNodesByContextIndexAndLineId[contextIndex] ?= {}
    index = contextNode.children.length - 1
    while lineId = newLinesIds.pop()
      lineNode = contextNode.children[index--]
      @lineNodesByLineId[lineId] = lineNode
      @lineNodesByContextIndexAndLineId[contextIndex][lineId] = lineNode

  lineNodeForScreenRow: (screenRow) ->
    line = @editor.tokenizedLineForScreenRow(screenRow)
    lineNode = @lineNodesByLineId[line.id]
    lineNode

  leftPixelPositionForScreenPosition: (position) ->
    @ensureInitialized()

    lineNode = @lineNodeForScreenRow(position.row)

    unless lineNode?
      # console.log "#{position.row} not found. This wasn't expected."
      return 0

    tokens = lineNode.getElementsByClassName("token")

    return 0 if tokens.length is 0

    if foundToken = @findTokenByColumn(position.column, tokens)
      textNode = foundToken.childNodes[0]
      positionWithinToken = position.column - parseInt(foundToken.dataset.start)
    else
      textNode = last(tokens).childNodes[0]
      positionWithinToken = textNode.textContent.length

    @leftPixelPositionForCharInTextNode(textNode, positionWithinToken)

  findTokenByColumn: (column, tokens, startIndex = 0, endIndex = tokens.length) ->
    index = Math.floor((startIndex + endIndex) / 2)

    return if startIndex > endIndex or index is tokens.length

    element = tokens[index]

    rangeStart = parseInt(element.dataset.start)
    rangeEnd = parseInt(element.dataset.end)

    if rangeStart > column
      @findTokenByColumn(column, tokens, startIndex, index - 1)
    else if rangeEnd < column
      @findTokenByColumn(column, tokens, index + 1, endIndex)
    else
      element

  leftPixelPositionForCharInTextNode: (textNode, charIndex = textNode.textContent.length) ->
    rangeForMeasurement.setEnd(textNode, textNode.textContent.length)

    if charIndex is 0
      rangeForMeasurement.setStart(textNode, 0)
      rangeForMeasurement.getBoundingClientRect().left
    else if charIndex is textNode.textContent.length
      rangeForMeasurement.setStart(textNode, 0)
      rangeForMeasurement.getBoundingClientRect().right
    else
      rangeForMeasurement.setStart(textNode, charIndex)
      rangeForMeasurement.getBoundingClientRect().left
