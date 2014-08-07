{Emitter, Subscriber} = require 'emissary'
_ = require 'underscore-plus'

module.exports =
class EditorPresenter
  Emitter.includeInto(this)
  Subscriber.includeInto(this)

  constructor: (@editor) ->
    @lineTiles = {}
    @gutterTiles = {}
    @updateTiles()

    @subscribe @editor.$width, @onWidthChanged
    @subscribe @editor.$height, @onHeightChanged
    @subscribe @editor.$lineHeightInPixels, @onLineHeightInPixelsChanged
    @subscribe @editor.$scrollTop, @onScrollTopChanged
    @subscribe @editor.$scrollLeft, @onScrollLeftChanged
    @subscribe @editor, 'screen-lines-changed', @onScreenLinesChanged
    @subscribe @editor, 'decoration-added', @onDecorationAdded
    @subscribe @editor, 'decoration-removed', @onDecorationRemoved
    @subscribe @editor, 'decoration-changed', @onDecorationChanged

  getLineTileSize: -> 5

  getGutterTileSize: -> 20

  getVisibleRowRange: ->
    heightInLines = Math.ceil(@editor.getHeight() / @editor.getLineHeightInPixels())
    startRow = Math.floor(@editor.getScrollTop() / @editor.getLineHeightInPixels())
    endRow = Math.min(@editor.getLineCount(), startRow + heightInLines)
    [startRow, endRow]

  lineTileStartRowForRow: (startRow) ->
    startRow - (startRow % @getLineTileSize())

  gutterTileStartRowForRow: (startRow) ->
    startRow - (startRow % @getGutterTileSize())

  getLineTileRowRange: ->
    [startRow, endRow] = @getVisibleRowRange()
    startRow = @lineTileStartRowForRow(startRow)
    endRow = @lineTileStartRowForRow(endRow) + @getLineTileSize()
    [startRow, endRow]

  getGutterTileRowRange: ->
    [startRow, endRow] = @getVisibleRowRange()
    startRow = @gutterTileStartRowForRow(startRow)
    endRow = @gutterTileStartRowForRow(endRow) + @getGutterTileSize()
    [startRow, endRow]

  updateTiles: (fn) ->
    @updateLineTiles(fn)
    @updateGutterTiles(fn)
    @emit 'did-change'

  updateLineTiles: (fn) ->
    [startRow, endRow] = @getLineTileRowRange()

    for tileStartRow of @lineTiles
      delete @lineTiles[tileStartRow] unless startRow <= tileStartRow < endRow

    for tileStartRow in [startRow...endRow] by @getLineTileSize()
      if existingTile = @lineTiles[tileStartRow]
        fn?(existingTile)
      else
        tileEndRow = tileStartRow + @getLineTileSize()
        @lineTiles[tileStartRow] = new LineTilePresenter(@editor, tileStartRow, tileEndRow)

  updateGutterTiles: (fn) ->
    [startRow, endRow] = @getGutterTileRowRange()

    for tileStartRow of @gutterTiles
      delete @gutterTiles[tileStartRow] unless startRow <= tileStartRow < endRow

    for tileStartRow in [startRow...endRow] by @getGutterTileSize()
      if existingTile = @gutterTiles[tileStartRow]
        fn?(existingTile)
      else
        tileEndRow = tileStartRow + @getGutterTileSize()
        @gutterTiles[tileStartRow] = new GutterTilePresenter(@editor, tileStartRow, tileEndRow)

  onWidthChanged: =>
    @updateTiles (tile) -> tile.updateWidth()

  onHeightChanged: =>
    @updateTiles()

  onLineHeightInPixelsChanged: =>
    @updateTiles (tile) -> tile.updateLineHeightInPixels()

  onScrollTopChanged: =>
    @updateTiles (tile) -> tile.updateScrollTop()

  onScrollLeftChanged: =>
    @updateTiles (tile) -> tile.updateScrollLeft()

  onScreenLinesChanged: (change) =>
    @updateTiles (tile) -> tile.onScreenLinesChanged(change)

  onDecorationAdded: (marker, decoration) =>
    @updateTiles (tile) -> tile.onDecorationAdded(decoration)

  onDecorationRemoved: (marker, decoration) =>
    @updateTiles (tile) -> tile.onDecorationRemoved(decoration)

  onDecorationChanged: (marker, decoration, change) =>
    @updateTiles (tile) -> tile.onDecorationChanged(decoration, change)

class LineTilePresenter
  constructor: (@editor, @startRow, @endRow) ->
    @lineDecorations = {}
    @updateWidth()
    @updateLineHeightInPixels()
    @updateScrollTop()
    @updateScrollLeft()
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
    @updateLineHeightInPixels()
    @updateScrollTop()

  updateLineHeightInPixels: ->
    @lineHeightInPixels = @editor.getLineHeightInPixels()
    @updateTop()
    @updateHeight()
    @updateLineNumbers()

  updateScrollLeft: -> # NO-OP

  updateScrollTop: ->
    @updateTop()

  updateTop: ->
    @top = @startRow * @editor.getLineHeightInPixels() - @editor.getScrollTop()

  updateWidth: -> # NO-OP

  updateHeight: ->
    @height = (@endRow - @startRow) * @editor.getLineHeightInPixels()

  updateLineNumbers: ->
    @lineNumbers = @editor.lineNumbersForScreenRows(@startRow, @endRow - 1)
    @maxLineNumberDigits = @editor.getLineCount().toString().length

  onScreenLinesChanged: (change) ->
    if (change.bufferDelta isnt 0 or change.screenDelta isnt 0) and change.start < @endRow
      @updateLineNumbers()

  onDecorationAdded: (decoration) ->

  onDecorationRemoved: (decoration) ->

  onDecorationChanged: (decoration, change) ->
