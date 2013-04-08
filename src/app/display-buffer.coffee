_ = require 'underscore'
TokenizedBuffer = require 'tokenized-buffer'
LineMap = require 'line-map'
Point = require 'point'
EventEmitter = require 'event-emitter'
Range = require 'range'
Fold = require 'fold'
ScreenLine = require 'screen-line'
Token = require 'token'
DisplayBufferMarker = require 'display-buffer-marker'

module.exports =
class DisplayBuffer
  @idCounter: 1
  lineMap: null
  languageMode: null
  tokenizedBuffer: null
  activeFolds: null
  foldsById: null
  markers: null

  constructor: (@buffer, options={}) ->
    @id = @constructor.idCounter++
    @languageMode = options.languageMode
    @tokenizedBuffer = new TokenizedBuffer(@buffer, options)
    @softWrapColumn = options.softWrapColumn ? Infinity
    @activeFolds = {}
    @foldsById = {}
    @markers = {}
    @buildLineMap()
    @tokenizedBuffer.on 'changed', @handleTokenizedBufferChange
    @buffer.on 'markers-updated', @handleMarkersUpdated

  setVisible: (visible) -> @tokenizedBuffer.setVisible(visible)

  buildLineMap: ->
    @lineMap = new LineMap
    @lineMap.insertAtScreenRow 0, @buildLinesForBufferRows(0, @buffer.getLastRow())

  triggerChanged: (eventProperties, refreshMarkers=true) ->
    if refreshMarkers
      @pauseMarkerObservers()
      @refreshMarkerScreenPositions()
    @trigger 'changed', eventProperties
    @resumeMarkerObservers()

  setSoftWrapColumn: (@softWrapColumn) ->
    start = 0
    end = @getLastRow()
    @buildLineMap()
    screenDelta = @getLastRow() - end
    bufferDelta = 0
    @triggerChanged({ start, end, screenDelta, bufferDelta })

  lineForRow: (row) ->
    @lineMap.lineForScreenRow(row)

  linesForRows: (startRow, endRow) ->
    @lineMap.linesForScreenRows(startRow, endRow)

  getLines: ->
    @lineMap.linesForScreenRows(0, @lineMap.lastScreenRow())

  bufferRowsForScreenRows: (startRow, endRow) ->
    @lineMap.bufferRowsForScreenRows(startRow, endRow)

  foldAll: ->
    for currentRow in [0..@buffer.getLastRow()]
      [startRow, endRow] = @languageMode.rowRangeForFoldAtBufferRow(currentRow) ? []
      continue unless startRow?

      @createFold(startRow, endRow)

  unfoldAll: ->
    for row in [@buffer.getLastRow()..0]
      @activeFolds[row]?.forEach (fold) => @destroyFold(fold)

  rowRangeForCommentAtBufferRow: (row) ->
    return unless @tokenizedBuffer.lineForScreenRow(row).isComment()

    startRow = row
    for currentRow in [row-1..0]
      break if @buffer.isRowBlank(currentRow)
      break unless @tokenizedBuffer.lineForScreenRow(currentRow).isComment()
      startRow = currentRow
    endRow = row
    for currentRow in [row+1..@buffer.getLastRow()]
      break if @buffer.isRowBlank(currentRow)
      break unless @tokenizedBuffer.lineForScreenRow(currentRow).isComment()
      endRow = currentRow
    return [startRow, endRow] if startRow isnt endRow

  foldBufferRow: (bufferRow) ->
    for currentRow in [bufferRow..0]
      rowRange = @rowRangeForCommentAtBufferRow(currentRow)
      rowRange ?= @languageMode.rowRangeForFoldAtBufferRow(currentRow)
      [startRow, endRow] = rowRange ? []
      continue unless startRow? and startRow <= bufferRow <= endRow
      fold = @largestFoldStartingAtBufferRow(startRow)
      continue if fold

      @createFold(startRow, endRow)

      return

  unfoldBufferRow: (bufferRow) ->
    @largestFoldContainingBufferRow(bufferRow)?.destroy()

  createFold: (startRow, endRow) ->
    return fold if fold = @foldFor(startRow, endRow)
    fold = new Fold(this, startRow, endRow)
    @registerFold(fold)

    unless @isFoldContainedByActiveFold(fold)
      bufferRange = new Range([startRow, 0], [endRow, @buffer.lineLengthForRow(endRow)])
      oldScreenRange = @screenLineRangeForBufferRange(bufferRange)

      lines = @buildLineForBufferRow(startRow)
      @lineMap.replaceScreenRows(oldScreenRange.start.row, oldScreenRange.end.row, lines)
      newScreenRange = @screenLineRangeForBufferRange(bufferRange)

      start = oldScreenRange.start.row
      end = oldScreenRange.end.row
      screenDelta = newScreenRange.end.row - oldScreenRange.end.row
      bufferDelta = 0
      @triggerChanged({ start, end, screenDelta, bufferDelta })

    fold

  isFoldContainedByActiveFold: (fold) ->
    for row, folds of @activeFolds
      for otherFold in folds
        return otherFold if fold != otherFold and fold.isContainedByFold(otherFold)

  foldFor: (startRow, endRow) ->
    _.find @activeFolds[startRow] ? [], (fold) ->
      fold.startRow == startRow and fold.endRow == endRow

  destroyFold: (fold) ->
    @unregisterFold(fold.startRow, fold)

    unless @isFoldContainedByActiveFold(fold)
      { startRow, endRow } = fold
      bufferRange = new Range([startRow, 0], [endRow, @buffer.lineLengthForRow(endRow)])
      oldScreenRange = @screenLineRangeForBufferRange(bufferRange)
      lines = @buildLinesForBufferRows(startRow, endRow)
      @lineMap.replaceScreenRows(oldScreenRange.start.row, oldScreenRange.end.row, lines)
      newScreenRange = @screenLineRangeForBufferRange(bufferRange)

      start = oldScreenRange.start.row
      end = oldScreenRange.end.row
      screenDelta = newScreenRange.end.row - oldScreenRange.end.row
      bufferDelta = 0

      @triggerChanged({ start, end, screenDelta, bufferDelta })

  destroyFoldsContainingBufferRow: (bufferRow) ->
    for row, folds of @activeFolds
      for fold in new Array(folds...)
        fold.destroy() if fold.getBufferRange().containsRow(bufferRow)

  registerFold: (fold) ->
    @activeFolds[fold.startRow] ?= []
    @activeFolds[fold.startRow].push(fold)
    @foldsById[fold.id] = fold

  unregisterFold: (bufferRow, fold) ->
    folds = @activeFolds[bufferRow]
    _.remove(folds, fold)
    delete @foldsById[fold.id]
    delete @activeFolds[bufferRow] if folds.length == 0

  largestFoldStartingAtBufferRow: (bufferRow) ->
    return unless folds = @activeFolds[bufferRow]
    (folds.sort (a, b) -> b.endRow - a.endRow)[0]

  largestFoldStartingAtScreenRow: (screenRow) ->
    @largestFoldStartingAtBufferRow(@bufferRowForScreenRow(screenRow))

  largestFoldContainingBufferRow: (bufferRow) ->
    largestFold = null
    for currentBufferRow in [bufferRow..0]
      if fold = @largestFoldStartingAtBufferRow(currentBufferRow)
        largestFold = fold if fold.endRow >= bufferRow
    largestFold

  screenLineRangeForBufferRange: (bufferRange) ->
    @expandScreenRangeToLineEnds(
      @lineMap.screenRangeForBufferRange(
        @expandBufferRangeToLineEnds(bufferRange)))

  screenRowForBufferRow: (bufferRow) ->
    @lineMap.screenPositionForBufferPosition([bufferRow, 0]).row

  lastScreenRowForBufferRow: (bufferRow) ->
    @lineMap.screenPositionForBufferPosition([bufferRow, Infinity]).row

  bufferRowForScreenRow: (screenRow) ->
    @lineMap.bufferPositionForScreenPosition([screenRow, 0]).row

  screenRangeForBufferRange: (bufferRange) ->
    @lineMap.screenRangeForBufferRange(bufferRange)

  bufferRangeForScreenRange: (screenRange) ->
    @lineMap.bufferRangeForScreenRange(screenRange)

  lineCount: ->
    @lineMap.screenLineCount()

  getLastRow: ->
    @lineCount() - 1

  maxLineLength: ->
    @lineMap.maxScreenLineLength

  screenPositionForBufferPosition: (position, options) ->
    @lineMap.screenPositionForBufferPosition(position, options)

  bufferPositionForScreenPosition: (position, options) ->
    @lineMap.bufferPositionForScreenPosition(position, options)

  scopesForBufferPosition: (bufferPosition) ->
    @tokenizedBuffer.scopesForPosition(bufferPosition)

  # Public: Retrieves the current tab length.
  #
  # Returns a {Number}.
  getTabLength: ->
    @tokenizedBuffer.getTabLength()

  # Public: Specifies the tab length.
  #
  # tabLength - A {Number} that defines the new tab length.
  setTabLength: (tabLength) ->
    @tokenizedBuffer.setTabLength(tabLength)

  clipScreenPosition: (position, options) ->
    @lineMap.clipScreenPosition(position, options)

  handleBufferChange: (e) ->
    allFolds = [] # Folds can modify @activeFolds, so first make sure we have a stable array of folds
    allFolds.push(folds...) for row, folds of @activeFolds
    fold.handleBufferChange(e) for fold in allFolds

  handleTokenizedBufferChange: (tokenizedBufferChange) =>
    if bufferChange = tokenizedBufferChange.bufferChange
      @handleBufferChange(bufferChange)
      bufferDelta = bufferChange.newRange.end.row - bufferChange.oldRange.end.row

    tokenizedBufferStart = @bufferRowForScreenRow(@screenRowForBufferRow(tokenizedBufferChange.start))
    tokenizedBufferEnd = tokenizedBufferChange.end
    tokenizedBufferDelta = tokenizedBufferChange.delta

    start = @screenRowForBufferRow(tokenizedBufferStart)
    end = @lastScreenRowForBufferRow(tokenizedBufferEnd)
    newScreenLines = @buildLinesForBufferRows(tokenizedBufferStart, tokenizedBufferEnd + tokenizedBufferDelta)
    @lineMap.replaceScreenRows(start, end, newScreenLines)
    screenDelta = @lastScreenRowForBufferRow(tokenizedBufferEnd + tokenizedBufferDelta) - end

    changeEvent = { start, end, screenDelta, bufferDelta }
    if bufferChange
      @pauseMarkerObservers()
      @pendingChangeEvent = changeEvent
    else
      @triggerChanged(changeEvent, false)

  handleMarkersUpdated: =>
    event = @pendingChangeEvent
    @pendingChangeEvent = null
    @triggerChanged(event, false)

  buildLineForBufferRow: (bufferRow) ->
    @buildLinesForBufferRows(bufferRow, bufferRow)

  buildLinesForBufferRows: (startBufferRow, endBufferRow) ->
    lineFragments = []
    startBufferColumn = null
    currentBufferRow = startBufferRow
    currentScreenLineLength = 0

    startBufferColumn = 0
    while currentBufferRow <= endBufferRow
      screenLine = @tokenizedBuffer.lineForScreenRow(currentBufferRow)

      if fold = @largestFoldStartingAtBufferRow(currentBufferRow)
        screenLine = screenLine.copy()
        screenLine.fold = fold
        screenLine.bufferRows = fold.getBufferRowCount()
        lineFragments.push(screenLine)
        currentBufferRow = fold.endRow + 1
        continue

      startBufferColumn ?= 0
      screenLine = screenLine.softWrapAt(startBufferColumn)[1] if startBufferColumn > 0
      wrapScreenColumn = @findWrapColumn(screenLine.text, @softWrapColumn)
      if wrapScreenColumn?
        screenLine = screenLine.softWrapAt(wrapScreenColumn)[0]
        screenLine.screenDelta = new Point(1, 0)
        startBufferColumn += wrapScreenColumn
      else
        currentBufferRow++
        startBufferColumn = 0

      lineFragments.push(screenLine)

    lineFragments

  findWrapColumn: (line, softWrapColumn) ->
    return unless line.length > softWrapColumn

    if /\s/.test(line[softWrapColumn])
      # search forward for the start of a word past the boundary
      for column in [softWrapColumn..line.length]
        return column if /\S/.test(line[column])
      return line.length
    else
      # search backward for the start of the word on the boundary
      for column in [softWrapColumn..0]
        return column + 1 if /\s/.test(line[column])
      return softWrapColumn

  expandScreenRangeToLineEnds: (screenRange) ->
    screenRange = Range.fromObject(screenRange)
    { start, end } = screenRange
    new Range([start.row, 0], [end.row, @lineMap.lineForScreenRow(end.row).text.length])

  expandBufferRangeToLineEnds: (bufferRange) ->
    bufferRange = Range.fromObject(bufferRange)
    { start, end } = bufferRange
    new Range([start.row, 0], [end.row, Infinity])

  rangeForAllLines: ->
    new Range([0, 0], @clipScreenPosition([Infinity, Infinity]))

  getMarker: (id) ->
    @markers[id] ? new DisplayBufferMarker({id, displayBuffer: this})

  getMarkers: ->
    _.values(@markers)

  markScreenRange: (args...) ->
    bufferRange = @bufferRangeForScreenRange(args.shift())
    @markBufferRange(bufferRange, args...)

  markBufferRange: (args...) ->
    @buffer.markRange(args...)

  markScreenPosition: (screenPosition, options) ->
    @markBufferPosition(@bufferPositionForScreenPosition(screenPosition), options)

  markBufferPosition: (bufferPosition, options) ->
    @buffer.markPosition(bufferPosition, options)

  destroyMarker: (id) ->
    @buffer.destroyMarker(id)
    delete @markers[id]

  getMarkerScreenRange: (id) ->
    @getMarker(id).getScreenRange()

  setMarkerScreenRange: (id, screenRange, options) ->
    @getMarker(id).setScreenRange(screenRange, options)

  getMarkerBufferRange: (id) ->
    @getMarker(id).getBufferRange()

  setMarkerBufferRange: (id, bufferRange, options) ->
    @getMarker(id).setBufferRange(bufferRange, options)

  getMarkerScreenPosition: (id) ->
    @getMarkerHeadScreenPosition(id)

  getMarkerBufferPosition: (id) ->
    @getMarkerHeadBufferPosition(id)

  getMarkerHeadScreenPosition: (id) ->
    @getMarker(id).getHeadScreenPosition()

  setMarkerHeadScreenPosition: (id, screenPosition, options) ->
    @getMarker(id).setHeadScreenPosition(screenPosition, options)

  getMarkerHeadBufferPosition: (id) ->
    @getMarker(id).getHeadBufferPosition()

  setMarkerHeadBufferPosition: (id, bufferPosition) ->
    @getMarker(id).setHeadBufferPosition(bufferPosition)

  getMarkerTailScreenPosition: (id) ->
    @getMarker(id).getTailScreenPosition()

  setMarkerTailScreenPosition: (id, screenPosition, options) ->
    @getMarker(id).setTailScreenPosition(screenPosition, options)

  getMarkerTailBufferPosition: (id) ->
    @getMarker(id).getTailBufferPosition()

  setMarkerTailBufferPosition: (id, bufferPosition) ->
    @getMarker(id).setTailBufferPosition(bufferPosition)

  placeMarkerTail: (id) ->
    @getMarker(id).placeTail()

  clearMarkerTail: (id) ->
    @getMarker(id).clearTail()

  isMarkerReversed: (id) ->
    @buffer.isMarkerReversed(id)

  observeMarker: (id, callback) ->
    @getMarker(id).observe(callback)

  pauseMarkerObservers: ->
    marker.pauseEvents() for marker in @getMarkers()

  resumeMarkerObservers: ->
    marker.resumeEvents() for marker in @getMarkers()

  refreshMarkerScreenPositions: ->
    for marker in @getMarkers()
      marker.notifyObservers(bufferChanged: false)

  destroy: ->
    @tokenizedBuffer.destroy()
    @buffer.off 'markers-updated', @handleMarkersUpdated

  logLines: (start, end) ->
    @lineMap.logLines(start, end)

  getDebugSnapshot: ->
    lines = ["Display Buffer:"]
    for screenLine, row in @lineMap.linesForScreenRows(0, @getLastRow())
        lines.push "#{row}: #{screenLine.text}"
    lines.join('\n')

_.extend DisplayBuffer.prototype, EventEmitter
