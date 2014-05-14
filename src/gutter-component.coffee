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
    {width} = @props

    div className: 'gutter', style: {width},
      div className: 'line-numbers', ref: 'lineNumbers'

  componentWillMount: ->
    @lineNumberNodesById = {}

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
    maxLineNumberDigits = editor.getLineCount().toString().length
    verticalScrollOffset = -scrollTop % lineHeight
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

      top = (index * lineHeight) + verticalScrollOffset

      if @hasLineNumberNode(id)
        @updateLineNumberNode(id, top)
      else
        newLineNumberIds ?= []
        newLineNumbersHTML ?= ""
        newLineNumberIds.push(id)
        newLineNumbersHTML += @buildLineNumberHTML(bufferRow, wrapCount > 0, maxLineNumberDigits, top)

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

    "<div class=\"line-number editor-colors\" style=\"-webkit-transform: #{translate3d};\">#{innerHTML}</div>"

  updateLineNumberNode: (lineNumberId, top) ->
    @lineNumberNodesById[lineNumberId].style['-webkit-transform'] = @buildTranslate3d(top)

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
