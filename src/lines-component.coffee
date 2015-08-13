{$$} = require 'space-pen'

CursorsComponent = require './cursors-component'
LinesTileComponent = require './lines-tile-component'
TiledComponent = require './tiled-component'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]

module.exports =
class LinesComponent extends TiledComponent
  placeholderTextDiv: null

  constructor: ({@presenter, @hostElement, @useShadowDOM, visible}) ->
    @domNode = document.createElement('div')
    @domNode.classList.add('lines')
    @tilesNode = document.createElement("div")
    # Create a new stacking context, so that tiles z-index does not interfere
    # with other visual elements.
    @tilesNode.style.isolation = "isolate"
    @tilesNode.style.zIndex = 0
    @domNode.appendChild(@tilesNode)

    @cursorsComponent = new CursorsComponent
    @domNode.appendChild(@cursorsComponent.getDomNode())

    if @useShadowDOM
      insertionPoint = document.createElement('content')
      insertionPoint.setAttribute('select', '.overlayer')
      @domNode.appendChild(insertionPoint)

  getDomNode: ->
    @domNode

  shouldRecreateAllTilesOnUpdate: ->
    @oldState.indentGuidesVisible isnt @newState.indentGuidesVisible

  beforeUpdateSync: (state) ->
    if @newState.scrollHeight isnt @oldState.scrollHeight
      @domNode.style.height = @newState.scrollHeight + 'px'
      @oldState.scrollHeight = @newState.scrollHeight

    if @newState.backgroundColor isnt @oldState.backgroundColor
      @domNode.style.backgroundColor = @newState.backgroundColor
      @oldState.backgroundColor = @newState.backgroundColor

  afterUpdateSync: (state) ->
    if @newState.placeholderText isnt @oldState.placeholderText
      @placeholderTextDiv?.remove()
      if @newState.placeholderText?
        @placeholderTextDiv = document.createElement('div')
        @placeholderTextDiv.classList.add('placeholder-text')
        @placeholderTextDiv.textContent = @newState.placeholderText
        @domNode.appendChild(@placeholderTextDiv)

    if @newState.width isnt @oldState.width
      @domNode.style.width = @newState.width + 'px'
      @oldState.width = @newState.width

    @cursorsComponent.updateSync(state)

    @oldState.indentGuidesVisible = @newState.indentGuidesVisible

  buildComponentForTile: (id) -> new LinesTileComponent({id, @presenter})

  buildEmptyState: ->
    {tiles: {}}

  getNewState: (state) ->
    state.content

  getTilesNode: -> @tilesNode

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
      for id, component of @componentsByTileId
        component.measureCharactersInNewLines()

      return

  clearScopedCharWidths: ->
    for id, component of @componentsByTileId
      component.clearMeasurements()

    @presenter.clearScopedCharacterWidths()
