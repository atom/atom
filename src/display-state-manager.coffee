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
    @subscribe @editor.$width.changes, => @updateTiles()
    @subscribe @editor.$height.changes, => @updateTiles()
    @subscribe @editor.$lineHeightInPixels.changes, => @updateTiles()
    @subscribe @editor.$scrollLeft.changes, => @updateTiles()
    @subscribe @editor.$scrollTop.changes, => @updateTiles()
    @subscribe @editor, 'screen-lines-changed', (change) => @updateTiles(change)

  tileStartRowForScreenRow: (screenRow) ->
    screenRow - (screenRow % @getTileSize())

  getVisibleStartRow: ->
    Math.ceil(@editor.getScrollTop() / @editor.getLineHeightInPixels())

  getVisibleEndRow: ->
    heightInLines = Math.floor(@editor.getHeight() / @editor.getLineHeightInPixels())
    Math.min(@editor.getLineCount(), @getVisibleStartRow() + heightInLines)

  buildInitialState: ->
    Immutable.Map
      tiles: Immutable.Map().withMutations (tiles) =>
        visibleStartRow = @tileStartRowForScreenRow(@getVisibleStartRow())
        visibleEndRow = @getVisibleEndRow()
        for tileStartRow in [visibleStartRow..visibleEndRow] by @getTileSize()
          tiles.set(tileStartRow, @buildTile(tileStartRow))

  updateTiles: (change) ->
    visibleStartRow = @tileStartRowForScreenRow(@getVisibleStartRow())
    visibleEndRow = @getVisibleEndRow()
    lineHeightInPixels = @editor.getLineHeightInPixels()

    @setState @state.update 'tiles', (tiles) =>
      tiles.withMutations (tiles) =>
        tiles.forEach (tile, tileStartRow) ->
          unless visibleStartRow <= tileStartRow <= visibleEndRow
            tiles.delete(tileStartRow)

        for tileStartRow in [visibleStartRow..visibleEndRow] by @getTileSize()
          if tile = tiles.get(tileStartRow)
            tiles.set(tileStartRow, @updateTile(tileStartRow, tile, change))
          else
            tiles.set(tileStartRow, @buildTile(tileStartRow))

  buildTile: (startRow) ->
    lineHeightInPixels = @editor.getLineHeightInPixels()
    tileSize = @getTileSize()

    Immutable.Map
      startRow: startRow
      left: 0 - @editor.getScrollLeft()
      top: startRow * lineHeightInPixels - @editor.getScrollTop()
      width: @getLineWidth()
      height: lineHeightInPixels * tileSize
      lines: Immutable.Vector(@editor.linesForScreenRows(startRow, startRow + tileSize - 1)...)
      lineHeightInPixels: @editor.getLineHeightInPixels()

  updateTile: (startRow, tile, change) ->
    endRow = startRow + @getTileSize()

    tile.withMutations (tile) =>
      tile.set 'left', 0 - @editor.getScrollLeft()
      tile.set 'top', (startRow * @editor.getLineHeightInPixels()) - @editor.getScrollTop()
      tile.set 'width', @getLineWidth()
      tile.set 'lineHeightInPixels', @editor.getLineHeightInPixels()
      if change? and change.start < endRow
        tile.set 'lines', Immutable.Vector(@editor.linesForScreenRows(startRow, endRow - 1)...)
