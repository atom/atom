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

  lineNumberGroupSize: 10
  measuredWidth: null

  render: ->
    {scrollHeight, scrollViewHeight, scrollTop, onMouseDown, maxLineNumberDigits} = @props
    style =
      position: 'relative'
      WebkitTransform: 'translateZ(0px)'

    div className: 'gutter', style: style, onClick: @onClick, onMouseDown: onMouseDown,
      if @isMounted()
        [
          LineNumberComponent({key: 'dummy', bufferRow: -1, maxLineNumberDigits})
          @renderLineNumberGroups()
        ]

  renderLineNumberGroups: ->
    {renderedRowRange, scrollTop, editor, lineHeightInPixels, maxLineNumberDigits} = @props
    [renderedStartRow, renderedEndRow] = renderedRowRange
    renderedStartRow -= renderedStartRow % @lineNumberGroupSize

    for startRow in [renderedStartRow...renderedEndRow] by @lineNumberGroupSize
      key = startRow
      endRow = startRow + @lineNumberGroupSize
      LineNumberGroupComponent {
        key, startRow, endRow, scrollTop, editor, lineHeightInPixels, maxLineNumberDigits
      }

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
    unless isEqualForProperties(oldProps, @props, 'maxLineNumberDigits', 'defaultCharWidth')
      @measureWidth()

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

LineNumberGroupComponent = React.createClass
  displayName: 'LineNumberGroupComponent'

  render: ->
    {editor, startRow, endRow, scrollTop, scrollLeft, lineHeightInPixels, showIndentGuide, mini, invisibles} = @props
    top = startRow * lineHeightInPixels - scrollTop
    style =
      position: 'absolute'
      top: 0
      WebkitTransform: "translate3d(0px, #{top}px, 0px)"

    div {className: 'line-number-group', style},
      @renderLineNumbers()

  renderLineNumbers: ->
    {editor, startRow, endRow, maxLineNumberDigits} = @props

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
      LineNumberComponent({key, bufferRow, screenRow, softWrapped, maxLineNumberDigits})

LineNumberComponent = React.createClass
  displayName: 'LineNumberComponent'

  innerHTML: null

  render: ->
    {bufferRow} = @props
    style = visibility: 'hidden' if bufferRow is -1

    @innerHTML ?= @buildInnerHTML()

    div {
      className: 'line-number'
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

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'screenRow', 'lineHeightInPixels', 'maxLineNumberDigits')

  componentWillUpdate: (newProps) ->
    @innerHTML = null unless newProps.maxLineNumberDigits is @props.maxLineNumberDigits
