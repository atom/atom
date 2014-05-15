React = require 'react'
{div} = require 'reactionary'
{isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'

WrapperDiv = document.createElement('div')

module.exports =
GutterComponent = React.createClass
  displayName: 'GutterComponent'
  mixins: [SubscriberMixin]

  lastMeasuredWidth: null

  render: ->
    {width, scrollHeight, scrollTop} = @props

    div className: 'gutter', style: {width},
      div className: 'line-numbers', ref: 'lineNumbers', style:
        height: scrollHeight
        WebkitTransform: "translate3d(0px, #{-scrollTop}px, 0px)"

  componentWillMount: ->
    @lineNumberNodesById = {}
    @lineNumberNodeTopPositions = {}

  # Only update the gutter if the visible row range has changed or if a
  # non-zero-delta change to the screen lines has occurred within the current
  # visible row range.
  shouldComponentUpdate: (newProps) ->
    return true unless isEqualForProperties(newProps, @props, 'visibleRowRange', 'scrollTop', 'lineHeight', 'fontSize')

    {visibleRowRange, pendingChanges} = newProps
    for change in pendingChanges when Math.abs(change.screenDelta) > 0 or Math.abs(change.bufferDelta) > 0
      return true unless change.end <= visibleRowRange.start or visibleRowRange.end <= change.start

    false

  componentDidUpdate: (oldProps) ->
    @updateLineNumbers()
    unless @lastMeasuredWidth? and isEqualForProperties(oldProps, @props, 'maxLineNumberDigits', 'fontSize', 'fontFamily')
      @measureWidth()

  updateLineNumbers: ->
    visibleLineNumberIds = @appendOrUpdateVisibleLineNumberNodes()
    @removeNonVisibleLineNumberNodes(visibleLineNumberIds)

  appendOrUpdateVisibleLineNumberNodes: ->
    {editor, visibleRowRange, scrollTop, lineHeight} = @props
    [startRow, endRow] = visibleRowRange
    startRow = Math.max(0, startRow - 8)
    endRow = Math.min(editor.getLineCount(), endRow + 8)

    maxLineNumberDigits = editor.getLineCount().toString().length
    newLineNumberIds = null
    newLineNumbersHTML = null
    visibleLineNumberIds = new Set

    wrapCount = 0
    for bufferRow, index in editor.bufferRowsForScreenRows(startRow, endRow - 1)
      if bufferRow is lastBufferRow
        id = "#{bufferRow}-#{wrapCount++}"
      else
        id = bufferRow.toString()
        lastBufferRow = bufferRow
        wrapCount = 0

      visibleLineNumberIds.add(id)

      screenRow = startRow + index
      top = screenRow * lineHeight

      if @hasLineNumberNode(id)
        @updateLineNumberNode(id, top)
      else
        newLineNumberIds ?= []
        newLineNumbersHTML ?= ""
        newLineNumberIds.push(id)
        newLineNumbersHTML += @buildLineNumberHTML(bufferRow, wrapCount > 0, maxLineNumberDigits, top)
        @lineNumberNodeTopPositions[id] = top

    if newLineNumberIds?
      WrapperDiv.innerHTML = newLineNumbersHTML
      newLineNumberNodes = toArray(WrapperDiv.children)

      node = @refs.lineNumbers.getDOMNode()
      for lineNumberId, i in newLineNumberIds
        lineNumberNode = newLineNumberNodes[i]
        @lineNumberNodesById[lineNumberId] = lineNumberNode
        node.appendChild(lineNumberNode)

    visibleLineNumberIds

  removeNonVisibleLineNumberNodes: (visibleLineNumberIds) ->
    node = @refs.lineNumbers.getDOMNode()
    for id, lineNumberNode of @lineNumberNodesById when not visibleLineNumberIds.has(id)
      delete @lineNumberNodesById[id]
      delete @lineNumberNodeTopPositions[id]
      node.removeChild(lineNumberNode)

  buildLineNumberHTML: (bufferRow, softWrapped, maxLineNumberDigits, top) ->
    if softWrapped
      lineNumber = "•"
    else
      lineNumber = (bufferRow + 1).toString()

    padding = multiplyString('&nbsp;', maxLineNumberDigits - lineNumber.length)
    iconHTML = '<div class="icon-right"></div>'
    innerHTML = padding + lineNumber + iconHTML
    translate3d = @buildTranslate3d(top)

    "<div class=\"line-number editor-colors\" style=\"top: #{top}px;\">#{innerHTML}</div>"

  updateLineNumberNode: (lineNumberId, top) ->
    unless @lineNumberNodeTopPositions[lineNumberId] is top
      @lineNumberNodesById[lineNumberId].style.top = top + 'px'
      @lineNumberNodeTopPositions[lineNumberId] = top

  hasLineNumberNode: (lineNumberId) ->
    @lineNumberNodesById.hasOwnProperty(lineNumberId)

  buildTranslate3d: (top) ->
    "translate3d(0px, #{top}px, 0px)"

  measureWidth: ->
    lineNumberNode = @refs.lineNumbers.getDOMNode().firstChild
    # return unless lineNumberNode?

    width = lineNumberNode.offsetWidth
    if width isnt @lastMeasuredWidth
      @props.onWidthChanged(@lastMeasuredWidth = width)
