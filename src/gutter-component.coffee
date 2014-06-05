React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'

WrapperDiv = document.createElement('div')

module.exports =
GutterComponent = React.createClass
  displayName: 'GutterComponent'
  mixins: [SubscriberMixin]
  decorationType: 'gutter'
  decorationRenderDelay: 100

  dummyLineNumberNode: null

  render: ->
    {scrollHeight, scrollTop} = @props

    div className: 'gutter',
      div className: 'line-numbers', ref: 'lineNumbers', style:
        height: scrollHeight
        WebkitTransform: "translate3d(0px, #{-scrollTop}px, 0px)"

  componentWillMount: ->
    @lineNumberNodesById = {}
    @lineNumberIdsByScreenRow = {}
    @screenRowsByLineNumberId = {}
    @decoratorUpdates = {}

  componentDidMount: ->
    @appendDummyLineNumber()
    @subscribeToEditor()

  componentWillUnmount: ->
    @unsubscribe()

  subscribeToEditor: ->
    @subscribe @props.editor, 'decoration-changed', @onDecorationChanged

  # Only update the gutter if the visible row range has changed or if a
  # non-zero-delta change to the screen lines has occurred within the current
  # visible row range.
  shouldComponentUpdate: (newProps) ->
    return true unless isEqualForProperties(newProps, @props,
      'renderedRowRange', 'scrollTop', 'lineHeightInPixels', 'mouseWheelScreenRow'
    )

    {renderedRowRange, pendingChanges} = newProps
    for change in pendingChanges when Math.abs(change.screenDelta) > 0 or Math.abs(change.bufferDelta) > 0
      return true unless change.end <= renderedRowRange.start or renderedRowRange.end <= change.start

    false

  componentDidUpdate: (oldProps) ->
    unless oldProps.maxLineNumberDigits is @props.maxLineNumberDigits
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
    WrapperDiv.innerHTML = @buildLineNumberHTML(0, false, maxLineNumberDigits)
    @dummyLineNumberNode = WrapperDiv.children[0]
    @refs.lineNumbers.getDOMNode().appendChild(@dummyLineNumberNode)

  updateDummyLineNumber: ->
    @dummyLineNumberNode.innerHTML = @buildLineNumberInnerHTML(0, false, @props.maxLineNumberDigits)

  updateLineNumbers: ->
    lineNumberIdsToPreserve = @appendOrUpdateVisibleLineNumberNodes()
    @removeLineNumberNodes(lineNumberIdsToPreserve)

  appendOrUpdateVisibleLineNumberNodes: ->
    {editor, renderedRowRange, scrollTop, maxLineNumberDigits} = @props
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

    if newLineNumberIds?
      WrapperDiv.innerHTML = newLineNumbersHTML
      newLineNumberNodes = toArray(WrapperDiv.children)

      node = @refs.lineNumbers.getDOMNode()
      for lineNumberId, i in newLineNumberIds
        lineNumberNode = newLineNumberNodes[i]
        @lineNumberNodesById[lineNumberId] = lineNumberNode
        node.appendChild(lineNumberNode)

    @decoratorUpdates = {}
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

  buildLineNumberHTML: (bufferRow, softWrapped, maxLineNumberDigits, screenRow) ->
    if screenRow?
      {lineHeightInPixels} = @props
      style = "position: absolute; top: #{screenRow * lineHeightInPixels}px;"
    else
      style = "visibility: hidden;"
    innerHTML = @buildLineNumberInnerHTML(bufferRow, softWrapped, maxLineNumberDigits)

    classes = ['line-number']
    classes.push 'foldable' if not softWrapped and @props.editor.isFoldableAtBufferRow(bufferRow)
    classes.push 'folded' if @props.editor.isFoldedAtBufferRow(bufferRow)

    decorations = @props.editor.decorationsForBufferRow(bufferRow, @decorationType)
    for decoration in decorations
      classes.push(decoration.class) if not softWrapped or softWrapped and decoration.softWrap

    "<div class=\"#{classes.join(' ')}\" style=\"#{style}\" data-buffer-row=\"#{bufferRow}\" data-screen-row=\"#{screenRow}\">#{innerHTML}</div>"

  buildLineNumberInnerHTML: (bufferRow, softWrapped, maxLineNumberDigits) ->
    if softWrapped
      lineNumber = "•"
    else
      lineNumber = (bufferRow + 1).toString()

    padding = multiplyString('&nbsp;', maxLineNumberDigits - lineNumber.length)
    iconHTML = '<div class="icon-right"></div>'
    padding + lineNumber + iconHTML

  updateLineNumberNode: (lineNumberId, bufferRow, screenRow, softWrapped) ->
    node = @lineNumberNodesById[lineNumberId]

    @toggleClass node, 'foldable', not softWrapped and @props.editor.isFoldableAtBufferRow(bufferRow)
    @toggleClass node, 'folded', @props.editor.isFoldedAtBufferRow(bufferRow)

    if @decoratorUpdates[bufferRow]?
      for change in @decoratorUpdates[bufferRow]
        if change.action == 'add' and (not softWrapped or softWrapped and change.decoration.softWrap)
          node.classList.add(change.decoration.class)
        else if change.action == 'remove'
          node.classList.remove(change.decoration.class)

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

  toggleClass: (node, klass, condition) ->
    if condition then node.classList.add(klass) else node.classList.remove(klass)

  onDecorationChanged: (change) ->
    if change.decoration.type == @decorationType
      @decoratorUpdates[change.bufferRow] ?= []
      @decoratorUpdates[change.bufferRow].push change
      @renderDecorations()

  renderDecorations: ->
    clearTimeout(@decorationRenderTimeout) if @decorationRenderTimeout
    render = =>
      @forceUpdate()
      @decorationRenderTimeout = null
    @decorationRenderTimeout = setTimeout(render, @decorationRenderDelay)
