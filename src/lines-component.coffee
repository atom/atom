CursorsComponent = require './cursors-component'
LinesTileComponent = require './lines-tile-component'
TiledComponent = require './tiled-component'

DummyLineNode = null

module.exports =
class LinesComponent extends TiledComponent
  placeholderTextDiv: null

  constructor: ({@presenter, @useShadowDOM, @domElementPool, @assert, @grammars}) ->
    DummyLineNode ?= @buildDummyLineNode()
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

  buildDummyLineNode: ->
    node = document.createElement('div')
    node.className = 'line'
    node.style.position = 'absolute'
    node.style.visibility = 'hidden'
    node.appendChild(document.createElement('span'))
    node.appendChild(document.createElement('span'))
    node.appendChild(document.createElement('span'))
    node.appendChild(document.createElement('span'))
    node.children[0].textContent = 'x' # latin
    node.children[1].textContent = '我' # double width
    node.children[2].textContent = 'ﾊ' # half width
    node.children[3].textContent = '세' # korean
    node

  getDomNode: ->
    @domNode

  shouldRecreateAllTilesOnUpdate: ->
    @oldState.indentGuidesVisible isnt @newState.indentGuidesVisible or @newState.continuousReflow

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

    if @newState.width isnt @oldState.width
      @domNode.style.width = @newState.width + 'px'
      @oldState.width = @newState.width

    @cursorsComponent.updateSync(state)

    @oldState.indentGuidesVisible = @newState.indentGuidesVisible

  buildComponentForTile: (id) -> new LinesTileComponent({id, @presenter, @domElementPool, @assert, @grammars})

  buildEmptyState: ->
    {tiles: {}}

  getNewState: (state) ->
    state.content

  getTilesNode: -> @tilesNode

  measureLineHeightAndDefaultCharWidth: ->
    @domNode.appendChild(DummyLineNode)
    textNode = DummyLineNode.firstChild.childNodes[0]

    lineHeightInPixels = DummyLineNode.getBoundingClientRect().height
    defaultCharWidth = DummyLineNode.children[0].getBoundingClientRect().width
    doubleWidthCharWidth = DummyLineNode.children[1].getBoundingClientRect().width
    halfWidthCharWidth = DummyLineNode.children[2].getBoundingClientRect().width
    koreanCharWidth = DummyLineNode.children[3].getBoundingClientRect().width

    @domNode.removeChild(DummyLineNode)

    @presenter.setLineHeight(lineHeightInPixels)
    @presenter.setBaseCharacterWidth(defaultCharWidth, doubleWidthCharWidth, halfWidthCharWidth, koreanCharWidth)

  lineNodeForLineIdAndScreenRow: (lineId, screenRow) ->
    tile = @presenter.tileForRow(screenRow)
    @getComponentForTile(tile)?.lineNodeForLineId(lineId)

  textNodesForLineIdAndScreenRow: (lineId, screenRow) ->
    tile = @presenter.tileForRow(screenRow)
    @getComponentForTile(tile)?.textNodesForLineId(lineId)
