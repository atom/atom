_ = require 'underscore-plus'
React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
Decoration = require './decoration'
SubscriberMixin = require './subscriber-mixin'
GutterTileComponent = require './gutter-tile-component'

WrapperDiv = document.createElement('div')

module.exports =
GutterComponent = React.createClass
  displayName: 'GutterComponent'
  mixins: [SubscriberMixin]

  dummyLineNumberNode: null
  measuredWidth: null

  render: ->
    div className: 'gutter', onClick: @onClick, onMouseDown: @props.onMouseDown

  componentWillMount: ->
    @tileComponentsByStartRow = {}

  componentDidMount: ->
    @appendDummyTile()

  componentDidUpdate: (oldProps) ->
    if @props.performedInitialMeasurement
      @updateTiles()

  updateTiles: ->
    {gutterPresenter} = @props

    domNode = @getDOMNode()

    for tileStartRow, tileComponent of @tileComponentsByStartRow
      unless gutterPresenter.tiles[tileStartRow]?
        domNode.removeChild(tileComponent.domNode)
        delete @tileComponentsByStartRow[tileStartRow]

    for tileStartRow, tilePresenter of gutterPresenter.tiles
      if tileComponent = @tileComponentsByStartRow[tileStartRow]
        tileComponent = @tileComponentsByStartRow[tileStartRow]
        tileComponent.update()
      else
        tileComponent = new GutterTileComponent(tilePresenter)
        @tileComponentsByStartRow[tileStartRow] = tileComponent
        domNode.appendChild(tileComponent.domNode)

  # This dummy line number element holds the gutter to the appropriate width,
  # since the real line numbers are absolutely positioned for performance reasons.
  appendDummyTile: ->
    @dummyTileComponent = new GutterTileComponent(@props.gutterPresenter.dummyTile)
    @getDOMNode().appendChild(@dummyTileComponent.domNode)

  updateDummyLineNumber: ->
    @dummyLineNumberNode.innerHTML = @buildLineNumberInnerHTML(0, false, @props.maxLineNumberDigits)

  hasDecoration: (decorations, decoration) ->
    decorations? and decorations[decoration.id] is decoration

  hasLineNumberNode: (lineNumberId) ->
    @lineNumberNodesById.hasOwnProperty(lineNumberId)

  lineNumberNodeForScreenRow: (screenRow) ->
    @lineNumberNodesById[@lineNumberIdsByScreenRow[screenRow]]

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
