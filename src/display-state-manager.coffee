{Emitter, Subscriber} = require 'emissary'
Immutable = require 'immutable'
if Immutable.Map.update?
  throw new Error("Remove the Immutable.Map::update shim now that you've upgraded immutable")
else
  Immutable.Map::update = (key, fn) -> @set(key, fn(@get(key)))

module.exports =
class DisplayStateManager
  Emitter.includeInto(this)
  Subscriber.includeInto(this)

  constructor: (@editor) ->
    @state = @buildInitialState()
    @observeEditor()

  getState: -> @state

  setState: (@state) ->
    @emit 'did-change-state', @state
    @state

  getTileSize: -> 5

  getLineWidth: ->
    Math.max(@editor.getScrollWidth(), @editor.getWidth())

  observeEditor: ->
    @subscribe @editor.$width.changes, @onWidthChanged
    @subscribe @editor.$height.changes, @onHeightChanged
    @subscribe @editor.$lineHeightInPixels.changes, @onLineHeightInPixelsChanged
    @subscribe @editor.$scrollLeft.changes, @onScrollLeftChanged
    @subscribe @editor.$scrollTop.changes, @onScrollTopChanged
    @subscribe @editor, 'screen-lines-changed', @onScreenLinesChanged
    @subscribe @editor, 'decoration-added', @onDecorationAdded

  tileStartRowForScreenRow: (screenRow) ->
    screenRow - (screenRow % @getTileSize())

  getTileRowRange: ->
    heightInLines = Math.floor(@editor.getHeight() / @editor.getLineHeightInPixels())
    startRow = Math.ceil(@editor.getScrollTop() / @editor.getLineHeightInPixels())
    endRow = Math.min(@editor.getLineCount(), startRow + heightInLines)
    [@tileStartRowForScreenRow(startRow), @tileStartRowForScreenRow(endRow)]

  buildInitialState: ->
    [startRow, endRow] = @getTileRowRange()

    Immutable.Map
      tiles: Immutable.Map().withMutations (tiles) =>
        for tileStartRow in [startRow..endRow] by @getTileSize()
          tiles.set(tileStartRow, @buildTile(tileStartRow))

  updateTiles: (fn) ->
    tileSize = @getTileSize()
    [startRow, endRow] = @getTileRowRange()

    @setState @state.update 'tiles', (tiles) ->
      tiles.withMutations (tiles) ->
        # delete any tiles that are outside of the row range
        tiles.forEach (tile, tileStartRow) ->
          unless startRow <= tileStartRow <= endRow
            tiles.delete(tileStartRow)

        # call the callback with the start row and existing state of visible tiles
        for tileStartRow in [startRow..endRow] by tileSize
          if newTile = fn(tileStartRow, tiles.get(tileStartRow))
            tiles.set(tileStartRow, newTile)

  buildTile: (startRow) ->
    lineHeightInPixels = @editor.getLineHeightInPixels()
    tileSize = @getTileSize()

    Immutable.Map
      startRow: startRow
      left: 0 - @editor.getScrollLeft()
      top: startRow * lineHeightInPixels - @editor.getScrollTop()
      width: @getLineWidth()
      height: lineHeightInPixels * tileSize
      lineHeightInPixels: @editor.getLineHeightInPixels()
      lines: Immutable.Vector(@editor.linesForScreenRows(startRow, startRow + tileSize - 1)...)
      lineDecorations: Immutable.Map()

  onWidthChanged: (width) =>
    @updateTiles (tileStartRow, tile) => tile.set('width', width)

  onHeightChanged: =>
    @updateTiles (tileStartRow, tile) => tile ? @buildTile(tileStartRow)

  onLineHeightInPixelsChanged: (lineHeightInPixels) =>
    scrollTop = @editor.getScrollTop()

    @updateTiles (tileStartRow, tile) =>
      if tile?
        tile.withMutations (tile) ->
          tile.set('top', tileStartRow * lineHeightInPixels - scrollTop)
          tile.set('lineHeightInPixels', lineHeightInPixels)
      else
        @buildTile(tileStartRow)

  onScrollTopChanged: (scrollTop) =>
    lineHeightInPixels = @editor.getLineHeightInPixels()

    @updateTiles (tileStartRow, tile) =>
      if tile?
        tile.set('top', tileStartRow * lineHeightInPixels - scrollTop)
      else
        @buildTile(tileStartRow)

  onScrollLeftChanged: (scrollLeft) =>
    @updateTiles (tileStartRow, tile) ->
      tile.set('left', 0 - scrollLeft)

  onScreenLinesChanged: (change) =>
    @updateTiles (tileStartRow, tile) =>
      tileEndRow = tileStartRow + @getTileSize()
      if change.start < tileEndRow
        tile.set 'lines',
          Immutable.Vector(@editor.linesForScreenRows(tileStartRow, tileEndRow - 1)...)

  onDecorationAdded: (marker, decoration) =>
    {start, end} = marker.getScreenRange()
    decorationStartRow = start.row
    decorationEndRow = end.row
    tileSize = @getTileSize()

    @updateTiles (tileStartRow, tile) ->
      tileEndRow = tileStartRow + tileSize
      if decorationEndRow < tileStartRow or tileEndRow <= decorationStartRow
        tile
      else
        startRow = Math.max(decorationStartRow, tileStartRow)
        endRow = Math.min(decorationEndRow, tileEndRow - 1)
        tile.update 'lineDecorations', (lineDecorations) ->
          lineDecorations.withMutations (lineDecorations) ->
            for row in [startRow..endRow]
              lineDecorations.update row, (decorationsById) ->
                decorationsById ?= Immutable.Map()
                decorationsById.set(decoration.id, decoration.getParams())
