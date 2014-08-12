_ = require 'underscore-plus'
React = require 'react-atom-fork'
{div, span} = require 'reactionary-atom-fork'
{debounce, isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
{$$} = require 'space-pen'

Decoration = require './decoration'
CursorsComponent = require './cursors-component'
HighlightsComponent = require './highlights-component'
EditorTileComponent = require './editor-tile-component'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
WrapperDiv = document.createElement('div')

module.exports =
LinesComponent = React.createClass
  displayName: 'LinesComponent'

  tileSize: 5
  preservedTileNode: null

  render: ->
    div className: 'lines'

  componentWillMount: ->
    @measuredLines = new WeakSet
    @tileComponentsByStartRow = {}

  componentDidMount: ->
    @getDOMNode().addEventListener 'mousewheel', @onMouseWheel

  shouldComponentUpdate: (newProps) ->
    return true

    return true unless isEqualForProperties(newProps, @props,
      'renderedRowRange', 'lineDecorations', 'highlightDecorations', 'lineHeightInPixels', 'defaultCharWidth',
      'scrollTop', 'scrollLeft', 'showIndentGuide', 'scrollingVertically', 'invisibles', 'visible',
      'scrollViewHeight', 'mouseWheelScreenRow', 'scopedCharacterWidthsChangeCount', 'lineWidth', 'useHardwareAcceleration',
      'placeholderText', 'performedInitialMeasurement', 'backgroundColor', 'cursorPixelRects'
    )

    {renderedRowRange, pendingChanges} = newProps
    return false unless renderedRowRange?

    [renderedStartRow, renderedEndRow] = renderedRowRange
    for change in pendingChanges
      if change.screenDelta is 0
        return true unless change.end < renderedStartRow or renderedEndRow <= change.start
      else
        return true unless renderedEndRow <= change.start

    false

  componentDidUpdate: (prevProps) ->
    {performedInitialMeasurement, visible, scrollingVertically} = @props
    return unless performedInitialMeasurement

    @clearTiles() unless isEqualForProperties(prevProps, @props, 'showIndentGuide', 'invisibles')
    @updateTiles()
    @measureCharactersInNewLines() if visible and not scrollingVertically

  lineNodeForScreenRow: (screenRow) ->
    tileComponent = @tileComponentsByStartRow[@tileStartRowForScreenRow(screenRow)]
    tileComponent?.lineNodeForScreenRow(screenRow)

  tileStartRowForScreenRow: (screenRow) ->
    screenRow - (screenRow % @tileSize)

  measureLineHeightAndDefaultCharWidth: ->
    node = @getDOMNode()
    node.appendChild(DummyLineNode)
    lineHeightInPixels = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    node.removeChild(DummyLineNode)

    {editor} = @props
    editor.setLineHeightInPixels(lineHeightInPixels)
    editor.setDefaultCharWidth(charWidth)

  updateTiles: ->
    {contentPresenter} = @props
    domNode = @getDOMNode()

    for tileStartRow, tileComponent of @tileComponentsByStartRow
      unless contentPresenter.tiles[tileStartRow]?
        if tileComponent.domNode is @preservedTileNode
          tileComponent.preserve()
        else
          domNode.removeChild(tileComponent.domNode)
          delete @tileComponentsByStartRow[tileStartRow]

    for tileStartRow, tilePresenter of contentPresenter.tiles
      if tileComponent = @tileComponentsByStartRow[tileStartRow]
        tileComponent = @tileComponentsByStartRow[tileStartRow]
        tileComponent.revive(tilePresenter) if tileComponent.preserved
        tileComponent.update()
      else
        tileComponent = new EditorTileComponent(tilePresenter)
        @tileComponentsByStartRow[tileStartRow] = tileComponent
        domNode.appendChild(tileComponent.domNode)

  clearTiles: ->
    for startRow, tileComponent of @tileComponentsByStartRow
      domNode.removeChild(tileComponent.domNode)
      delete @tileComponentsByStartRow[startRow]

  remeasureCharacterWidths: ->
    @clearScopedCharWidths()
    @measureCharactersInNewLines()

  measureCharactersInNewLines: ->
    return
    {editor} = @props
    [visibleStartRow, visibleEndRow] = @props.renderedRowRange
    node = @getDOMNode()

    editor.batchCharacterMeasurement =>
      for tokenizedLine, i in editor.linesForScreenRows(visibleStartRow, visibleEndRow - 1)
        screenRow = visibleStartRow + i
        unless @measuredLines.has(tokenizedLine)
          lineNode = @lineNodeForScreenRow(screenRow)
          @measureCharactersInLine(tokenizedLine, lineNode)
      return

  measureCharactersInLine: (tokenizedLine, lineNode) ->
    {editor} = @props
    rangeForMeasurement = null
    iterator = null
    charIndex = 0

    for {value, scopes}, tokenIndex in tokenizedLine.tokens
      charWidths = editor.getScopedCharWidths(scopes)

      for char in value
        continue if char is '\0'

        unless charWidths[char]?
          unless textNode?
            rangeForMeasurement ?= document.createRange()
            iterator =  document.createNodeIterator(lineNode, NodeFilter.SHOW_TEXT, AcceptFilter)
            textNode = iterator.nextNode()
            textNodeIndex = 0
            nextTextNodeIndex = textNode.textContent.length

          while nextTextNodeIndex <= charIndex
            textNode = iterator.nextNode()
            textNodeIndex = nextTextNodeIndex
            nextTextNodeIndex = textNodeIndex + textNode.textContent.length

          i = charIndex - textNodeIndex
          rangeForMeasurement.setStart(textNode, i)
          rangeForMeasurement.setEnd(textNode, i + 1)
          charWidth = rangeForMeasurement.getBoundingClientRect().width
          editor.setScopedCharWidth(scopes, char, charWidth)

        charIndex++

    @measuredLines.add(tokenizedLine)

  clearScopedCharWidths: ->
    @measuredLines.clear()
    @props.editor.clearScopedCharWidths()

  onMouseWheel: (event) ->
    node = event.target
    node = node.parentNode until node.dataset.tile
    @preservedTileNode = node
