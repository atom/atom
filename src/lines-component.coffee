_ = require 'underscore-plus'
{toArray} = require 'underscore-plus'
{$$} = require 'space-pen'

CursorsComponent = require './cursors-component'
HighlightsComponent = require './highlights-component'
TileComponent = require './tile-component'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
WrapperDiv = document.createElement('div')

cloneObject = (object) ->
  clone = {}
  clone[key] = value for key, value of object
  clone

module.exports =
class LinesComponent
  placeholderTextDiv: null

  constructor: ({@presenter, @hostElement, @useShadowDOM, visible}) ->
    @tileComponentsByTileId = {}

    @domNode = document.createElement('div')
    @domNode.classList.add('lines')

    @cursorsComponent = new CursorsComponent(@presenter)
    @domNode.appendChild(@cursorsComponent.getDomNode())

    @highlightsComponent = new HighlightsComponent(@presenter)
    @domNode.appendChild(@highlightsComponent.getDomNode())

    if @useShadowDOM
      insertionPoint = document.createElement('content')
      insertionPoint.setAttribute('select', '.overlayer')
      @domNode.appendChild(insertionPoint)

  getDomNode: ->
    @domNode

  updateSync: (state) ->
    @newState = state.content
    @oldState ?= {tiles: {}}

    if @newState.scrollHeight isnt @oldState.scrollHeight
      @domNode.style.height = @newState.scrollHeight + 'px'
      @oldState.scrollHeight = @newState.scrollHeight

    if @newState.scrollLeft isnt @oldState.scrollLeft
      @domNode.style['-webkit-transform'] = "translate3d(#{-@newState.scrollLeft}px, 0, 0px)"
      @oldState.scrollLeft = @newState.scrollLeft

    if @newState.backgroundColor isnt @oldState.backgroundColor
      @domNode.style.backgroundColor = @newState.backgroundColor
      @oldState.backgroundColor = @newState.backgroundColor

    if @newState.placeholderText isnt @oldState.placeholderText
      @placeholderTextDiv?.remove()
      if @newState.placeholderText?
        @placeholderTextDiv = document.createElement('div')
        @placeholderTextDiv.classList.add('placeholder-text')
        @placeholderTextDiv.textContent = @newState.placeholderText
        @domNode.appendChild(@placeholderTextDiv)

    @removeTileNodes() unless @oldState.indentGuidesVisible is @newState.indentGuidesVisible
    @updateTileNodes()

    if @newState.scrollWidth isnt @oldState.scrollWidth
      @domNode.style.width = @newState.scrollWidth + 'px'
      @oldState.scrollWidth = @newState.scrollWidth

    @cursorsComponent.updateSync(state)
    @highlightsComponent.updateSync(state)

    @oldState.indentGuidesVisible = @newState.indentGuidesVisible
    @oldState.scrollWidth = @newState.scrollWidth

  removeTileNodes: ->
    @removeTileNode(id) for id of @oldState.tiles
    return

  removeTileNode: (id) ->
    @tileComponentsByTileId[id].getDomNode().remove()
    delete @tileComponentsByTileId[id]
    delete @oldState.tiles[id]

  updateTileNodes: ->
    for id of @oldState.tiles
      unless @newState.tiles.hasOwnProperty(id)
        @removeTileNode(id)

    for id, tileState of @newState.tiles
      tileComponent = @tileComponentsByTileId[id] ?= new TileComponent({id, @presenter})

      unless @oldState.tiles.hasOwnProperty(id)
        @domNode.appendChild(tileComponent.getDomNode())
        @oldState.tiles[id] = cloneObject(tileState)

      tileComponent.updateSync(@newState)

    return

  measureLineHeightAndDefaultCharWidth: ->
    @domNode.appendChild(DummyLineNode)
    lineHeightInPixels = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    @domNode.removeChild(DummyLineNode)

    @presenter.setLineHeight(lineHeightInPixels)
    @presenter.setBaseCharacterWidth(charWidth)

  remeasureCharacterWidths: ->
    return unless @presenter.baseCharacterWidth

    @clearScopedCharWidths()
    @measureCharactersInNewLines()

  measureCharactersInNewLines: ->
    @presenter.batchCharacterMeasurement =>
      for id, lineState of @oldState.lines
        unless @measuredLines.has(id)
          lineNode = @lineNodesByLineId[id]
          @measureCharactersInLine(id, lineState, lineNode)
      return

  measureCharactersInLine: (lineId, tokenizedLine, lineNode) ->
    rangeForMeasurement = null
    iterator = null
    charIndex = 0

    for {value, scopes, hasPairedCharacter} in tokenizedLine.tokens
      charWidths = @presenter.getScopedCharacterWidths(scopes)

      valueIndex = 0
      while valueIndex < value.length
        if hasPairedCharacter
          char = value.substr(valueIndex, 2)
          charLength = 2
          valueIndex += 2
        else
          char = value[valueIndex]
          charLength = 1
          valueIndex++

        continue if char is '\0'

        unless charWidths[char]?
          unless textNode?
            rangeForMeasurement ?= document.createRange()
            iterator =  document.createNodeIterator(lineNode, NodeFilter.SHOW_TEXT, AcceptFilter)
            textNode = iterator.nextNode()
            textNodeIndex = 0
            nextTextNodeIndex = textNode.textContent.length

          while nextTextNodeIndex <= charIndex
            textNode = iterator.nextNode()
            textNodeIndex = nextTextNodeIndex
            nextTextNodeIndex = textNodeIndex + textNode.textContent.length

          i = charIndex - textNodeIndex
          rangeForMeasurement.setStart(textNode, i)
          rangeForMeasurement.setEnd(textNode, i + charLength)
          charWidth = rangeForMeasurement.getBoundingClientRect().width
          @presenter.setScopedCharacterWidth(scopes, char, charWidth)

        charIndex += charLength

    @measuredLines.add(lineId)

  clearScopedCharWidths: ->
    @measuredLines.clear()
    @presenter.clearScopedCharacterWidths()
