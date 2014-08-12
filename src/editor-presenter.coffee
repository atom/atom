{Emitter, Subscriber} = require 'emissary'
_ = require 'underscore-plus'

module.exports =
class EditorPresenter
  Emitter.includeInto(this)
  Subscriber.includeInto(this)

  constructor: (@editor) ->
    @content = {tiles: {}}
    @gutter = {tiles: {}, dummyTile: {dummy: true}}
    @updateTiles()
    @updateDummyGutterTile()
    @scrollTop = @editor.getScrollTop()
    @scrollLeft = @editor.getScrollLeft()

    @subscribe @editor.$width.changes, @onWidthChanged
    @subscribe @editor.$height.changes, @onHeightChanged
    @subscribe @editor.$lineHeightInPixels.changes, @onLineHeightInPixelsChanged
    @subscribe @editor.$scrollTop.changes, @onScrollTopChanged
    @subscribe @editor.$scrollLeft.changes, @onScrollLeftChanged
    @subscribe @editor.$backgroundColor.changes, @onBackgroundColorChanged
    @subscribe @editor.$gutterBackgroundColor.changes, @onBackgroundColorChanged
    @subscribe @editor, 'screen-lines-changed', @onScreenLinesChanged
    @subscribe @editor, 'decoration-added', @onDecorationAdded
    @subscribe @editor, 'decoration-removed', @onDecorationRemoved
    @subscribe @editor, 'decoration-changed', @onDecorationChanged

  getContentTileSize: -> 5

  getGutterTileSize: -> 20

  getVisibleRowRange: ->
    heightInLines = Math.ceil(@editor.getHeight() / @editor.getLineHeightInPixels())
    startRow = Math.floor(@editor.getScrollTop() / @editor.getLineHeightInPixels())
    endRow = Math.min(@editor.getLineCount(), startRow + heightInLines)
    [startRow, endRow]

  contentTileStartRowForRow: (startRow) ->
    startRow - (startRow % @getContentTileSize())

  gutterTileStartRowForRow: (startRow) ->
    startRow - (startRow % @getGutterTileSize())

  getContentTileRowRange: ->
    [startRow, endRow] = @getVisibleRowRange()
    startRow = @contentTileStartRowForRow(startRow)
    endRow = @contentTileStartRowForRow(endRow) + @getContentTileSize()
    [startRow, endRow]

  getGutterTileRowRange: ->
    [startRow, endRow] = @getVisibleRowRange()
    startRow = @gutterTileStartRowForRow(startRow)
    endRow = @gutterTileStartRowForRow(endRow) + @getGutterTileSize()
    [startRow, endRow]

  updateTiles: (fn) ->
    @updateContentTiles(fn)
    @updateGutterTiles(fn)
    @emit 'did-change'

  updateContentTiles: (fn) ->
    [startRow, endRow] = @getContentTileRowRange()

    for tileStartRow of @content.tiles
      delete @content.tiles[tileStartRow] unless startRow <= tileStartRow < endRow

    for tileStartRow in [startRow...endRow] by @getContentTileSize()
      if existingTile = @content.tiles[tileStartRow]
        fn?(existingTile)
      else
        tileEndRow = tileStartRow + @getContentTileSize()
        @content.tiles[tileStartRow] = new ContentTilePresenter(@editor, tileStartRow, tileEndRow)

  updateGutterTiles: (fn) ->
    [startRow, endRow] = @getGutterTileRowRange()

    for tileStartRow of @gutter.tiles
      delete @gutter.tiles[tileStartRow] unless startRow <= tileStartRow < endRow

    for tileStartRow in [startRow...endRow] by @getGutterTileSize()
      if existingTile = @gutter.tiles[tileStartRow]
        fn?(existingTile)
      else
        tileEndRow = tileStartRow + @getGutterTileSize()
        @gutter.tiles[tileStartRow] = new GutterTilePresenter(@editor, tileStartRow, tileEndRow)

  updateDummyGutterTile: ->
    @gutter.dummyTile.maxLineNumberDigits = @editor.getLineCount().toString().length

  onWidthChanged: =>
    @updateTiles (tile) -> tile.updateWidth()

  onHeightChanged: =>
    @updateTiles()

  onLineHeightInPixelsChanged: =>
    @updateTiles (tile) -> tile.updateLineHeightInPixels()

  onScrollTopChanged: (@scrollTop) =>
    @updateTiles (tile) -> tile.updateScrollTop()

  onScrollLeftChanged: (@scrollLeft) =>
    @updateTiles (tile) -> tile.updateScrollLeft()

  onScreenLinesChanged: (change) =>
    @updateDummyGutterTile() if change.bufferDelta isnt 0
    @updateTiles (tile) -> tile.onScreenLinesChanged(change)

  onBackgroundColorChanged: =>
    @updateTiles (tile) -> tile.updateBackgroundColor()

  onDecorationAdded: (marker, decoration) =>
    @updateTiles (tile) -> tile.onDecorationAdded(decoration)

  onDecorationRemoved: (marker, decoration) =>
    @updateTiles (tile) -> tile.onDecorationRemoved(decoration)

  onDecorationChanged: (marker, decoration, change) =>
    @updateTiles (tile) -> tile.onDecorationChanged(decoration, change)

