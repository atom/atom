_ = require 'underscore-plus'

module.exports =
class LineNumbersTileComponent
  @createDummy: (domElementPool) ->
    new LineNumbersTileComponent({id: -1, domElementPool})

  constructor: ({@id, @domElementPool}) ->
    @lineNumberNodesById = {}
    @domNode = @domElementPool.build("div", "tile")
    @domNode.style.position = "absolute"
    @domNode.style.display = "block"
    @domNode.style.top = 0 # Cover the space occupied by a dummy lineNumber

  destroy: ->
    @domElementPool.freeElementAndDescendants(@domNode)

  getDomNode: ->
    @domNode

  updateSync: (state) ->
    @newState = state
    unless @oldState
      @oldState = {tiles: {}, styles: {}}
      @oldState.tiles[@id] = {lineNumbers: {}}

    @newTileState = @newState.tiles[@id]
    @oldTileState = @oldState.tiles[@id]

    if @newTileState.display isnt @oldTileState.display
      @domNode.style.display = @newTileState.display
      @oldTileState.display = @newTileState.display

    if @newState.styles.backgroundColor isnt @oldState.styles.backgroundColor
      @domNode.style.backgroundColor = @newState.styles.backgroundColor
      @oldState.styles.backgroundColor = @newState.styles.backgroundColor

    if @newTileState.height isnt @oldTileState.height
      @domNode.style.height = @newTileState.height + 'px'
      @oldTileState.height = @newTileState.height

    if @newTileState.top isnt @oldTileState.top
      @domNode.style['-webkit-transform'] = "translate3d(0, #{@newTileState.top}px, 0px)"
      @oldTileState.top = @newTileState.top

    if @newTileState.zIndex isnt @oldTileState.zIndex
      @domNode.style.zIndex = @newTileState.zIndex
      @oldTileState.zIndex = @newTileState.zIndex

    if @newState.maxLineNumberDigits isnt @oldState.maxLineNumberDigits
      for id, node of @lineNumberNodesById
        @domElementPool.freeElementAndDescendants(node)

      @oldState.tiles[@id] = {lineNumbers: {}}
      @oldTileState = @oldState.tiles[@id]
      @lineNumberNodesById = {}
      @oldState.maxLineNumberDigits = @newState.maxLineNumberDigits

    @updateLineNumbers()

  updateLineNumbers: ->
    newLineNumberIds = null
    newLineNumberNodes = null

    for id, lineNumberState of @oldTileState.lineNumbers
      unless @newTileState.lineNumbers.hasOwnProperty(id)
        @domElementPool.freeElementAndDescendants(@lineNumberNodesById[id])
        delete @lineNumberNodesById[id]
        delete @oldTileState.lineNumbers[id]

    for id, lineNumberState of @newTileState.lineNumbers
      if @oldTileState.lineNumbers.hasOwnProperty(id)
        @updateLineNumberNode(id, lineNumberState)
      else
        newLineNumberIds ?= []
        newLineNumberNodes ?= []
        newLineNumberIds.push(id)
        newLineNumberNodes.push(@buildLineNumberNode(lineNumberState))
        @oldTileState.lineNumbers[id] = _.clone(lineNumberState)

    if newLineNumberIds?
      node = @domNode
      for id, i in newLineNumberIds
        lineNumberNode = newLineNumberNodes[i]
        @lineNumberNodesById[id] = lineNumberNode
        node.appendChild(lineNumberNode)

    return

  buildLineNumberNode: (lineNumberState) ->
    {screenRow, bufferRow, softWrapped, top, decorationClasses, zIndex} = lineNumberState

    className = @buildLineNumberClassName(lineNumberState)
    lineNumberNode = @domElementPool.build("div", className)
    lineNumberNode.dataset.screenRow = screenRow
    lineNumberNode.dataset.bufferRow = bufferRow

    if screenRow?
      lineNumberNode.style.position = "absolute"
      lineNumberNode.style.top = top + "px"
      lineNumberNode.style.zIndex = zIndex
    else
      lineNumberNode.style.visibility = "hidden"

    @appendLineNumberInnerNodes(bufferRow, softWrapped, lineNumberNode)
    lineNumberNode

  appendLineNumberInnerNodes: (bufferRow, softWrapped, lineNumberNode) ->
    {maxLineNumberDigits} = @newState

    if softWrapped
      lineNumber = "•"
    else
      lineNumber = (bufferRow + 1).toString()

    padding = _.multiplyString("\u00a0", maxLineNumberDigits - lineNumber.length)
    iconRight = @domElementPool.build("div", "icon-right")

    lineNumberNode.innerText = padding + lineNumber
    lineNumberNode.appendChild(iconRight)

  updateLineNumberNode: (lineNumberId, newLineNumberState) ->
    oldLineNumberState = @oldTileState.lineNumbers[lineNumberId]
    node = @lineNumberNodesById[lineNumberId]

    unless oldLineNumberState.foldable is newLineNumberState.foldable and _.isEqual(oldLineNumberState.decorationClasses, newLineNumberState.decorationClasses)
      node.className = @buildLineNumberClassName(newLineNumberState)
      oldLineNumberState.foldable = newLineNumberState.foldable
      oldLineNumberState.decorationClasses = _.clone(newLineNumberState.decorationClasses)

    unless oldLineNumberState.top is newLineNumberState.top
      node.style.top = newLineNumberState.top + 'px'
      node.dataset.screenRow = newLineNumberState.screenRow
      oldLineNumberState.top = newLineNumberState.top
      oldLineNumberState.screenRow = newLineNumberState.screenRow

    unless oldLineNumberState.zIndex is newLineNumberState.zIndex
      node.style.zIndex = newLineNumberState.zIndex
      oldLineNumberState.zIndex = newLineNumberState.zIndex

  buildLineNumberClassName: ({bufferRow, foldable, decorationClasses, softWrapped}) ->
    className = "line-number line-number-#{bufferRow}"
    className += " " + decorationClasses.join(' ') if decorationClasses?
    className += " foldable" if foldable and not softWrapped
    className

  lineNumberNodeForScreenRow: (screenRow) ->
    for id, lineNumberState of @oldTileState.lineNumbers
      if lineNumberState.screenRow is screenRow
        return @lineNumberNodesById[id]
    null
