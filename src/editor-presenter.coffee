{Emitter, Subscriber} = require 'emissary'
_ = require 'underscore-plus'

module.exports =
class EditorPresenter
  Emitter.includeInto(this)
  Subscriber.includeInto(this)

  constructor: (@editor) ->
    @tiles = {}
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

  getTileSize: -> 5

  getVisibleRowRange: ->
    heightInLines = Math.floor(@editor.getHeight() / @editor.getLineHeightInPixels())
    startRow = Math.ceil(@editor.getScrollTop() / @editor.getLineHeightInPixels())
    endRow = Math.min(@editor.getLineCount(), startRow + heightInLines)
    [startRow, endRow]

  getTileRowRange: ->
    [startRow, endRow] = @getVisibleRowRange()
    startRow = @tileStartRowForRow(startRow)
    endRow = @tileStartRowForRow(endRow) + @getTileSize()
    [startRow, endRow]

  tileStartRowForRow: (row) ->
    row - (row % @getTileSize())

  updateTiles: (fn) ->
    [startRow, endRow] = @getTileRowRange()

    for tileStartRow of @tiles
      delete @tiles[tileStartRow] unless startRow <= tileStartRow < endRow

    for tileStartRow in [startRow...endRow] by @getTileSize()
      if existingTile = @tiles[tileStartRow]
        fn?(existingTile)
      else
        tileEndRow = tileStartRow + @getTileSize()
        @tiles[tileStartRow] = new TilePresenter(@editor, tileStartRow, tileEndRow)

    @emit 'did-change'

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
    @updateTiles (tile) ->
      unless tile.endRow < change.start
        tile.updateLines()

  onDecorationAdded: (marker, decoration) =>
    @updateTiles (tile) -> tile.onDecorationAdded(decoration)

  onDecorationRemoved: (marker, decoration) =>
    @updateTiles (tile) -> tile.onDecorationRemoved(decoration)

  onDecorationChanged: (marker, decoration, change) =>
    @updateTiles (tile) -> tile.onDecorationChanged(decoration, change)

class TilePresenter
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
