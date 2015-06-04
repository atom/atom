{$$} = require 'space-pen'

CursorsComponent = require './cursors-component'
HighlightsComponent = require './highlights-component'
TileComponent = require './tile-component'
TiledComponent = require './tiled-component'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]

module.exports =
class LinesComponent extends TiledComponent
  placeholderTextDiv: null

  constructor: ({@presenter, @hostElement, @useShadowDOM, visible}) ->
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

  shouldRecreateAllTilesOnUpdate: ->
    @oldState.indentGuidesVisible isnt @newState.indentGuidesVisible

  afterUpdateSync: (state) ->
    if @newState.placeholderText isnt @oldState.placeholderText
      @placeholderTextDiv?.remove()
      if @newState.placeholderText?
        @placeholderTextDiv = document.createElement('div')
        @placeholderTextDiv.classList.add('placeholder-text')
        @placeholderTextDiv.textContent = @newState.placeholderText
        @domNode.appendChild(@placeholderTextDiv)

    @cursorsComponent.updateSync(state)
    @highlightsComponent.updateSync(state)

    @oldState.indentGuidesVisible = @newState.indentGuidesVisible
    @oldState.scrollWidth = @newState.scrollWidth

  buildComponentForTile: (id) -> new TileComponent({id, @presenter})

  buildEmptyState: ->
    {tiles: {}}

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

  lineNodeForScreenRow: (screenRow) ->
    tile = @presenter.tileForRow(screenRow)

    @componentsByTileId[tile]?.lineNodeForScreenRow(screenRow)
