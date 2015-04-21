_ = require 'underscore-plus'
{setDimensionsAndBackground} = require './gutter-component-helpers'

WrapperDiv = document.createElement('div')

module.exports =
class LineNumberGutterComponent
  dummyLineNumberNode: null

  constructor: ({@onMouseDown, @editor, @gutter}) ->
    @lineNumberNodesById = {}
    @visible = true

    @domNode = atom.views.getView(@gutter)
    @lineNumbersNode = @domNode.firstChild

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

  updateSync: (state) ->
    @newState = state.gutters.lineNumberGutter
    @oldState ?= {lineNumbers: {}}

    @appendDummyLineNumber() unless @dummyLineNumberNode?

    newDimensionsAndBackgroundState = state.gutters
    setDimensionsAndBackground(@oldState, newDimensionsAndBackgroundState, @lineNumbersNode)

    if @newState.maxLineNumberDigits isnt @oldState.maxLineNumberDigits
      @updateDummyLineNumber()
      node.remove() for id, node of @lineNumberNodesById
      @oldState = {maxLineNumberDigits: @newState.maxLineNumberDigits, lineNumbers: {}}
      @lineNumberNodesById = {}

    @updateLineNumbers()

  ###
  Section: Private Methods
  ###

  # This dummy line number element holds the gutter to the appropriate width,
  # since the real line numbers are absolutely positioned for performance reasons.
  appendDummyLineNumber: ->
    WrapperDiv.innerHTML = @buildLineNumberHTML({bufferRow: -1})
    @dummyLineNumberNode = WrapperDiv.children[0]
    @lineNumbersNode.appendChild(@dummyLineNumberNode)

  updateDummyLineNumber: ->
    @dummyLineNumberNode.innerHTML = @buildLineNumberInnerHTML(0, false)

  updateLineNumbers: ->
    newLineNumberIds = null
    newLineNumbersHTML = null

    for id, lineNumberState of @newState.lineNumbers
      if @oldState.lineNumbers.hasOwnProperty(id)
        @updateLineNumberNode(id, lineNumberState)
      else
        newLineNumberIds ?= []
        newLineNumbersHTML ?= ""
        newLineNumberIds.push(id)
        newLineNumbersHTML += @buildLineNumberHTML(lineNumberState)
        @oldState.lineNumbers[id] = _.clone(lineNumberState)

    if newLineNumberIds?
      WrapperDiv.innerHTML = newLineNumbersHTML
      newLineNumberNodes = _.toArray(WrapperDiv.children)

      node = @lineNumbersNode
      for id, i in newLineNumberIds
        lineNumberNode = newLineNumberNodes[i]
        @lineNumberNodesById[id] = lineNumberNode
        node.appendChild(lineNumberNode)

    for id, lineNumberState of @oldState.lineNumbers
      unless @newState.lineNumbers.hasOwnProperty(id)
        @lineNumberNodesById[id].remove()
        delete @lineNumberNodesById[id]
        delete @oldState.lineNumbers[id]

    return

  buildLineNumberHTML: (lineNumberState) ->
    {screenRow, bufferRow, softWrapped, top, decorationClasses} = lineNumberState
    if screenRow?
      style = "position: absolute; top: #{top}px;"
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
    oldLineNumberState = @oldState.lineNumbers[lineNumberId]
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

  buildLineNumberClassName: ({bufferRow, foldable, decorationClasses, softWrapped}) ->
    className = "line-number line-number-#{bufferRow}"
    className += " " + decorationClasses.join(' ') if decorationClasses?
    className += " foldable" if foldable and not softWrapped
    className

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
