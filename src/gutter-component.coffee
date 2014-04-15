React = require 'react'
{div} = require 'reactionary'
{multiplyString} = require 'underscore-plus'

module.exports =
GutterComponent = React.createClass
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

LineNumberComponent = React.createClass
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