class ContentTilePresenter
  constructor: (@editor, @startRow, @endRow) ->
    @lineDecorations = {}
    @updateWidth()
    @updateLineHeightInPixels()
    @updateScrollTop()
    @updateScrollLeft()
    @updateBackgroundColor()
    @updateLines()
    @populateDecorations()

  updateWidth: ->
    @width = @editor.getWidth()

  updateHeight: ->
    @height = (@endRow - @startRow) * @editor.getLineHeightInPixels()

  updateLineHeightInPixels: ->
    @lineHeightInPixels = @editor.getLineHeightInPixels()
    @updateTop()
    @updateHeight()

  updateScrollTop: ->
    @updateTop()

  updateScrollLeft: ->
    @left = 0 - @editor.getScrollLeft()

  updateBackgroundColor: ->
    @backgroundColor = @editor.getBackgroundColor()

  updateTop: ->
    @top = @startRow * @editor.getLineHeightInPixels() - @editor.getScrollTop()

  updateLines: ->
    @lines = @editor.linesForScreenRows(@startRow, @endRow - 1)

  populateDecorations: ->
    for markerId, decorations of @editor.decorationsForScreenRowRange(@startRow, @endRow)
      for decoration in decorations
        @onDecorationAdded(decoration)

  onScreenLinesChanged: (change) ->
    @updateLines() if change.start < @endRow

  onDecorationAdded: (decoration) ->
    if decoration.isType('line')
      @onLineDecorationAdded(decoration)

  onDecorationRemoved: (decoration) ->
    if decoration.isType('line')
      @onLineDecorationRemoved(decoration)

  onDecorationChanged: (decoration, change) ->
    if decoration.isType('line')
      @onLineDecorationChanged(decoration, change)

  onLineDecorationAdded: (decoration) ->
    marker = decoration.getMarker()
    headRow = marker.getHeadScreenPosition().row
    tailRow = marker.getTailScreenPosition().row
    valid = marker.isValid()
    params = decoration.getParams()

    if rowRange = @rowRangeForLineDecoration(params, headRow, tailRow, valid)
      @addLineDecorations(params, rowRange...)

  onLineDecorationRemoved: (decoration) ->
    marker = decoration.getMarker()
    headRow = marker.getHeadScreenPosition().row
    tailRow = marker.getTailScreenPosition().row
    valid = true # FIXME: Markers shouldn't always be invalidated when destroyed
    params = decoration.getParams()

    if rowRange = @rowRangeForLineDecoration(params, headRow, tailRow, valid)
      @removeLineDecorations(params, rowRange...)

  onLineDecorationChanged: (decoration, change) ->
    params = decoration.getParams()

    {oldHeadScreenPosition, oldTailScreenPosition, wasValid} = change
    if rowRange = @rowRangeForLineDecoration(params, oldHeadScreenPosition.row, oldTailScreenPosition.row, wasValid)
      @removeLineDecorations(params, rowRange...)

    {newHeadScreenPosition, newTailScreenPosition, isValid} = change
    if rowRange = @rowRangeForLineDecoration(params, newHeadScreenPosition.row, newTailScreenPosition.row, isValid)
      @addLineDecorations(params, rowRange...)

  addLineDecorations: (params, decorationStartRow, decorationEndRow) ->
    unless decorationEndRow < @startRow or @endRow <= decorationStartRow
      for row in [decorationStartRow..decorationEndRow]
        @lineDecorations[row] ?= {}
        @lineDecorations[row][params.id] = params

  removeLineDecorations: (params, decorationStartRow, decorationEndRow) ->
    unless decorationEndRow < @startRow or @endRow <= decorationStartRow
      for row in [decorationStartRow..decorationEndRow]
        delete @lineDecorations[row][params.id]
        delete @lineDecorations[row] if _.size(@lineDecorations[row]) is 0

  rowRangeForLineDecoration: (decoration, headRow, tailRow, valid) ->
    return unless valid

    startRow = Math.min(headRow, tailRow)
    endRow = Math.max(headRow, tailRow)
    [startRow, endRow]

