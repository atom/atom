React = require 'react'
{div} = require 'reactionary'
{isEqual, isEqualForProperties, multiplyString} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'

module.exports =
GutterComponent = React.createClass
  displayName: 'GutterComponent'
  mixins: [SubscriberMixin]

  render: ->
    div className: 'gutter',
      @renderLineNumbers() if @isMounted()

  renderLineNumbers: ->
    {editor, renderedRowRange, scrollTop, scrollHeight} = @props
    [startRow, endRow] = renderedRowRange
    charWidth = editor.getDefaultCharWidth()
    lineHeight = editor.getLineHeight()
    maxDigits = editor.getLastBufferRow().toString().length
    style =
      width: charWidth * (maxDigits + 1.5)
      height: scrollHeight
      WebkitTransform: "translate3d(0, #{-scrollTop}px, 0)"

    lineNumbers = []
    tokenizedLines = editor.linesForScreenRows(startRow, endRow - 1)
    tokenizedLines.push({id: 0}) if tokenizedLines.length is 0
    for bufferRow, i in editor.bufferRowsForScreenRows(startRow, endRow - 1)
      if bufferRow is lastBufferRow
        lineNumber = '•'
      else
        lastBufferRow = bufferRow
        lineNumber = (bufferRow + 1).toString()

      key = tokenizedLines[i]?.id
      screenRow = startRow + i
      lineNumbers.push(LineNumberComponent({key, lineNumber, maxDigits, bufferRow, screenRow, lineHeight}))
      lastBufferRow = bufferRow

    div className: 'line-numbers', style: style,
      lineNumbers

  componentWillUnmount: ->
    @unsubscribe()

  # Only update the gutter if the visible row range has changed or if a
  # non-zero-delta change to the screen lines has occurred within the current
  # visible row range.
  shouldComponentUpdate: (newProps) ->
    {renderedRowRange, pendingChanges, scrollTop} = @props

    return true unless isEqualForProperties(newProps, @props, 'renderedRowRange', 'scrollTop', 'lineHeight')

    for change in pendingChanges when change.screenDelta > 0 or change.bufferDelta > 0
      return true unless change.end <= renderedRowRange.start or renderedRowRange.end <= change.start

    false

LineNumberComponent = React.createClass
  displayName: 'LineNumberComponent'

  render: ->
    {bufferRow, screenRow, lineHeight} = @props
    div
      className: "line-number line-number-#{bufferRow}"
      style: {top: screenRow * lineHeight}
      'data-buffer-row': bufferRow
      'data-screen-row': screenRow
      dangerouslySetInnerHTML: {__html: @buildInnerHTML()}

  buildInnerHTML: ->
    {lineNumber, maxDigits} = @props
    if lineNumber.length < maxDigits
      padding = multiplyString('&nbsp;', maxDigits - lineNumber.length)
      padding + lineNumber + @iconDivHTML
    else
      lineNumber + @iconDivHTML

  iconDivHTML: '<div class="icon-right"></div>'

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'lineHeight')
