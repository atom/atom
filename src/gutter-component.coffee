_ = require 'underscore-plus'
React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqual, isEqualForProperties, multiplyString, toArray} = _
Decoration = require './decoration'
SubscriberMixin = require './subscriber-mixin'

WrapperDiv = document.createElement('div')

module.exports =
GutterComponent = React.createClass
  displayName: 'GutterComponent'
  mixins: [SubscriberMixin]

  maxLineNumberDigits: null
  dummyLineNumberNode: null
  measuredWidth: null

  render: ->
    {presenter} = @props
    @newState = presenter.state.gutter
    @oldState ?= {lineNumbers: {}}

    {scrollHeight, backgroundColor} = @newState

    div className: 'gutter',
      div className: 'line-numbers', ref: 'lineNumbers', style:
        height: scrollHeight
        WebkitTransform: @getTransform()
        backgroundColor: backgroundColor

  getTransform: ->
    {useHardwareAcceleration} = @props
    {scrollTop} = @newState

    if useHardwareAcceleration
      "translate3d(0px, #{-scrollTop}px, 0px)"
    else
      "translate(0px, #{-scrollTop}px)"

  componentWillMount: ->
    @lineNumberNodesById = {}

  componentDidMount: ->
    {@maxLineNumberDigits} = @newState
    @appendDummyLineNumber()
    @updateLineNumbers()

    node = @getDOMNode()
    node.addEventListener 'click', @onClick
    node.addEventListener 'mousedown', @onMouseDown

  componentDidUpdate: (oldProps) ->
    {maxLineNumberDigits} = @newState
    unless maxLineNumberDigits is @maxLineNumberDigits
      @maxLineNumberDigits = maxLineNumberDigits
      @updateDummyLineNumber()
      node.remove() for id, node of @lineNumberNodesById
      @oldState = {lineNumbers: {}}
      @lineNumberNodesById = {}

    @updateLineNumbers()

  # This dummy line number element holds the gutter to the appropriate width,
  # since the real line numbers are absolutely positioned for performance reasons.
  appendDummyLineNumber: ->
    WrapperDiv.innerHTML = @buildLineNumberHTML({bufferRow: -1})
    @dummyLineNumberNode = WrapperDiv.children[0]
    @refs.lineNumbers.getDOMNode().appendChild(@dummyLineNumberNode)

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
      newLineNumberNodes = toArray(WrapperDiv.children)

      node = @refs.lineNumbers.getDOMNode()
      for id, i in newLineNumberIds
        lineNumberNode = newLineNumberNodes[i]
        @lineNumberNodesById[id] = lineNumberNode
        node.appendChild(lineNumberNode)

    for id, lineNumberState of @oldState.lineNumbers
      unless @newState.lineNumbers.hasOwnProperty(id)
        @lineNumberNodesById[id].remove()
        delete @lineNumberNodesById[id]
        delete @oldState.lineNumbers[id]

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

    padding = multiplyString('&nbsp;', maxLineNumberDigits - lineNumber.length)
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

  buildLineNumberClassName: ({bufferRow, foldable, decorationClasses}) ->
    className = "line-number line-number-#{bufferRow}"
    className += " " + decorationClasses.join(' ') if decorationClasses?
    className += " foldable" if foldable
    className

  lineNumberNodeForScreenRow: (screenRow) ->
    for id, lineNumberState of @oldState.lineNumbers
      if lineNumberState.screenRow is screenRow
        return @lineNumberNodesById[id]
    null

  onMouseDown: (event) ->
    {target} = event
    lineNumber = target.parentNode

    unless target.classList.contains('icon-right') and lineNumber.classList.contains('foldable')
      @props.onMouseDown(event)

  onClick: (event) ->
    {editor} = @props
    {target} = event
    lineNumber = target.parentNode

    if target.classList.contains('icon-right') and lineNumber.classList.contains('foldable')
      bufferRow = parseInt(lineNumber.getAttribute('data-buffer-row'))
      if lineNumber.classList.contains('folded')
        editor.unfoldBufferRow(bufferRow)
      else
        editor.foldBufferRow(bufferRow)
