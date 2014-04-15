React = require 'react'
{div} = require 'reactionary'
{isEqual, multiplyString} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'

module.exports =
GutterComponent = React.createClass
  displayName: 'GutterComponent'
  mixins: [SubscriberMixin]

  render: ->
    {editor, visibleRowRange} = @props
    [startRow, endRow] = visibleRowRange
    lineHeightInPixels = editor.getLineHeight()
    precedingHeight = startRow * lineHeightInPixels
    followingHeight = (editor.getScreenLineCount() - endRow) * lineHeightInPixels
    maxDigits = editor.getLastBufferRow().toString().length
    style =
      height: editor.getScrollHeight()
      WebkitTransform: "translateY(#{-editor.getScrollTop()}px)"
    wrapCount = 0

    lineNumbers = []
    for bufferRow in @props.editor.bufferRowsForScreenRows(startRow, endRow - 1)
      if bufferRow is lastBufferRow
        lineNumber = '•'
        key = "#{bufferRow}-#{++wrapCount}"
      else
        lastBufferRow = bufferRow
        wrapCount = 0
        lineNumber = (bufferRow + 1).toString()
        key = bufferRow.toString()

      lineNumbers.push(LineNumberComponent({lineNumber, maxDigits, bufferRow, key}))
      lastBufferRow = bufferRow

    div className: 'gutter',
      div className: 'line-numbers', style: style, [
        div className: 'spacer', key: 'top-spacer', style: {height: precedingHeight}
        lineNumbers...
        div className: 'spacer', key: 'bottom-spacer', style: {height: followingHeight}
      ]

  componentDidMount: ->
    @pendingChanges = []
    @subscribe @props.editor, 'screen-lines-changed', @onScreenLinesChanged

  componentWillUnmount: ->
    @unsubscribe()

  # Only update the gutter if the visible row range has changed or if a
  # non-zero-delta change to the screen lines has occurred within the current
  # visible row range.
  shouldComponentUpdate: (newProps) ->
    {visibleRowRange} = @props

    return true unless isEqual(newProps.visibleRowRange, visibleRowRange)

    for change in @pendingChanges when change.screenDelta > 0 or change.bufferDelta > 0
      return true unless change.end <= visibleRowRange.start or visibleRowRange.end <= change.start

    false

  componentDidUpdate: ->
    @pendingChanges.length = 0

  onScreenLinesChanged: (change) ->
    @pendingChanges.push(change)

LineNumberComponent = React.createClass
  displayName: 'LineNumberComponent'

  render: ->
    {bufferRow} = @props
    div
      className: "line-number line-number-#{bufferRow}"
      'data-buffer-row': bufferRow
      dangerouslySetInnerHTML: {__html: @buildInnerHTML()}

  buildInnerHTML: ->
    {lineNumber, maxDigits} = @props
    if lineNumber.length < maxDigits
      padding = multiplyString('&nbsp;', maxDigits - lineNumber.length)
      padding + lineNumber + @iconDivHTML
    else
      lineNumber + @iconDivHTML

  iconDivHTML: '<div class="icon-right"></div>'

  shouldComponentUpdate: -> false
