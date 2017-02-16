_ = require 'underscore-plus'

module.exports =
class LineNumbersTileComponent
  @createDummy: ->
    new LineNumbersTileComponent({id: -1})

  constructor: ({@id}) ->
    @lineNumberNodesById = {}
    @domNode = document.createElement('div')
    @domNode.style.position = "absolute"
    @domNode.style.display = "block"
    @domNode.style.top = 0 # Cover the space occupied by a dummy lineNumber

  destroy: ->
    @domNode.remove()

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
        node.remove()

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
        @lineNumberNodesById[id].remove()
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

    return unless newLineNumberIds?

    for id, i in newLineNumberIds
      lineNumberNode = newLineNumberNodes[i]
      @lineNumberNodesById[id] = lineNumberNode
      if nextNode = @findNodeNextTo(lineNumberNode)
        @domNode.insertBefore(lineNumberNode, nextNode)
      else
        @domNode.appendChild(lineNumberNode)

  findNodeNextTo: (node) ->
    for nextNode in @domNode.children
      return nextNode if @screenRowForNode(node) < @screenRowForNode(nextNode)
    return

  screenRowForNode: (node) -> parseInt(node.dataset.screenRow)

  buildLineNumberNode: (lineNumberState) ->
    {screenRow, bufferRow, softWrapped, blockDecorationsHeight} = lineNumberState

    className = @buildLineNumberClassName(lineNumberState)
    lineNumberNode = document.createElement('div')
    lineNumberNode.className = className
    lineNumberNode.dataset.screenRow = screenRow
    lineNumberNode.dataset.bufferRow = bufferRow
    lineNumberNode.style.marginTop = blockDecorationsHeight + "px"

    @setLineNumberInnerNodes(bufferRow, softWrapped, lineNumberNode)
    lineNumberNode

  setLineNumberInnerNodes: (bufferRow, softWrapped, lineNumberNode) ->
    while lineNumberNode.firstChild
      lineNumberNode.removeChild(lineNumberNode.firstChild)

    {maxLineNumberDigits} = @newState

    if softWrapped
      lineNumber = "•"
    else
      lineNumber = (bufferRow + 1).toString()
    padding = _.multiplyString("\u00a0", maxLineNumberDigits - lineNumber.length)

    textNode = document.createTextNode(padding + lineNumber)
    iconRight = document.createElement('div')
    iconRight.className = 'icon-right'

    lineNumberNode.appendChild(textNode)
    lineNumberNode.appendChild(iconRight)

  updateLineNumberNode: (lineNumberId, newLineNumberState) ->
    oldLineNumberState = @oldTileState.lineNumbers[lineNumberId]
    node = @lineNumberNodesById[lineNumberId]

    unless oldLineNumberState.foldable is newLineNumberState.foldable and _.isEqual(oldLineNumberState.decorationClasses, newLineNumberState.decorationClasses)
      node.className = @buildLineNumberClassName(newLineNumberState)
      oldLineNumberState.foldable = newLineNumberState.foldable
      oldLineNumberState.decorationClasses = _.clone(newLineNumberState.decorationClasses)

    unless oldLineNumberState.screenRow is newLineNumberState.screenRow and oldLineNumberState.bufferRow is newLineNumberState.bufferRow
      @setLineNumberInnerNodes(newLineNumberState.bufferRow, newLineNumberState.softWrapped, node)
      node.dataset.screenRow = newLineNumberState.screenRow
      node.dataset.bufferRow = newLineNumberState.bufferRow
      oldLineNumberState.screenRow = newLineNumberState.screenRow
      oldLineNumberState.bufferRow = newLineNumberState.bufferRow

    unless oldLineNumberState.blockDecorationsHeight is newLineNumberState.blockDecorationsHeight
      node.style.marginTop = newLineNumberState.blockDecorationsHeight + "px"
      oldLineNumberState.blockDecorationsHeight = newLineNumberState.blockDecorationsHeight

  buildLineNumberClassName: ({bufferRow, foldable, decorationClasses, softWrapped}) ->
    className = "line-number"
    className += " " + decorationClasses.join(' ') if decorationClasses?
    className += " foldable" if foldable and not softWrapped
    className

  lineNumberNodeForScreenRow: (screenRow) ->
    for id, lineNumberState of @oldTileState.lineNumbers
      if lineNumberState.screenRow is screenRow
        return @lineNumberNodesById[id]
    null
