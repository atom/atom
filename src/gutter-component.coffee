_ = require 'underscore-plus'
React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'

WrapperDiv = document.createElement('div')

module.exports =
GutterComponent = React.createClass
  displayName: 'GutterComponent'
  mixins: [SubscriberMixin]

  dummyLineNumberNode: null
  measuredWidth: null

  render: ->
    {scrollHeight, scrollViewHeight, scrollTop} = @props

    div className: 'gutter', onClick: @onClick,
      # The line-numbers div must have the 'editor-colors' class so it has an
      # opaque background to avoid sub-pixel anti-aliasing problems on the GPU
      div className: 'gutter line-numbers editor-colors', ref: 'lineNumbers', style:
        height: Math.max(scrollHeight, scrollViewHeight)
        WebkitTransform: "translate3d(0px, #{-scrollTop}px, 0px)"

  componentWillMount: ->
    @lineNumberNodesById = {}
    @lineNumberIdsByScreenRow = {}
    @screenRowsByLineNumberId = {}
    @previousDecorations = {}

  componentDidMount: ->
    @appendDummyLineNumber()

  # Only update the gutter if the visible row range has changed or if a
  # non-zero-delta change to the screen lines has occurred within the current
  # visible row range.
  shouldComponentUpdate: (newProps) ->
    return true unless isEqualForProperties(newProps, @props,
      'renderedRowRange', 'scrollTop', 'lineHeightInPixels', 'mouseWheelScreenRow', 'lineDecorations',
      'scrollViewHeight'
    )

    {renderedRowRange, pendingChanges, lineDecorations} = newProps
    for change in pendingChanges when Math.abs(change.screenDelta) > 0 or Math.abs(change.bufferDelta) > 0
      return true unless change.end <= renderedRowRange.start or renderedRowRange.end <= change.start

    false

  componentDidUpdate: (oldProps) ->
    unless isEqualForProperties(oldProps, @props, 'maxLineNumberDigits')
      @updateDummyLineNumber()
      @removeLineNumberNodes()

    unless isEqualForProperties(oldProps, @props, 'maxLineNumberDigits', 'defaultCharWidth')
      @measureWidth()

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
        @updateLineNumberNode(id, bufferRow, screenRow, wrapCount > 0, lineDecorations[screenRow])
      else
        newLineNumberIds ?= []
        newLineNumbersHTML ?= ""
        newLineNumberIds.push(id)
        newLineNumbersHTML += @buildLineNumberHTML(bufferRow, wrapCount > 0, maxLineNumberDigits, screenRow, lineDecorations[screenRow])
        @screenRowsByLineNumberId[id] = screenRow
        @lineNumberIdsByScreenRow[screenRow] = id

    if newLineNumberIds?
      WrapperDiv.innerHTML = newLineNumbersHTML
      newLineNumberNodes = toArray(WrapperDiv.children)

      node = @refs.lineNumbers.getDOMNode()
      for lineNumberId, i in newLineNumberIds
        lineNumberNode = newLineNumberNodes[i]
        @lineNumberNodesById[lineNumberId] = lineNumberNode
        node.appendChild(lineNumberNode)

    @previousDecorations = lineDecorations
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
        node.removeChild(lineNumberNode)

  buildLineNumberHTML: (bufferRow, softWrapped, maxLineNumberDigits, screenRow, decorations) ->
    {editor, lineHeightInPixels} = @props
    if screenRow?
      style = "position: absolute; top: #{screenRow * lineHeightInPixels}px;"
    else
      style = "visibility: hidden;"
    innerHTML = @buildLineNumberInnerHTML(bufferRow, softWrapped, maxLineNumberDigits)

    classes = ''
    if decorations?
      for decoration in decorations
        if editor.decorationMatchesType(decoration, 'gutter')
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

  updateLineNumberNode: (lineNumberId, bufferRow, screenRow, softWrapped, decorations) ->
    {editor} = @props
    node = @lineNumberNodesById[lineNumberId]
    previousDecorations = @previousDecorations[screenRow]

    if editor.isFoldableAtBufferRow(bufferRow)
      node.classList.add('foldable')
    else
      node.classList.remove('foldable')

    if previousDecorations?
      for decoration in previousDecorations
        node.classList.remove(decoration.class) if editor.decorationMatchesType(decoration, 'gutter') and not contains(decorations, decoration)

    if decorations?
      for decoration in decorations
        if editor.decorationMatchesType(decoration, 'gutter') and not contains(previousDecorations, decoration)
          node.classList.add(decoration.class)

    unless @screenRowsByLineNumberId[lineNumberId] is screenRow
      {lineHeightInPixels} = @props
      node.style.top = screenRow * lineHeightInPixels + 'px'
      node.dataset.screenRow = screenRow
      @screenRowsByLineNumberId[lineNumberId] = screenRow
      @lineNumberIdsByScreenRow[screenRow] = lineNumberId

  hasLineNumberNode: (lineNumberId) ->
    @lineNumberNodesById.hasOwnProperty(lineNumberId)

  lineNumberNodeForScreenRow: (screenRow) ->
    @lineNumberNodesById[@lineNumberIdsByScreenRow[screenRow]]

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

  measureWidth: ->
    width = @getDOMNode().offsetWidth
    unless width is @measuredWidth
      @measuredWidth = width
      @props.onWidthChanged?(width)

# Created because underscore uses === not _.isEqual, which we need
contains = (array, target) ->
  return false unless array?
  for object in array
    return true if _.isEqual(object, target)
  false
