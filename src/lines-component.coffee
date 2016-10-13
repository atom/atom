CursorsComponent = require './cursors-component'
LinesTileComponent = require './lines-tile-component'
TiledComponent = require './tiled-component'

DummyLineNode = document.createElement('div')
DummyLineNode.className = 'line'
DummyLineNode.style.position = 'absolute'
DummyLineNode.style.visibility = 'hidden'
DummyLineNode.appendChild(document.createElement('span'))
DummyLineNode.appendChild(document.createElement('span'))
DummyLineNode.appendChild(document.createElement('span'))
DummyLineNode.appendChild(document.createElement('span'))
DummyLineNode.children[0].textContent = 'x'
DummyLineNode.children[1].textContent = '我'
DummyLineNode.children[2].textContent = 'ﾊ'
DummyLineNode.children[3].textContent = '세'

module.exports =
class LinesComponent extends TiledComponent
  placeholderTextDiv: null

  constructor: ({@presenter, @domElementPool, @assert}) ->
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

  getDomNode: ->
    @domNode

  shouldRecreateAllTilesOnUpdate: ->
    @newState.continuousReflow

  beforeUpdateSync: (state) ->
    if @newState.maxHeight isnt @oldState.maxHeight
      @domNode.style.height = @newState.maxHeight + 'px'
      @oldState.maxHeight = @newState.maxHeight

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
      @oldState.placeholderText = @newState.placeholderText

    @cursorsComponent.updateSync(state)

  buildComponentForTile: (id) -> new LinesTileComponent({id, @presenter, @domElementPool, @assert})

  buildEmptyState: ->
    {tiles: {}}

  getNewState: (state) ->
    state.content

  getTilesNode: -> @tilesNode

  measureLineHeightAndDefaultCharWidth: ->
    @domNode.appendChild(DummyLineNode)

    lineHeightInPixels = DummyLineNode.getBoundingClientRect().height
    defaultCharWidth = DummyLineNode.children[0].getBoundingClientRect().width
    doubleWidthCharWidth = DummyLineNode.children[1].getBoundingClientRect().width
    halfWidthCharWidth = DummyLineNode.children[2].getBoundingClientRect().width
    koreanCharWidth = DummyLineNode.children[3].getBoundingClientRect().width

    @domNode.removeChild(DummyLineNode)

    @presenter.setLineHeight(lineHeightInPixels)
    @presenter.setBaseCharacterWidth(defaultCharWidth, doubleWidthCharWidth, halfWidthCharWidth, koreanCharWidth)

  lineIdForScreenRow: (screenRow) ->
    tile = @presenter.tileForRow(screenRow)
    @getComponentForTile(tile)?.lineIdForScreenRow(screenRow)

  lineNodeForScreenRow: (screenRow) ->
    tile = @presenter.tileForRow(screenRow)
    @getComponentForTile(tile)?.lineNodeForScreenRow(screenRow)

  textNodesForScreenRow: (screenRow) ->
    tile = @presenter.tileForRow(screenRow)
    @getComponentForTile(tile)?.textNodesForScreenRow(screenRow)
