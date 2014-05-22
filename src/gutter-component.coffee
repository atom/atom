React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'

WrapperDiv = document.createElement('div')

module.exports =
GutterComponent = React.createClass
  displayName: 'GutterComponent'
  mixins: [SubscriberMixin]

  lastMeasuredWidth: null
  wrapCountsByScreenRow: null

  render: ->
    {scrollHeight, scrollTop} = @props

    style =
      height: scrollHeight
      WebkitTransform: "translate3d(0px, #{-scrollTop}px, 0px)"

    div className: 'gutter',
      div className: 'line-numbers', ref: 'lineNumbers', style: style,
        @renderDummyLineNode()
        @renderLineNumbers() if @isMounted()

  renderDummyLineNode: ->
    {editor, renderedRowRange, maxLineNumberDigits} = @props
    bufferRow = editor.getLastBufferRow()
    key = 'dummy'

    LineNumberComponent({key, bufferRow, maxLineNumberDigits})

  renderLineNumbers: ->
    {editor, renderedRowRange, maxLineNumberDigits, lineHeightInPixels, mouseWheelScreenRow} = @props
    [startRow, endRow] = renderedRowRange

    lastBufferRow = null
    wrapCount = 0

    wrapCountsByScreenRow = {}
    lineNumberComponents =
      for bufferRow, i in editor.bufferRowsForScreenRows(startRow, endRow - 1)
        if bufferRow is lastBufferRow
          softWrapped = true
          key = "#{bufferRow}-#{++wrapCount}"
        else
          softWrapped = false
          key = bufferRow.toString()
          lastBufferRow = bufferRow
          wrapCount = 0

        screenRow = startRow + i
        wrapCountsByScreenRow[screenRow] = wrapCount
        LineNumberComponent({key, bufferRow, screenRow, softWrapped, maxLineNumberDigits, lineHeightInPixels})

    # Preserve the mouse wheel target's screen row if it exists
    if mouseWheelScreenRow? and not (startRow <= mouseWheelScreenRow < endRow)
      screenRow = mouseWheelScreenRow
      bufferRow = editor.bufferRowForScreenRow(screenRow)
      wrapCount = @wrapCountsByScreenRow[screenRow]
      wrapCountsByScreenRow[screenRow] = wrapCount
      if softWrapped = (wrapCount > 0)
        key = "#{bufferRow}-#{wrapCount}"
      else
        key = bufferRow.toString()

      lineNumberComponents.push(LineNumberComponent({
        key, bufferRow, screenRow, screenRowOverride: endRow, softWrapped,
        maxLineNumberDigits, lineHeightInPixels
      }))

    @wrapCountsByScreenRow = wrapCountsByScreenRow
    lineNumberComponents

  # Only update the gutter if the visible row range has changed or if a
  # non-zero-delta change to the screen lines has occurred within the current
  # visible row range.
  shouldComponentUpdate: (newProps) ->
    return true unless isEqualForProperties(newProps, @props, 'renderedRowRange', 'scrollTop', 'lineHeightInPixels', 'fontSize', 'maxLineNumberDigits', 'mouseWheelScreenRow')

    {renderedRowRange, pendingChanges} = newProps
    for change in pendingChanges when Math.abs(change.screenDelta) > 0 or Math.abs(change.bufferDelta) > 0
      return true unless change.end <= renderedRowRange.start or renderedRowRange.end <= change.start

    false

  componentDidUpdate: (oldProps) ->
    @measureWidth() unless @lastMeasuredWidth? and isEqualForProperties(oldProps, @props, 'maxLineNumberDigits', 'fontSize', 'fontFamily')

  measureWidth: ->
    lineNumberNode = @refs.lineNumbers.getDOMNode().firstChild
    width = lineNumberNode.offsetWidth
    if width isnt @lastMeasuredWidth
      @props.onWidthChanged(@lastMeasuredWidth = width)

  lineNumberNodeForScreenRow: (screenRow) ->
    {renderedRowRange} = @props
    [startRow, endRow] = renderedRowRange

    unless startRow <= screenRow < endRow
      throw new Error("Requested screenRow #{screenRow} is not currently rendered")

    @refs.lineNumbers.getDOMNode().children[screenRow - startRow + 1]

LineNumberComponent = React.createClass
  displayName: 'LineNumberComponent'

  innerHTML: null

  render: ->
    {screenRow, screenRowOverride, lineHeightInPixels} = @props

    if screenRow?
      style =
        position: 'absolute'
        top: (screenRowOverride ? screenRow) * lineHeightInPixels
    else
      style =
        visibility: 'hidden'

    @innerHTML ?= @buildInnerHTML()

    div {
      className: 'line-number'
      'data-screen-row': screenRow
      style
      dangerouslySetInnerHTML: {__html: @innerHTML}
    }

  buildInnerHTML: ->
    {bufferRow, softWrapped, maxLineNumberDigits} = @props

    if softWrapped
      lineNumber = "•"
    else
      lineNumber = (bufferRow + 1).toString()

    padding = multiplyString('&nbsp;', maxLineNumberDigits - lineNumber.length)
    iconHTML = '<div class="icon-right"></div>'
    padding + lineNumber + iconHTML

    if softWrapped
      lineNumber = "•"
    else
      lineNumber = (bufferRow + 1).toString()

    padding = multiplyString('&nbsp;', maxLineNumberDigits - lineNumber.length)
    iconHTML = '<div class="icon-right"></div>'
    padding + lineNumber + iconHTML

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'screenRow', 'lineHeightInPixels', 'maxLineNumberDigits')

  componentWillUpdate: (newProps) ->
    @innerHTML = null unless newProps.maxLineNumberDigits is @props.maxLineNumberDigits
