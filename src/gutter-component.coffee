React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'


LineComponent = React.createClass
  displayName: 'LineComponent'
  render: ->
    {id, softWrapped, bufferRow, screenRow, style, maxLineNumberDigits} = @props
    {foldable, folded} = @props

    if softWrapped
      text = '\u2022' # a Dot
    else
      text = bufferRow

    className = 'line-number'
    className += ' foldable' if foldable
    className += ' folded' if folded

    div key: id, className: className, 'data-buffer-row': bufferRow, 'data-screen-row': screenRow, style: style,
      text
      div className: 'icon-right', onMouseDown: @toggleFold

  toggleFold: ->
    if @props.foldable
      @props.editor.toggleFoldAtBufferRow(@props.bufferRow)


module.exports =
GutterComponent = React.createClass
  displayName: 'GutterComponent'
  mixins: [SubscriberMixin]

  render: ->
    {editor, scrollHeight, scrollTop, renderedRowRange, lineHeightInPixels, maxLineNumberDigits} = @props
    style =
      height: scrollHeight
      WebkitTransform: "translate3d(0px, #{-scrollTop}px, 0px)"
      position: 'absolute'
      width: "#{maxLineNumberDigits}em"

    rows = []
    if renderedRowRange
      [startRow, endRow] = renderedRowRange

      style.top = "#{startRow * lineHeightInPixels}px"

      wrapCount = 0
      lastBufferRow = null
      rows = for bufferRow, index in editor.bufferRowsForScreenRows(startRow, endRow - 1)
        if bufferRow is lastBufferRow
          id = "#{bufferRow}-#{wrapCount++}"
        else
          id = bufferRow
          wrapCount = 0

        foldable = bufferRow isnt lastBufferRow and editor.isFoldableAtBufferRow(bufferRow)
        folded = editor.isFoldedAtBufferRow(bufferRow)

        lastBufferRow = bufferRow
        LineComponent {editor, id, bufferRow, maxLineNumberDigits, foldable, folded, softWrapped: wrapCount > 0}

    dummyLineStyle =
      visibility: 'hidden'
      width: "#{maxLineNumberDigits}em"

    div className: 'gutter',
      # This dummy line number element holds the gutter to the appropriate width,
      # since the real line numbers are absolutely positioned for performance reasons.
      LineComponent {bufferRow:0, maxLineNumberDigits, style: dummyLineStyle}

      div className: 'line-numbers', ref: 'lineNumbers', style:style, rows...


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
