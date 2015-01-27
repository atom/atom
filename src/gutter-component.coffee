_ = require 'underscore-plus'
React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
Decoration = require './decoration'
SubscriberMixin = require './subscriber-mixin'

WrapperDiv = document.createElement('div')

module.exports =
GutterComponent = React.createClass
  displayName: 'GutterComponent'
  mixins: [SubscriberMixin]

  dummyLineNumberNode: null
  measuredWidth: null

  render: ->
    {presenter, backgroundColor, gutterBackgroundColor} = @props

    if gutterBackgroundColor isnt 'rbga(0, 0, 0, 0)'
      backgroundColor = gutterBackgroundColor

    div className: 'gutter',
      div className: 'line-numbers', ref: 'lineNumbers', style:
        height: presenter?.state.scrollHeight
        WebkitTransform: @getTransform() if presenter?
        backgroundColor: backgroundColor

  getTransform: ->
    {presenter, useHardwareAcceleration} = @props
    {scrollTop} = presenter.state

    if useHardwareAcceleration
      "translate3d(0px, #{-scrollTop}px, 0px)"
    else
      "translate(0px, #{-scrollTop}px)"

  componentWillMount: ->
    @lineNumberNodesById = {}
    @lineNumberIdsByScreenRow = {}
    @screenRowsByLineNumberId = {}
    @renderedDecorationsByLineNumberId = {}

  componentDidMount: ->
    @appendDummyLineNumber()
    @updateLineNumbers() if @props.presenter?

    node = @getDOMNode()
    node.addEventListener 'click', @onClick
    node.addEventListener 'mousedown', @onMouseDown

  componentDidUpdate: (oldProps) ->
    return unless @props.presenter?

    unless isEqualForProperties(oldProps, @props, 'maxLineNumberDigits')
      @updateDummyLineNumber()
      @removeLineNumberNodes()

    @clearScreenRowCaches() unless oldProps.lineHeightInPixels is @props.lineHeightInPixels
    @updateLineNumbers()

  clearScreenRowCaches: ->
    @lineNumberIdsByScreenRow = {}
    @screenRowsByLineNumberId = {}

  # This dummy line number element holds the gutter to the appropriate width,
  # since the real line numbers are absolutely positioned for performance reasons.
  appendDummyLineNumber: ->
    {maxLineNumberDigits} = @props
    WrapperDiv.innerHTML = @buildLineNumberHTML(-1, false, maxLineNumberDigits)
    @dummyLineNumberNode = WrapperDiv.children[0]
    @refs.lineNumbers.getDOMNode().appendChild(@dummyLineNumberNode)

  updateDummyLineNumber: ->
    @dummyLineNumberNode.innerHTML = @buildLineNumberInnerHTML(0, false, @props.maxLineNumberDigits)

  updateLineNumbers: ->
    lineNumberIdsToPreserve = @appendOrUpdateVisibleLineNumberNodes()
    @removeLineNumberNodes(lineNumberIdsToPreserve)

  appendOrUpdateVisibleLineNumberNodes: ->
    {editor, renderedRowRange, scrollTop, maxLineNumberDigits, lineDecorations} = @props
    [startRow, endRow] = renderedRowRange

    newLineNumberIds = null
    newLineNumbersHTML = null
    visibleLineNumberIds = new Set

    wrapCount = 0
    for bufferRow, index in editor.bufferRowsForScreenRows(startRow, endRow - 1)
      screenRow = startRow + index

      if bufferRow is lastBufferRow
        id = "#{bufferRow}-#{wrapCount++}"
      else
        id = bufferRow.toString()
        lastBufferRow = bufferRow
        wrapCount = 0

      visibleLineNumberIds.add(id)

      if @hasLineNumberNode(id)
        @updateLineNumberNode(id, bufferRow, screenRow, wrapCount > 0)
      else
        newLineNumberIds ?= []
        newLineNumbersHTML ?= ""
        newLineNumberIds.push(id)
        newLineNumbersHTML += @buildLineNumberHTML(bufferRow, wrapCount > 0, maxLineNumberDigits, screenRow)
        @screenRowsByLineNumberId[id] = screenRow
        @lineNumberIdsByScreenRow[screenRow] = id

      @renderedDecorationsByLineNumberId[id] = lineDecorations[screenRow]

    if newLineNumberIds?
      WrapperDiv.innerHTML = newLineNumbersHTML
      newLineNumberNodes = toArray(WrapperDiv.children)

      node = @refs.lineNumbers.getDOMNode()
      for lineNumberId, i in newLineNumberIds
        lineNumberNode = newLineNumberNodes[i]
        @lineNumberNodesById[lineNumberId] = lineNumberNode
        node.appendChild(lineNumberNode)

    visibleLineNumberIds

  removeLineNumberNodes: (lineNumberIdsToPreserve) ->
    {mouseWheelScreenRow} = @props
    node = @refs.lineNumbers.getDOMNode()
    for lineNumberId, lineNumberNode of @lineNumberNodesById when not lineNumberIdsToPreserve?.has(lineNumberId)
      screenRow = @screenRowsByLineNumberId[lineNumberId]
      if not screenRow? or screenRow isnt mouseWheelScreenRow
        delete @lineNumberNodesById[lineNumberId]
        delete @lineNumberIdsByScreenRow[screenRow] if @lineNumberIdsByScreenRow[screenRow] is lineNumberId
        delete @screenRowsByLineNumberId[lineNumberId]
        delete @renderedDecorationsByLineNumberId[lineNumberId]
        node.removeChild(lineNumberNode)

  buildLineNumberHTML: (bufferRow, softWrapped, maxLineNumberDigits, screenRow) ->
    {editor, lineHeightInPixels, lineDecorations} = @props
    if screenRow?
      style = "position: absolute; top: #{screenRow * lineHeightInPixels}px;"
    else
      style = "visibility: hidden;"
    innerHTML = @buildLineNumberInnerHTML(bufferRow, softWrapped, maxLineNumberDigits)

    classes = ''
    if lineDecorations? and decorations = lineDecorations[screenRow]
      for id, decoration of decorations
        if Decoration.isType(decoration, 'line-number')
          classes += decoration.class + ' '

    classes += "foldable " if bufferRow >= 0 and editor.isFoldableAtBufferRow(bufferRow)
    classes += "line-number line-number-#{bufferRow}"

    "<div class=\"#{classes}\" style=\"#{style}\" data-buffer-row=\"#{bufferRow}\" data-screen-row=\"#{screenRow}\">#{innerHTML}</div>"

  buildLineNumberInnerHTML: (bufferRow, softWrapped, maxLineNumberDigits) ->
    if softWrapped
      lineNumber = "•"
    else
      lineNumber = (bufferRow + 1).toString()

    padding = multiplyString('&nbsp;', maxLineNumberDigits - lineNumber.length)
    iconHTML = '<div class="icon-right"></div>'
    padding + lineNumber + iconHTML

  updateLineNumberNode: (lineNumberId, bufferRow, screenRow, softWrapped) ->
    {editor, lineDecorations} = @props
    node = @lineNumberNodesById[lineNumberId]

    if editor.isFoldableAtBufferRow(bufferRow)
      node.classList.add('foldable')
    else
      node.classList.remove('foldable')

    decorations = lineDecorations[screenRow]
    previousDecorations = @renderedDecorationsByLineNumberId[lineNumberId]

    if previousDecorations?
      for id, decoration of previousDecorations
        if Decoration.isType(decoration, 'line-number') and not @hasDecoration(decorations, decoration)
          node.classList.remove(decoration.class)

    if decorations?
      for id, decoration of decorations
        if Decoration.isType(decoration, 'line-number') and not @hasDecoration(previousDecorations, decoration)
          node.classList.add(decoration.class)

    unless @screenRowsByLineNumberId[lineNumberId] is screenRow
      {lineHeightInPixels} = @props
      node.style.top = screenRow * lineHeightInPixels + 'px'
      node.dataset.screenRow = screenRow
      @screenRowsByLineNumberId[lineNumberId] = screenRow
      @lineNumberIdsByScreenRow[screenRow] = lineNumberId

  hasDecoration: (decorations, decoration) ->
    decorations? and decorations[decoration.id] is decoration

  hasLineNumberNode: (lineNumberId) ->
    @lineNumberNodesById.hasOwnProperty(lineNumberId)

  lineNumberNodeForScreenRow: (screenRow) ->
    @lineNumberNodesById[@lineNumberIdsByScreenRow[screenRow]]

  onMouseDown: (event) ->
    {editor} = @props
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
