{$$} = require 'space-pen'

CursorsComponent = require './cursors-component'
TileComponent = require './tile-component'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]

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

    if @newState.width isnt @oldState.width
      @domNode.style.width = @newState.width + 'px'

    @cursorsComponent.updateSync(state)

    @oldState.indentGuidesVisible = @newState.indentGuidesVisible
    @oldState.scrollWidth = @newState.scrollWidth
    @oldState.width = @newState.width

  removeTileNodes: ->
    @removeTileNode(id) for id of @oldState.tiles
    return

  removeTileNode: (id) ->
    node = @tileComponentsByTileId[id].getDomNode()

    node.remove()
    delete @tileComponentsByTileId[id]
    delete @oldState.tiles[id]

  updateTileNodes: ->
    for id of @oldState.tiles
      unless @newState.tiles.hasOwnProperty(id)
        @removeTileNode(id)

    for id, tileState of @newState.tiles
      if @oldState.tiles.hasOwnProperty(id)
        tileComponent = @tileComponentsByTileId[id]
      else
        tileComponent = @tileComponentsByTileId[id] = new TileComponent({id, @presenter})

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
      for id, component of @tileComponentsByTileId
        component.measureCharactersInNewLines()

      return

  clearScopedCharWidths: ->
    for id, component of @tileComponentsByTileId
      component.clearMeasurements()

    @presenter.clearScopedCharacterWidths()

  lineNodeForScreenRow: (screenRow) ->
    tile = @presenter.tileForRow(screenRow)

    @tileComponentsByTileId[tile]?.lineNodeForScreenRow(screenRow)
