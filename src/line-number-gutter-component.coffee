{setDimensionsAndBackground} = require './gutter-component-helpers'

TiledComponent = require './tiled-component'
LineNumbersTileComponent = require './line-numbers-tile-component'
WrapperDiv = document.createElement('div')
DummyLineNumberComponent = new LineNumbersTileComponent(id: -1)

module.exports =
class LineNumberGutterComponent extends TiledComponent
  dummyLineNumberNode: null

  constructor: ({@onMouseDown, @editor, @gutter}) ->
    @lineNumberNodesById = {}
    @visible = true

    @domNode = atom.views.getView(@gutter)
    @lineNumbersNode = @domNode.firstChild
    @lineNumbersNode.innerHTML = ''

    @domNode.addEventListener 'click', @onClick
    @domNode.addEventListener 'mousedown', @onMouseDown

  getDomNode: ->
    @domNode

  hideNode: ->
    if @visible
      @domNode.style.display = 'none'
      @visible = false

  showNode: ->
    if not @visible
      @domNode.style.removeProperty('display')
      @visible = true

  buildEmptyState: ->
    {
      tiles: {}
      styles: {}
    }

  getNewState: (state) -> state

  getTilesNode: -> @lineNumbersNode

  beforeUpdateSync: (state) ->
    @appendDummyLineNumber() unless @dummyLineNumberNode?

    setDimensionsAndBackground(@oldState.styles, @newState.styles, @lineNumbersNode)

    if @newState.maxLineNumberDigits isnt @oldState.maxLineNumberDigits
      @updateDummyLineNumber()
      @oldState.styles = {}

  afterUpdateSync: (state) ->
    @oldState.maxLineNumberDigits = @newState.maxLineNumberDigits

  buildComponentForTile: (id) -> new LineNumbersTileComponent({id})

  ###
  Section: Private Methods
  ###

  # This dummy line number element holds the gutter to the appropriate width,
  # since the real line numbers are absolutely positioned for performance reasons.
  appendDummyLineNumber: ->
    DummyLineNumberComponent.newState = @newState
    WrapperDiv.innerHTML = DummyLineNumberComponent.buildLineNumberHTML({bufferRow: -1})
    @dummyLineNumberNode = WrapperDiv.children[0]
    @lineNumbersNode.appendChild(@dummyLineNumberNode)

  updateDummyLineNumber: ->
    DummyLineNumberComponent.newState = @newState
    @dummyLineNumberNode.innerHTML = DummyLineNumberComponent.buildLineNumberInnerHTML(0, false)

  lineNumberNodeForScreenRow: (screenRow) ->
    for id, lineNumberState of @oldState.lineNumbers
      if lineNumberState.screenRow is screenRow
        return @lineNumberNodesById[id]
    null

  onMouseDown: (event) =>
    {target} = event
    lineNumber = target.parentNode

    unless target.classList.contains('icon-right') and lineNumber.classList.contains('foldable')
      @onMouseDown(event)

  onClick: (event) =>
    {target} = event
    lineNumber = target.parentNode

    if target.classList.contains('icon-right') and lineNumber.classList.contains('foldable')
      bufferRow = parseInt(lineNumber.getAttribute('data-buffer-row'))
      if lineNumber.classList.contains('folded')
        @editor.unfoldBufferRow(bufferRow)
      else
        @editor.foldBufferRow(bufferRow)
