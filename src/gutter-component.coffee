React = require 'react'
{div} = require 'reactionary'
{isEqual, multiplyString} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'

module.exports =
GutterComponent = React.createClass
  displayName: 'GutterComponent'
  mixins: [SubscriberMixin]

  render: ->
    div className: 'gutter',
      @renderLineNumbers() if @isMounted()

  renderLineNumbers: ->
    {editor, visibleRowRange, preservedScreenRow, scrollTop} = @props
    [startRow, endRow] = visibleRowRange
    lineHeightInPixels = editor.getLineHeight()
    maxDigits = editor.getLastBufferRow().toString().length
    style =
      height: editor.getScrollHeight()
      WebkitTransform: "translateY(#{-scrollTop}px)"
      paddingTop: startRow * lineHeightInPixels
      paddingBottom: (editor.getScreenLineCount() - endRow) * lineHeightInPixels

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
      lineNumbers.push(LineNumberComponent({key, lineNumber, maxDigits, bufferRow, screenRow}))
      lastBufferRow = bufferRow

    if preservedScreenRow? and (preservedScreenRow < startRow or endRow <= preservedScreenRow)
      lineNumbers.push(LineNumberComponent({key: editor.lineForScreenRow(preservedScreenRow).id, preserved: true}))

    div className: 'line-numbers', style: style,
      lineNumbers

  componentWillUnmount: ->
    @unsubscribe()

  # Only update the gutter if the visible row range has changed or if a
  # non-zero-delta change to the screen lines has occurred within the current
  # visible row range.
  shouldComponentUpdate: (newProps) ->
    {visibleRowRange, pendingChanges, scrollTop} = @props

    return true unless newProps.scrollTop is scrollTop
    return true unless isEqual(newProps.visibleRowRange, visibleRowRange)

    for change in pendingChanges when change.screenDelta > 0 or change.bufferDelta > 0
      return true unless change.end <= visibleRowRange.start or visibleRowRange.end <= change.start

    false

LineNumberComponent = React.createClass
  displayName: 'LineNumberComponent'

  render: ->
    {bufferRow, screenRow} = @props
    div
      className: "line-number line-number-#{bufferRow}"
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

  shouldComponentUpdate: -> false
