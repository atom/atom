_ = require 'underscore'
EventEmitter = require 'event-emitter'
LineMap = require 'line-map'
Point = require 'point'
Range = require 'range'

module.exports =
class LineWrapper
  constructor: (@maxLength, @lineFolder) ->
    @buildLineMap()
    @lineFolder.on 'change', (e) => @handleChange(e)

  setMaxLength: (@maxLength) ->
    oldRange = @rangeForAllLines()
    @buildLineMap()
    newRange = @rangeForAllLines()
    @trigger 'change', { oldRange, newRange }

  buildLineMap: ->
    @lineMap = new LineMap
    @lineMap.insertAtBufferRow 0, @buildScreenLinesForBufferRows(0, @lineFolder.lastRow())

  handleChange: (e) ->
    oldBufferRange = e.oldRange
    newBufferRange = e.newRange

    oldScreenRange = @lineMap.screenRangeForBufferRange(@expandBufferRangeToLineEnds(oldBufferRange))
    newScreenLines = @buildScreenLinesForBufferRows(newBufferRange.start.row, newBufferRange.end.row)
    @lineMap.replaceBufferRows oldBufferRange.start.row, oldBufferRange.end.row, newScreenLines
    newScreenRange = @lineMap.screenRangeForBufferRange(@expandBufferRangeToLineEnds(newBufferRange))

    @trigger 'change', { oldRange: oldScreenRange, newRange: newScreenRange }

  expandBufferRangeToLineEnds: (bufferRange) ->
    { start, end } = bufferRange
    new Range([start.row, 0], [end.row, @lineMap.lineForBufferRow(end.row).text.length])

  rangeForAllLines: ->
    endRow = @lineCount() - 1
    endColumn = @lineMap.lineForScreenRow(endRow).text.length
    new Range([0, 0], [endRow, endColumn])

  buildScreenLinesForBufferRows: (start, end) ->
    _(@lineFolder
      .linesForScreenRows(start, end)
      .map((screenLine) => @wrapScreenLine(screenLine))).flatten()

  wrapScreenLine: (screenLine, startColumn=0) ->
    screenLines = []
    splitColumn = @findSplitColumn(screenLine.text)

    if splitColumn == 0 or splitColumn == screenLine.text.length
      screenLines.push screenLine
      endColumn = startColumn + screenLine.text.length
    else
      [leftHalf, rightHalf] = screenLine.splitAt(splitColumn)
      leftHalf.screenDelta = new Point(1, 0)
      screenLines.push leftHalf
      endColumn = startColumn + leftHalf.text.length
      screenLines.push @wrapScreenLine(rightHalf, endColumn)...

    _.extend(screenLines[0], {startColumn, endColumn})
    screenLines

  findSplitColumn: (line) ->
    return line.length unless line.length > @maxLength

    if /\s/.test(line[@maxLength])
      # search forward for the start of a word past the boundary
      for column in [@maxLength..line.length]
        return column if /\S/.test(line[column])
      return line.length
    else
      # search backward for the start of the word on the boundary
      for column in [@maxLength..0]
        return column + 1 if /\s/.test(line[column])
      return @maxLength

  screenPositionForBufferPosition: (bufferPosition, eagerWrap=true) ->
    @lineMap.screenPositionForBufferPosition(
      @lineFolder.screenPositionForBufferPosition(bufferPosition),
      eagerWrap)

  bufferPositionForScreenPosition: (screenPosition) ->
    @lineFolder.bufferPositionForScreenPosition(
      @lineMap.bufferPositionForScreenPosition(screenPosition))

  screenRangeForBufferRange: (bufferRange) ->
    @lineMap.screenRangeForBufferRange(
      @lineFolder.screenRangeForBufferRange(bufferRange))

  bufferRangeForScreenRange: (screenRange) ->
    @lineFolder.bufferRangeForScreenRange(
      @lineMap.bufferRangeForScreenRange(screenRange))

  clipScreenPosition: (screenPosition, eagerWrap=false) ->
    @lineMap.screenPositionForBufferPosition(
      @lineFolder.clipScreenPosition(
        @lineMap.bufferPositionForScreenPosition(
          @lineMap.clipScreenPosition(screenPosition, eagerWrap)
        ),
        eagerWrap
      )
    )

  lineForScreenRow: (screenRow) ->
    @linesForScreenRows(screenRow, screenRow)[0]

  linesForScreenRows: (startRow, endRow) ->
    @lineMap.linesForScreenRows(startRow, endRow)

  getLines: ->
    @linesForScreenRows(0, @lastRow())

  lineCount: ->
    @lineMap.screenLineCount()

  lastRow: ->
    @lineCount() - 1

  logLines: (start=0, end=@lineCount() - 1)->
    @lineMap.logLines(start, end)

_.extend(LineWrapper.prototype, EventEmitter)
