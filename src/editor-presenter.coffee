{Emitter, Subscriber} = require 'emissary'

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

class TilePresenter
  constructor: (@editor, @startRow, @endRow) ->
    @updateWidth()
    @updateLineHeightInPixels()
    @updateScrollTop()
    @updateScrollLeft()
    @updateLines()

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

  buildInitialDecorations: ->
    @lineDecorations = {}

    for markerId, decorations of @editor.decorationsForScreenRowRange(@startRow, @endRow)
      for decoration in decorations
        if decoration.isType('line')
          if rowRange = decoration.getRowRange()
            [start, end] = rowRange
            for row in [start..end]
              @lineDecorations[row] ?= {}
              @lineDecorations[row][decoration.id] = decoration.getParams()
