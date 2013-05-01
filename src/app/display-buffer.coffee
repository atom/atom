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
Subscriber = require 'subscriber'

module.exports =
class DisplayBuffer
  @idCounter: 1
  lineMap: null
  tokenizedBuffer: null
  markers: null
  foldsByMarkerId: null

  ###
  # Internal #
  ###

  constructor: (@buffer, options={}) ->
    @id = @constructor.idCounter++
    @tokenizedBuffer = new TokenizedBuffer(@buffer, options)
    @softWrapColumn = options.softWrapColumn ? Infinity
    @markers = {}
    @foldsByMarkerId = {}
    @buildLineMap()
    @tokenizedBuffer.on 'grammar-changed', (grammar) => @trigger 'grammar-changed', grammar
    @tokenizedBuffer.on 'changed', @handleTokenizedBufferChange
    @subscribe @buffer, 'markers-updated', @handleMarkersUpdated
    @subscribe @buffer, 'marker-created', @handleMarkerCreated

  buildLineMap: ->
    @lineMap = new LineMap
    @lineMap.insertAtScreenRow 0, @buildLinesForBufferRows(0, @buffer.getLastRow())

  triggerChanged: (eventProperties, refreshMarkers=true) ->
    if refreshMarkers
      @pauseMarkerObservers()
      @refreshMarkerScreenPositions()
    @trigger 'changed', eventProperties
    @resumeMarkerObservers()

  ###
  # Public #
  ###

  setVisible: (visible) -> @tokenizedBuffer.setVisible(visible)

  # Public: Defines the limit at which the buffer begins to soft wrap text.
  #
  # softWrapColumn - A {Number} defining the soft wrap limit.
  setSoftWrapColumn: (@softWrapColumn) ->
    start = 0
    end = @getLastRow()
    @buildLineMap()
    screenDelta = @getLastRow() - end
    bufferDelta = 0
    @triggerChanged({ start, end, screenDelta, bufferDelta })

  # Public: Gets the screen line for the given screen row.
  #
  # screenRow - A {Number} indicating the screen row.
  #
  # Returns a {ScreenLine}.
  lineForRow: (row) ->
    @lineMap.lineForScreenRow(row)

  # Public: Gets the screen lines for the given screen row range.
  #
  # startRow - A {Number} indicating the beginning screen row.
  # endRow - A {Number} indicating the ending screen row.
  #
  # Returns an {Array} of {ScreenLine}s.
  linesForRows: (startRow, endRow) ->
    @lineMap.linesForScreenRows(startRow, endRow)

  # Public: Gets all the screen lines.
  #
  # Returns an {Array} of {ScreenLines}s.
  getLines: ->
    @lineMap.linesForScreenRows(0, @lineMap.lastScreenRow())


  # Public: Given starting and ending screen rows, this returns an array of the
  # buffer rows corresponding to every screen row in the range
  #
  # startRow - The screen row {Number} to start at
  # endRow - The screen row {Number} to end at (default: the last screen row)
  #
  # Returns an {Array} of buffer rows as {Numbers}s.
  bufferRowsForScreenRows: (startRow, endRow) ->
    @lineMap.bufferRowsForScreenRows(startRow, endRow)

  # Public: Creates a new fold between two row numbers.
  #
  # startRow - The row {Number} to start folding at
  # endRow - The row {Number} to end the fold
  #
  # Returns the new {Fold}.
  createFold: (startRow, endRow) ->
    foldMarker =
      @buffer.findMarker({class: 'fold', startRow, endRow}) ?
        @buffer.markRange([[startRow, 0], [endRow, Infinity]], class: 'fold')
    @foldForMarker(foldMarker)

  # Public: Removes any folds found that contain the given buffer row.
  #
  # bufferRow - The buffer row {Number} to check against
  destroyFoldsContainingBufferRow: (bufferRow) ->
    fold.destroy() for fold in @foldsContainingBufferRow(bufferRow)

  # Largest is defined as the fold whose difference between its start and end rows
  # is the greatest.
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns a {Fold} or null if none exists.
  largestFoldStartingAtBufferRow: (bufferRow) ->
    @foldsStartingAtBufferRow(bufferRow)[0]

  # Public: Given a buffer row, this returns all folds that start there.
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns an {Array} of {Fold}s.
  foldsStartingAtBufferRow: (bufferRow) ->
    for marker in @buffer.findMarkers(class: 'fold', startRow: bufferRow)
      @foldForMarker(marker)

  # Public: Given a screen row, this returns the largest fold that starts there.
  #
  # Largest is defined as the fold whose difference between its start and end points
  # are the greatest.
  #
  # screenRow - A {Number} indicating the screen row
  #
  # Returns a {Fold}.
  largestFoldStartingAtScreenRow: (screenRow) ->
    @largestFoldStartingAtBufferRow(@bufferRowForScreenRow(screenRow))

  # Public: Given a buffer row, this returns the largest fold that includes it.
  #
  # Largest is defined as the fold whose difference between its start and end rows
  # is the greatest.
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns a {Fold}.
  largestFoldContainingBufferRow: (bufferRow) ->
    @foldsContainingBufferRow(bufferRow)[0]

  # Public: Given a buffer row, this returns folds that include it.
  #
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns an {Array} of {Fold}s.
  foldsContainingBufferRow: (bufferRow) ->
    for marker in @buffer.findMarkers(class: 'fold', containsRow: bufferRow)
      @foldForMarker(marker)

  # Public: Given a buffer range, this converts it into a screen range.
  #
  # bufferRange - A {Range} consisting of buffer positions
  #
  # Returns a {Range}.
  screenLineRangeForBufferRange: (bufferRange) ->
    @expandScreenRangeToLineEnds(
      @lineMap.screenRangeForBufferRange(
        @expandBufferRangeToLineEnds(bufferRange)))

  # Public: Given a buffer row, this converts it into a screen row.
  #
  # bufferRow - A {Number} representing a buffer row
  #
  # Returns a {Number}.
  screenRowForBufferRow: (bufferRow) ->
    @lineMap.screenPositionForBufferPosition([bufferRow, 0]).row

  lastScreenRowForBufferRow: (bufferRow) ->
    @lineMap.screenPositionForBufferPosition([bufferRow, Infinity]).row

  # Public: Given a screen row, this converts it into a buffer row.
  #
  # screenRow - A {Number} representing a screen row
  #
  # Returns a {Number}.
  bufferRowForScreenRow: (screenRow) ->
    @lineMap.bufferPositionForScreenPosition([screenRow, 0]).row

  # Public: Given a buffer range, this converts it into a screen position.
  #
  # bufferRange - The {Range} to convert
  #
  # Returns a {Range}.
  screenRangeForBufferRange: (bufferRange) ->
    @lineMap.screenRangeForBufferRange(bufferRange)

  # Public: Given a screen range, this converts it into a buffer position.
  #
  # screenRange - The {Range} to convert
  #
  # Returns a {Range}.
  bufferRangeForScreenRange: (screenRange) ->
    @lineMap.bufferRangeForScreenRange(screenRange)

  # Public: Gets the number of lines in the buffer.
  #
  # Returns a {Number}.
  getLineCount: ->
    @lineMap.getScreenLineCount()

  # Public: Gets the number of the last row in the buffer.
  #
  # Returns a {Number}.
  getLastRow: ->
    @getLineCount() - 1

  # Public: Gets the length of the longest screen line.
  #
  # Returns a {Number}.
  maxLineLength: ->
    @lineMap.maxScreenLineLength

  # Public: Given a buffer position, this converts it into a screen position.
  #
  # bufferPosition - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - A hash of options with the following keys:
  #           :wrapBeyondNewlines -
  #           :wrapAtSoftNewlines -
  #
  # Returns a {Point}.
  screenPositionForBufferPosition: (position, options) ->
    @lineMap.screenPositionForBufferPosition(position, options)

  # Public: Given a buffer range, this converts it into a screen position.
  #
  # screenPosition - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - A hash of options with the following keys:
  #           :wrapBeyondNewlines -
  #           :wrapAtSoftNewlines -
  #
  # Returns a {Point}.
  bufferPositionForScreenPosition: (position, options) ->
    @lineMap.bufferPositionForScreenPosition(position, options)

  # Public: Retrieves the grammar's token scopes for a buffer position.
  #
  # bufferPosition - A {Point} in the {Buffer}
  #
  # Returns an {Array} of {String}s.
  scopesForBufferPosition: (bufferPosition) ->
    @tokenizedBuffer.scopesForPosition(bufferPosition)

  # Public: Retrieves the grammar's token for a buffer position.
  #
  # bufferPosition - A {Point} in the {Buffer}.
  #
  # Returns a {Token}.
  tokenForBufferPosition: (bufferPosition) ->
    @tokenizedBuffer.tokenForPosition(bufferPosition)

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

  getGrammar: ->
    @tokenizedBuffer.grammar

  setGrammar: (grammar) ->
    @tokenizedBuffer.setGrammar(grammar)

  reloadGrammar: ->
    @tokenizedBuffer.reloadGrammar()

  # Public: Given a position, this clips it to a real position.
  #
  # For example, if `position`'s row exceeds the row count of the buffer,
  # or if its column goes beyond a line's length, this "sanitizes" the value
  # to a real position.
  #
  # position - The {Point} to clip
  # options - A hash with the following values:
  #           :wrapBeyondNewlines - if `true`, continues wrapping past newlines
  #           :wrapAtSoftNewlines - if `true`, continues wrapping past soft newlines
  #           :screenLine - if `true`, indicates that you're using a line number, not a row number
  #
  # Returns the new, clipped {Point}. Note that this could be the same as `position` if no clipping was performed.
  clipScreenPosition: (position, options) ->
    @lineMap.clipScreenPosition(position, options)

  ###
  # Internal #
  ###

  handleTokenizedBufferChange: (tokenizedBufferChange) =>
    {start, end, delta, bufferChange} = tokenizedBufferChange
    @updateScreenLines(start, end, delta, delayChangeEvent: bufferChange?)

  updateScreenLines: (startBufferRow, endBufferRow, bufferDelta, options={}) ->
    startBufferRow = @bufferRowForScreenRow(@screenRowForBufferRow(startBufferRow))
    newScreenLines = @buildLinesForBufferRows(startBufferRow, endBufferRow + bufferDelta)

    startScreenRow = @screenRowForBufferRow(startBufferRow)
    endScreenRow = @lastScreenRowForBufferRow(endBufferRow)

    @lineMap.replaceScreenRows(startScreenRow, endScreenRow, newScreenLines)

    changeEvent =
      start: startScreenRow
      end: endScreenRow
      screenDelta: @lastScreenRowForBufferRow(endBufferRow + bufferDelta) - endScreenRow
      bufferDelta: bufferDelta

    if options.delayChangeEvent
      @pauseMarkerObservers()
      @pendingChangeEvent = changeEvent
    else
      @triggerChanged(changeEvent, options.refreshMarkers)

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
        currentBufferRow = fold.getEndRow() + 1
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

  handleMarkersUpdated: =>
    event = @pendingChangeEvent
    @pendingChangeEvent = null
    @triggerChanged(event, false)

  handleMarkerCreated: (marker) =>
    new Fold(this, marker) if marker.matchesAttributes(class: 'fold')
    @trigger 'marker-created', @getMarker(marker.id)

  foldForMarker: (marker) ->
    @foldsByMarkerId[marker.id]

  ###
  # Public #
  ###

  # Public: Given a line, finds the point where it would wrap.
  #
  # line - The {String} to check
  # softWrapColumn - The {Number} where you want soft wrapping to occur
  #
  # Returns a {Number} representing the `line` position where the wrap would take place.
  # Returns `null` if a wrap wouldn't occur.
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

  # Public: Given a range in screen coordinates, this expands it to the start and end of a line
  #
  # screenRange - The {Range} to expand
  #
  # Returns a new {Range}.
  expandScreenRangeToLineEnds: (screenRange) ->
    screenRange = Range.fromObject(screenRange)
    { start, end } = screenRange
    new Range([start.row, 0], [end.row, @lineMap.lineForScreenRow(end.row).text.length])

  # Public: Given a range in buffer coordinates, this expands it to the start and end of a line
  #
  # screenRange - The {Range} to expand
  #
  # Returns a new {Range}.
  expandBufferRangeToLineEnds: (bufferRange) ->
    bufferRange = Range.fromObject(bufferRange)
    { start, end } = bufferRange
    new Range([start.row, 0], [end.row, Infinity])

  # Public: Calculates a {Range} representing the start of the {Buffer} until the end.
  #
  # Returns a {Range}.
  rangeForAllLines: ->
    new Range([0, 0], @clipScreenPosition([Infinity, Infinity]))

  # Public: Retrieves a {DisplayBufferMarker} based on its id.
  #
  # id - A {Number} representing a marker id
  #
  # Returns the {DisplayBufferMarker} (if it exists).
  getMarker: (id) ->
    @markers[id] ?= do =>
      if bufferMarker = @buffer.getMarker(id)
        new DisplayBufferMarker({bufferMarker, displayBuffer: this})

  # Public: Retrieves the active markers in the buffer.
  #
  # Returns an {Array} of existing {DisplayBufferMarker}s.
  getMarkers: ->
    _.values(@markers)

  # Public: Constructs a new marker at the given screen range.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {BufferMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markScreenRange: (args...) ->
    bufferRange = @bufferRangeForScreenRange(args.shift())
    @markBufferRange(bufferRange, args...)

  # Public: Constructs a new marker at the given buffer range.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {BufferMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markBufferRange: (args...) ->
    @getMarker(@buffer.markRange(args...).id)

  # Public: Constructs a new marker at the given screen position.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {BufferMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markScreenPosition: (screenPosition, options) ->
    @markBufferPosition(@bufferPositionForScreenPosition(screenPosition), options)

  # Public: Constructs a new marker at the given buffer position.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {BufferMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markBufferPosition: (bufferPosition, options) ->
    @getMarker(@buffer.markPosition(bufferPosition, options).id)

  # Public: Removes the marker with the given id.
  #
  # id - The {Number} of the ID to remove
  destroyMarker: (id) ->
    @buffer.destroyMarker(id)
    delete @markers[id]

  # Finds the first marker satisfying the given attributes
  #
  # Refer to {DisplayBuffer.findMarkers} for details.
  #
  # Returns a {DisplayBufferMarker} or null
  findMarker: (attributes) ->
    @findMarkers(attributes)[0]

  # Finds all valid markers satisfying the given attributes
  #
  # attributes - The attributes against which to compare the markers' attributes
  #   There are some reserved keys that match against derived marker properties:
  #   startBufferRow - The buffer row at which the marker starts
  #   endBufferRow - The buffer row at which the marker ends
  #
  # Returns an {Array} of {DisplayBufferMarker}s
  findMarkers: (attributes) ->
    { startBufferRow, endBufferRow, containsBufferRange, containsBufferRow } = attributes
    attributes.startRow = startBufferRow if startBufferRow?
    attributes.endRow = endBufferRow if endBufferRow?
    attributes.containsRange = containsBufferRange if containsBufferRange?
    attributes.containsRow = containsBufferRow if containsBufferRow?
    attributes = _.omit(attributes, ['startBufferRow', 'endBufferRow', 'containsBufferRange', 'containsBufferRow'])
    @buffer.findMarkers(attributes).map ({id}) => @getMarker(id)

  ###
  # Internal #
  ###

  pauseMarkerObservers: ->
    marker.pauseEvents() for marker in @getMarkers()

  resumeMarkerObservers: ->
    marker.resumeEvents() for marker in @getMarkers()

  refreshMarkerScreenPositions: ->
    for marker in @getMarkers()
      marker.notifyObservers(bufferChanged: false)

  destroy: ->
    @tokenizedBuffer.destroy()
    @unsubscribe()

  logLines: (start, end) ->
    @lineMap.logLines(start, end)

  getDebugSnapshot: ->
    lines = ["Display Buffer:"]
    for screenLine, row in @lineMap.linesForScreenRows(0, @getLastRow())
        lines.push "#{row}: #{screenLine.text}"
    lines.join('\n')

_.extend DisplayBuffer.prototype, EventEmitter
_.extend DisplayBuffer.prototype, Subscriber
