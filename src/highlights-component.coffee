React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqualForProperties} = require 'underscore-plus'
{Range, Point} = require 'text-buffer'
HighlightComponent = require './highlight-component'

module.exports =
HighlightsComponent = React.createClass
  displayName: 'HighlightsComponent'

  render: ->
    div className: 'highlights',
      @renderHighlightGroups() if @isMounted()

  renderHighlightGroups: ->
    {renderedRowRange, scrollTop, scrollLeft, editor, lineHeightInPixels, highlightDecorations, tileSize} = @props
    [renderedStartRow, renderedEndRow] = renderedRowRange
    renderedStartRow -= renderedStartRow % tileSize

    for startRow in [renderedStartRow...renderedEndRow] by tileSize
      ref = startRow
      key = startRow
      endRow = startRow + tileSize
      highlightDecorationsForGroup = null

      for markerId, data of highlightDecorations
        if data.screenRange.intersectsRowRange(startRow, endRow)
          highlightDecorationsForGroup ?= {}
          highlightDecorationsForGroup[markerId] = data

      if highlightDecorationsForGroup?
        HighlightGroupComponent {
          key, ref, startRow, endRow, scrollTop, scrollLeft,
          editor, lineHeightInPixels, highlightDecorations: highlightDecorationsForGroup
        }

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props,
      'scrollTop', 'scrollLeft', 'highlightDecorations', 'lineHeightInPixels', 'defaultCharWidth', 'scopedCharacterWidthsChangeCount'
    )

HighlightGroupComponent = React.createClass
  displayName: 'HighlightGroupComponent'

  render: ->
    {startRow, endRow, scrollTop, scrollLeft, editor, lineHeightInPixels, highlightDecorations, lineWidth} = @props

    style =
      position: 'absolute'
      WebkitTransform: @getTranslation()
      width: '100%'

    div {className: 'highlight-group', style}, @renderHighlights()

  renderHighlights: ->
    {editor, startRow, endRow, highlightDecorations, lineHeightInPixels} = @props
    highlightComponents = []

    for markerId, {screenRange, decorations} of highlightDecorations
      for decoration in decorations
        highlightComponents.push(HighlightComponent({
          key: "#{markerId}-#{decoration.class}", screenRange, decoration, editor, lineHeightInPixels, startRow, endRow
        }))

    highlightComponents

  getTranslation: ->
    {startRow, lineHeightInPixels, scrollTop, scrollLeft} = @props
    top = startRow * lineHeightInPixels - scrollTop
    left = -scrollLeft
    "translate3d(#{left}px, #{top}px, 0px)"
