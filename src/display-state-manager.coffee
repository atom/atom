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
    @buildInitialState()
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
    @subscribe @editor, 'decoration-removed', @onDecorationRemoved
    @subscribe @editor, 'decoration-changed', @onDecorationChanged

  tileStartRowForScreenRow: (screenRow) ->
    screenRow - (screenRow % @getTileSize())

  getVisibleRowRange: ->
    heightInLines = Math.floor(@editor.getHeight() / @editor.getLineHeightInPixels())
    startRow = Math.ceil(@editor.getScrollTop() / @editor.getLineHeightInPixels())
    endRow = Math.min(@editor.getLineCount(), startRow + heightInLines)
    [startRow, endRow]

  getTileRowRange: ->
    [startRow, endRow] = @getVisibleRowRange()
    [@tileStartRowForScreenRow(startRow), @tileStartRowForScreenRow(endRow)]

  buildInitialState: ->
    [startRow, endRow] = @getTileRowRange()
    @state = Immutable.Map
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

  updateTilesIntersectingRowRange: (rangeStartRow, rangeEndRow, fn) ->
    tileSize = @getTileSize()

    @updateTiles (tileStartRow, tile) ->
      tileEndRow = tileStartRow + tileSize
      if rangeEndRow < tileStartRow or tileEndRow <= rangeStartRow
        tile
      else
        fn(tileStartRow, tile)

  buildTile: (tileStartRow) ->
    lineHeightInPixels = @editor.getLineHeightInPixels()
    tileSize = @getTileSize()
    tileEndRow = tileStartRow + tileSize

    Immutable.Map
      startRow: tileStartRow
      left: 0 - @editor.getScrollLeft()
      top: tileStartRow * lineHeightInPixels - @editor.getScrollTop()
      width: @getLineWidth()
      height: lineHeightInPixels * tileSize
      lineHeightInPixels: @editor.getLineHeightInPixels()
      lines: Immutable.Vector(@editor.linesForScreenRows(tileStartRow, tileEndRow - 1)...)
      lineDecorations: @buildLineDecorationsForTile(tileStartRow, tileEndRow)

  buildLineDecorationsForTile: (tileStartRow, tileEndRow) ->
    Immutable.Map().withMutations (lineDecorations) =>
      for markerId, decorations of @editor.decorationsForScreenRowRange(tileStartRow, tileEndRow)
        {start, end} = @editor.getMarker(markerId).getScreenRange()
        startRow = Math.max(start.row, tileStartRow)
        endRow = Math.min(end.row, tileEndRow)
        for row in [startRow..endRow]
          for decoration in decorations
            lineDecorations.update row, (decorationsById) ->
              decorationsById ?= Immutable.Map()
              decorationsById.set(decoration.id, decoration.getParams())

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
    return unless decoration.isType('line')

    headPosition = marker.getHeadScreenPosition()
    tailPosition = marker.getTailScreenPosition()
    valid = marker.isValid()

    if rowRange = @rowRangeForLineDecoration(decoration, headPosition, tailPosition, valid)
      [start, end] = rowRange
      params = decoration.getParams()
      @updateTilesIntersectingRowRange start, end, (tileStart, tile) =>
        @tileWithLineDecorations(tile, start, end, decoration.id, params)

  onDecorationRemoved: (marker, decoration) =>
    return unless decoration.isType('line')

    headPosition = marker.getHeadScreenPosition()
    tailPosition = marker.getTailScreenPosition()
    valid = true # FIXME: Why is a marker invalidated when destroyed? That seems wrong.

    if rowRange = @rowRangeForLineDecoration(decoration, headPosition, tailPosition, valid)
      [start, end] = rowRange
      @updateTilesIntersectingRowRange start, end, (tileStart, tile) =>
        @tileWithoutLineDecorations(tile, start, end, decoration.id)

  onDecorationChanged: (marker, decoration, change) =>
    return unless decoration.isType('line')

    {oldHeadScreenPosition, oldTailScreenPosition, wasValid} = change
    if rowRangeToRemove = @rowRangeForLineDecoration(decoration, oldHeadScreenPosition, oldTailScreenPosition, wasValid)
      [start, end] = rowRangeToRemove
      @updateTilesIntersectingRowRange start, end, (tileStart, tile) =>
        @tileWithoutLineDecorations(tile, start, end, decoration.id)

    {newHeadScreenPosition, newTailScreenPosition, isValid} = change
    if rowRangeToAdd = @rowRangeForLineDecoration(decoration, newHeadScreenPosition, newTailScreenPosition, isValid)
      [start, end] = rowRangeToAdd
      params = decoration.getParams()
      @updateTilesIntersectingRowRange start, end, (tileStart, tile) =>
        @tileWithLineDecorations(tile, start, end, decoration.id, params)

  rowRangeForLineDecoration: (decoration, headPosition, tailPosition, valid) ->
    return unless valid

    if decoration.getParams().onlyHead
      return [headPosition.row, headPosition.row]

    start = Math.min(headPosition.row, tailPosition.row)
    end = Math.max(headPosition.row, tailPosition.row)
    [start, end]

  tileWithLineDecorations: (tile, start, end, decorationId, decorationParams) ->
    tileStart = tile.get('startRow')
    tileEnd = tileStart + @getTileSize()
    start = Math.max(start, tileStart)
    end = Math.min(end, tileEnd)

    tile.update 'lineDecorations', (lineDecorations) ->
      lineDecorations.withMutations (lineDecorations) ->
        for row in [start..end]
          lineDecorations.update row, (decorationsById) ->
            decorationsById ?= Immutable.Map()
            decorationsById.set(decorationId, decorationParams)

  tileWithoutLineDecorations: (tile, start, end, decorationId) ->
    tileStart = tile.get('startRow')
    tileEnd = tileStart + @getTileSize()
    start = Math.max(start, tileStart)
    end = Math.min(end, tileEnd)

    tile.update 'lineDecorations', (lineDecorations) ->
      lineDecorations.withMutations (lineDecorations) ->
        for row in [start..end]
          lineDecorations.update row, (decorationsById) ->
            decorationsById?.delete(decorationId)
          if lineDecorations.get(row)?.length is 0
            lineDecorations.delete(row)