class GutterTilePresenter
  constructor: (@editor, @startRow, @endRow) ->
    @lineNumberDecorations = {}

    @populateDecorations()
    @updateLineHeightInPixels()
    @updateScrollTop()
    @updateBackgroundColor()

  populateDecorations: ->
    for markerId, decorations of @editor.decorationsForScreenRowRange(@startRow, @endRow)
      for decoration in decorations
        @onDecorationAdded(decoration)

  updateLineHeightInPixels: ->
    @lineHeightInPixels = @editor.getLineHeightInPixels()
    @updateTop()
    @updateHeight()
    @updateLineNumbers()

  updateScrollLeft: -> # NO-OP

  updateScrollTop: ->
    @updateTop()

  updateBackgroundColor: ->
    @backgroundColor = @editor.getGutterBackgroundColor() ? @editor.getBackgroundColor()

  updateTop: ->
    @top = @startRow * @editor.getLineHeightInPixels() - @editor.getScrollTop()

  updateWidth: -> # NO-OP

  updateHeight: ->
    @height = (@endRow - @startRow) * @editor.getLineHeightInPixels()

  updateLineNumbers: ->
    @lineNumbers = @editor.lineNumbersForScreenRows(@startRow, @endRow - 1)
    @maxLineNumberDigits = @editor.getLineCount().toString().length

  updateMaxLineNumberDigits: ->
    @maxLineNumberDigits = @editor.getLineCount().toString().length

  onScreenLinesChanged: (change) ->
    if change.bufferDelta isnt 0 or change.screenDelta isnt 0
      @updateMaxLineNumberDigits()
      @updateLineNumbers() if change.start < @endRow

  onDecorationAdded: (decoration) ->
    return unless decoration.isType('gutter')

    marker = decoration.getMarker()
    headRow = marker.getHeadScreenPosition().row
    tailRow = marker.getTailScreenPosition().row
    valid = marker.isValid()
    params = decoration.getParams()

    if rowRange = @rowRangeForLineNumberDecoration(params, headRow, tailRow, valid)
      @addLineNumberDecorations(params, rowRange...)

  onDecorationRemoved: (decoration) ->
    return unless decoration.isType('gutter')

    marker = decoration.getMarker()
    headRow = marker.getHeadScreenPosition().row
    tailRow = marker.getTailScreenPosition().row
    valid = true # FIXME: Markers shouldn't always be invalidated when destroyed
    params = decoration.getParams()

    if rowRange = @rowRangeForLineNumberDecoration(params, headRow, tailRow, valid)
      @removeLineNumberDecorations(params, rowRange...)

  onDecorationChanged: (decoration, change) ->
    return unless decoration.isType('gutter')

    params = decoration.getParams()

    {oldHeadScreenPosition, oldTailScreenPosition, wasValid} = change
    if rowRange = @rowRangeForLineNumberDecoration(params, oldHeadScreenPosition.row, oldTailScreenPosition.row, wasValid)
      @removeLineNumberDecorations(params, rowRange...)

    {newHeadScreenPosition, newTailScreenPosition, isValid} = change
    if rowRange = @rowRangeForLineNumberDecoration(params, newHeadScreenPosition.row, newTailScreenPosition.row, isValid)
      @addLineNumberDecorations(params, rowRange...)

  addLineNumberDecorations: (params, decorationStartRow, decorationEndRow) ->
    unless decorationEndRow < @startRow or @endRow <= decorationStartRow
      for row in [decorationStartRow..decorationEndRow]
        @lineNumberDecorations[row] ?= {}
        @lineNumberDecorations[row][params.id] = params

  removeLineNumberDecorations: (params, decorationStartRow, decorationEndRow) ->
    unless decorationEndRow < @startRow or @endRow <= decorationStartRow
      for row in [decorationStartRow..decorationEndRow]
        delete @lineNumberDecorations[row][params.id]
        delete @lineNumberDecorations[row] if _.size(@lineNumberDecorations[row]) is 0

  rowRangeForLineNumberDecoration: (decoration, headRow, tailRow, valid) ->
    return unless valid

    startRow = Math.min(headRow, tailRow)
    endRow = Math.max(headRow, tailRow)
    [startRow, endRow]
