_ = require 'underscore-plus'
WrapperDiv = document.createElement('div')

module.exports =
class LineNumbersTileComponent
  @createDummy: ->
    new LineNumbersTileComponent({id: -1})

  constructor: ({@id}) ->
    @lineNumberNodesById = {}
    @domNode = document.createElement("div")
    @domNode.classList.add("tile")
    @domNode.style.position = "absolute"
    @domNode.style.display = "block"
    @domNode.style.top = 0 # Cover the space occupied by a dummy lineNumber

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
      node.remove() for id, node of @lineNumberNodesById
      @oldState.tiles[@id] = {lineNumbers: {}}
      @oldTileState = @oldState.tiles[@id]
      @lineNumberNodesById = {}
      @oldState.maxLineNumberDigits = @newState.maxLineNumberDigits

    @updateLineNumbers()

  updateLineNumbers: ->
    newLineNumberIds = null
    newLineNumbersHTML = null

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
        newLineNumbersHTML ?= ""
        newLineNumberIds.push(id)
        newLineNumbersHTML += @buildLineNumberHTML(lineNumberState)
        @oldTileState.lineNumbers[id] = _.clone(lineNumberState)

    if newLineNumberIds?
      WrapperDiv.innerHTML = newLineNumbersHTML
      newLineNumberNodes = _.toArray(WrapperDiv.children)

      node = @domNode
      for id, i in newLineNumberIds
        lineNumberNode = newLineNumberNodes[i]
        @lineNumberNodesById[id] = lineNumberNode
        node.appendChild(lineNumberNode)

    return

  buildLineNumberHTML: (lineNumberState) ->
    {screenRow, bufferRow, softWrapped, top, decorationClasses, zIndex} = lineNumberState
    if screenRow?
      style = "position: absolute; top: #{top}px; z-index: #{zIndex};"
    else
      style = "visibility: hidden;"
    className = @buildLineNumberClassName(lineNumberState)
    innerHTML = @buildLineNumberInnerHTML(bufferRow, softWrapped)

    "<div class=\"#{className}\" style=\"#{style}\" data-buffer-row=\"#{bufferRow}\" data-screen-row=\"#{screenRow}\">#{innerHTML}</div>"

  buildLineNumberInnerHTML: (bufferRow, softWrapped) ->
    {maxLineNumberDigits} = @newState

    if softWrapped
      lineNumber = "•"
    else
      lineNumber = (bufferRow + 1).toString()

    padding = _.multiplyString('&nbsp;', maxLineNumberDigits - lineNumber.length)
    iconHTML = '<div class="icon-right"></div>'
    padding + lineNumber + iconHTML

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
