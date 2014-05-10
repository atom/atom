React = require 'react'
{div} = require 'reactionary'
{isEqual, isEqualForProperties, multiplyString} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'

module.exports =
GutterComponent = React.createClass
  displayName: 'GutterComponent'
  mixins: [SubscriberMixin]

  lastMeasuredWidth: null

  render: ->
    if @isMounted()
      {editor, renderedRowRange, lineOverdraw, scrollTop, lineHeight, showIndentGuide} = @props
      [startRow, endRow] = renderedRowRange
      scrollOffset = -scrollTop % lineHeight
      maxLineNumberDigits = editor.getLineCount().toString().length

      wrapCount = 0
      lineNumbers =
        for bufferRow, index in editor.bufferRowsForScreenRows(startRow, endRow - 1)
          if bufferRow is lastBufferRow
            lineNumber = '•'
            key = "#{bufferRow + 1}-#{++wrapCount}"
          else
            lastBufferRow = bufferRow
            wrapCount = 0
            lineNumber = "#{bufferRow + 1}"
            key = lineNumber

          LineNumberComponent({key, lineNumber, maxLineNumberDigits, index, lineHeight, scrollOffset})

    div className: 'gutter',
      div className: 'line-numbers',
        lineNumbers

  # Only update the gutter if the visible row range has changed or if a
  # non-zero-delta change to the screen lines has occurred within the current
  # visible row range.
  shouldComponentUpdate: (newProps) ->
    return true unless isEqualForProperties(newProps, @props, 'renderedRowRange', 'scrollTop', 'lineHeight', 'fontSize')

    {renderedRowRange, pendingChanges} = newProps
    for change in pendingChanges when change.screenDelta > 0 or change.bufferDelta > 0
      return true unless change.end <= renderedRowRange.start or renderedRowRange.end <= change.start

    false

  componentDidUpdate: (oldProps) ->
    unless @lastMeasuredWidth? and isEqualForProperties(oldProps, @props, 'maxLineNumberDigits', 'fontSize', 'fontFamily')
      width = @getDOMNode().offsetWidth
      if width isnt @lastMeasuredWidth
        @lastMeasuredWidth = width
        @props.onWidthChanged(width)

LineNumberComponent = React.createClass
  displayName: 'LineNumberComponent'

  render: ->
    {index, lineHeight, scrollOffset} = @props
    div
      className: "line-number"
      style: {WebkitTransform: "translate3d(0px, #{index * lineHeight + scrollOffset}px, 0px)"}
      dangerouslySetInnerHTML: {__html: @buildInnerHTML()}

  buildInnerHTML: ->
    {lineNumber, maxLineNumberDigits} = @props
    if lineNumber.length < maxLineNumberDigits
      padding = multiplyString('&nbsp;', maxLineNumberDigits - lineNumber.length)
      padding + lineNumber + @iconDivHTML
    else
      lineNumber + @iconDivHTML

  iconDivHTML: '<div class="icon-right"></div>'

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'index', 'lineHeight', 'scrollOffset')
