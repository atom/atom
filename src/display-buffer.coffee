_ = require 'underscore-plus'
{Emitter, Subscriber} = require 'emissary'
guid = require 'guid'
telepath = require 'telepath'
{Point, Range} = telepath
TokenizedBuffer = require './tokenized-buffer'
RowMap = require './row-map'
Fold = require './fold'
Token = require './token'
DisplayBufferMarker = require './display-buffer-marker'
ConfigObserver = require './config-observer'

# Private:
module.exports =
class DisplayBuffer
  Emitter.includeInto(this)
  Subscriber.includeInto(this)
  _.extend @prototype, ConfigObserver

  @acceptsDocuments: true
  atom.deserializers.add(this)
  @version: 2

  @deserialize: (state) -> new this(state)

  constructor: (optionsOrState) ->
    if optionsOrState instanceof telepath.Document
      @state = optionsOrState
      @id = @state.get('id')
      @tokenizedBuffer = atom.deserializers.deserialize(@state.get('tokenizedBuffer'))
      @buffer = @tokenizedBuffer.buffer
    else
      {@buffer, softWrap, editorWidthInChars} = optionsOrState
      @id = guid.create().toString()
      @tokenizedBuffer = new TokenizedBuffer(optionsOrState)
      @state = atom.site.createDocument
        deserializer: @constructor.name
        version: @constructor.version
        id: @id
        tokenizedBuffer: @tokenizedBuffer.getState()
        softWrap: softWrap ? atom.config.get('editor.softWrap') ? false
        editorWidthInChars: editorWidthInChars

    @markers = {}
    @foldsByMarkerId = {}
    @updateAllScreenLines()
    @createFoldForMarker(marker) for marker in @buffer.findMarkers(@getFoldMarkerAttributes())
    @subscribe @tokenizedBuffer, 'grammar-changed', (grammar) => @emit 'grammar-changed', grammar
    @subscribe @tokenizedBuffer, 'changed', @handleTokenizedBufferChange
    @subscribe @buffer, 'markers-updated', @handleBufferMarkersUpdated
    @subscribe @buffer, 'marker-created', @handleBufferMarkerCreated

    @subscribe @state, 'changed', ({newValues}) =>
      if newValues.softWrap?
        @emit 'soft-wrap-changed', newValues.softWrap
        @updateWrappedScreenLines()

    @observeConfig 'editor.preferredLineLength', callNow: false, =>
      @updateWrappedScreenLines() if @getSoftWrap() and atom.config.get('editor.softWrapAtPreferredLineLength')

    @observeConfig 'editor.softWrapAtPreferredLineLength', callNow: false, =>
      @updateWrappedScreenLines() if @getSoftWrap()

  serialize: -> @state.clone()
  getState: -> @state

  copy: ->
    newDisplayBuffer = new DisplayBuffer({@buffer, tabLength: @getTabLength()})
    for marker in @findMarkers(displayBufferId: @id)
      marker.copy(displayBufferId: newDisplayBuffer.id)
    newDisplayBuffer

  updateAllScreenLines: ->
    @maxLineLength = 0
    @screenLines = []
    @rowMap = new RowMap
    @updateScreenLines(0, @buffer.getLineCount(), null, suppressChangeEvent: true)

  emitChanged: (eventProperties, refreshMarkers=true) ->
    if refreshMarkers
      @pauseMarkerObservers()
      @refreshMarkerScreenPositions()
    @emit 'changed', eventProperties
    @resumeMarkerObservers()

  updateWrappedScreenLines: ->
    start = 0
    end = @getLastRow()
    @updateAllScreenLines()
    screenDelta = @getLastRow() - end
    bufferDelta = 0
    @emitChanged({ start, end, screenDelta, bufferDelta })

  ### Public ###

  # Sets the visibility of the tokenized buffer.
  #
  # visible - A {Boolean} indicating of the tokenized buffer is shown
  setVisible: (visible) -> @tokenizedBuffer.setVisible(visible)

  setSoftWrap: (softWrap) -> @state.set('softWrap', softWrap)

  getSoftWrap: -> @state.get('softWrap')

  # Set the number of characters that fit horizontally in the editor.
  #
  # editorWidthInChars - A {Number} of characters.
  setEditorWidthInChars: (editorWidthInChars) ->
    previousWidthInChars = @state.get('editorWidthInChars')
    @state.set('editorWidthInChars', editorWidthInChars)
    if editorWidthInChars isnt previousWidthInChars and @getSoftWrap()
      @updateWrappedScreenLines()

  getSoftWrapColumn: ->
    editorWidthInChars = @state.get('editorWidthInChars')
    if atom.config.get('editor.softWrapAtPreferredLineLength')
      Math.min(editorWidthInChars, atom.config.getPositiveInt('editor.preferredLineLength', editorWidthInChars))
    else
      editorWidthInChars

  # Gets the screen line for the given screen row.
  #
  # screenRow - A {Number} indicating the screen row.
  #
  # Returns a {ScreenLine}.
  lineForRow: (row) ->
    @screenLines[row]

  # Gets the screen lines for the given screen row range.
  #
  # startRow - A {Number} indicating the beginning screen row.
  # endRow - A {Number} indicating the ending screen row.
  #
  # Returns an {Array} of {ScreenLine}s.
  linesForRows: (startRow, endRow) ->
    @screenLines[startRow..endRow]

  # Gets all the screen lines.
  #
  # Returns an {Array} of {ScreenLines}s.
  getLines: ->
    new Array(@screenLines...)

  # Given starting and ending screen rows, this returns an array of the
  # buffer rows corresponding to every screen row in the range
  #
  # startScreenRow - The screen row {Number} to start at
  # endScreenRow - The screen row {Number} to end at (default: the last screen row)
  #
  # Returns an {Array} of buffer rows as {Numbers}s.
  bufferRowsForScreenRows: (startScreenRow, endScreenRow) ->
    for screenRow in [startScreenRow..endScreenRow]
      @rowMap.bufferRowRangeForScreenRow(screenRow)[0]

  # Creates a new fold between two row numbers.
  #
  # startRow - The row {Number} to start folding at
  # endRow - The row {Number} to end the fold
  #
  # Returns the new {Fold}.
  createFold: (startRow, endRow) ->
    foldMarker =
      @findFoldMarker({startRow, endRow}) ?
        @buffer.markRange([[startRow, 0], [endRow, Infinity]], @getFoldMarkerAttributes())
    @foldForMarker(foldMarker)

  isFoldedAtBufferRow: (bufferRow) ->
    @largestFoldContainingBufferRow(bufferRow)?

  isFoldedAtScreenRow: (screenRow) ->
    @largestFoldContainingBufferRow(@bufferRowForScreenRow(screenRow))?

  # Destroys the fold with the given id
  destroyFoldWithId: (id) ->
    @foldsByMarkerId[id]?.destroy()

  # Removes any folds found that contain the given buffer row.
  #
  # bufferRow - The buffer row {Number} to check against
  destroyFoldsContainingBufferRow: (bufferRow) ->
    fold.destroy() for fold in @foldsContainingBufferRow(bufferRow)

  # Given a buffer row, this returns the largest fold that starts there.
  #
  # Largest is defined as the fold whose difference between its start and end points
  # are the greatest.
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
    for marker in @findFoldMarkers(startRow: bufferRow)
      @foldForMarker(marker)

  # Given a screen row, this returns the largest fold that starts there.
  #
  # Largest is defined as the fold whose difference between its start and end points
  # are the greatest.
  #
  # screenRow - A {Number} indicating the screen row
  #
  # Returns a {Fold}.
  largestFoldStartingAtScreenRow: (screenRow) ->
    @largestFoldStartingAtBufferRow(@bufferRowForScreenRow(screenRow))

  # Given a buffer row, this returns the largest fold that includes it.
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
    for marker in @findFoldMarkers(intersectsRow: bufferRow)
      @foldForMarker(marker)

  # Given a buffer row, this converts it into a screen row.
  #
  # bufferRow - A {Number} representing a buffer row
  #
  # Returns a {Number}.
  screenRowForBufferRow: (bufferRow) ->
    @rowMap.screenRowRangeForBufferRow(bufferRow)[0]

  lastScreenRowForBufferRow: (bufferRow) ->
    @rowMap.screenRowRangeForBufferRow(bufferRow)[1] - 1

  # Given a screen row, this converts it into a buffer row.
  #
  # screenRow - A {Number} representing a screen row
  #
  # Returns a {Number}.
  bufferRowForScreenRow: (screenRow) ->
    @rowMap.bufferRowRangeForScreenRow(screenRow)[0]

  # Given a buffer range, this converts it into a screen position.
  #
  # bufferRange - The {Range} to convert
  #
  # Returns a {Range}.
  screenRangeForBufferRange: (bufferRange) ->
    bufferRange = Range.fromObject(bufferRange)
    start = @screenPositionForBufferPosition(bufferRange.start)
    end = @screenPositionForBufferPosition(bufferRange.end)
    new Range(start, end)

  # Given a screen range, this converts it into a buffer position.
  #
  # screenRange - The {Range} to convert
  #
  # Returns a {Range}.
  bufferRangeForScreenRange: (screenRange) ->
    screenRange = Range.fromObject(screenRange)
    start = @bufferPositionForScreenPosition(screenRange.start)
    end = @bufferPositionForScreenPosition(screenRange.end)
    new Range(start, end)

  # Gets the number of screen lines.
  #
  # Returns a {Number}.
  getLineCount: ->
    @screenLines.length

  # Gets the number of the last screen line.
  #
  # Returns a {Number}.
  getLastRow: ->
    @getLineCount() - 1

  # Gets the length of the longest screen line.
  #
  # Returns a {Number}.
  getMaxLineLength: ->
    @maxLineLength

  # Given a buffer position, this converts it into a screen position.
  #
  # bufferPosition - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - A hash of options with the following keys:
  #           wrapBeyondNewlines:
  #           wrapAtSoftNewlines:
  #
  # Returns a {Point}.
  screenPositionForBufferPosition: (bufferPosition, options) ->
    { row, column } = @buffer.clipPosition(bufferPosition)
    [startScreenRow, endScreenRow] = @rowMap.screenRowRangeForBufferRow(row)
    for screenRow in [startScreenRow...endScreenRow]
      unless screenLine = @screenLines[screenRow]
        throw new Error("No screen line exists for screen row #{screenRow}, converted from buffer position (#{row}, #{column})")

      maxBufferColumn = screenLine.getMaxBufferColumn()
      if screenLine.isSoftWrapped() and column > maxBufferColumn
        continue
      else
        if column <= maxBufferColumn
          screenColumn = screenLine.screenColumnForBufferColumn(column)
        else
          screenColumn = Infinity
        break

    new Point(screenRow, screenColumn)
    @clipScreenPosition([screenRow, screenColumn], options)

  # Given a buffer position, this converts it into a screen position.
  #
  # screenPosition - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - A hash of options with the following keys:
  #           wrapBeyondNewlines:
  #           wrapAtSoftNewlines:
  #
  # Returns a {Point}.
  bufferPositionForScreenPosition: (screenPosition, options) ->
    { row, column } = @clipScreenPosition(Point.fromObject(screenPosition), options)
    [bufferRow] = @rowMap.bufferRowRangeForScreenRow(row)
    new Point(bufferRow, @screenLines[row].bufferColumnForScreenColumn(column))

  # Retrieves the grammar's token scopes for a buffer position.
  #
  # bufferPosition - A {Point} in the {TextBuffer}
  #
  # Returns an {Array} of {String}s.
  scopesForBufferPosition: (bufferPosition) ->
    @tokenizedBuffer.scopesForPosition(bufferPosition)

  bufferRangeForScopeAtPosition: (selector, position) ->
    @tokenizedBuffer.bufferRangeForScopeAtPosition(selector, position)

  # Retrieves the grammar's token for a buffer position.
  #
  # bufferPosition - A {Point} in the {TextBuffer}.
  #
  # Returns a {Token}.
  tokenForBufferPosition: (bufferPosition) ->
    @tokenizedBuffer.tokenForPosition(bufferPosition)

  # Retrieves the current tab length.
  #
  # Returns a {Number}.
  getTabLength: ->
    @tokenizedBuffer.getTabLength()

  # Specifies the tab length.
  #
  # tabLength - A {Number} that defines the new tab length.
  setTabLength: (tabLength) ->
    @tokenizedBuffer.setTabLength(tabLength)

  # Get the grammar for this buffer.
  #
  # Returns the current {TextMateGrammar} or the {NullGrammar}.
  getGrammar: ->
    @tokenizedBuffer.grammar

  # Sets the grammar for the buffer.
  #
  # grammar - Sets the new grammar rules
  setGrammar: (grammar) ->
    @tokenizedBuffer.setGrammar(grammar)

  # Reloads the current grammar.
  reloadGrammar: ->
    @tokenizedBuffer.reloadGrammar()

  # Given a position, this clips it to a real position.
  #
  # For example, if `position`'s row exceeds the row count of the buffer,
  # or if its column goes beyond a line's length, this "sanitizes" the value
  # to a real position.
  #
  # position - The {Point} to clip
  # options - A hash with the following values:
  #           wrapBeyondNewlines: if `true`, continues wrapping past newlines
  #           wrapAtSoftNewlines: if `true`, continues wrapping past soft newlines
  #           screenLine: if `true`, indicates that you're using a line number, not a row number
  #
  # Returns the new, clipped {Point}. Note that this could be the same as `position` if no clipping was performed.
  clipScreenPosition: (screenPosition, options={}) ->
    { wrapBeyondNewlines, wrapAtSoftNewlines } = options
    { row, column } = Point.fromObject(screenPosition)

    if row < 0
      row = 0
      column = 0
    else if row > @getLastRow()
      row = @getLastRow()
      column = Infinity
    else if column < 0
      column = 0

    screenLine = @screenLines[row]
    maxScreenColumn = screenLine.getMaxScreenColumn()

    if screenLine.isSoftWrapped() and column >= maxScreenColumn
      if wrapAtSoftNewlines
        row++
        column = 0
      else
        column = screenLine.clipScreenColumn(maxScreenColumn - 1)
    else if wrapBeyondNewlines and column > maxScreenColumn and row < @getLastRow()
      row++
      column = 0
    else
      column = screenLine.clipScreenColumn(column, options)
    new Point(row, column)

  ### Public ###

  # Given a line, finds the point where it would wrap.
  #
  # line - The {String} to check
  # softWrapColumn - The {Number} where you want soft wrapping to occur
  #
  # Returns a {Number} representing the `line` position where the wrap would take place.
  # Returns `null` if a wrap wouldn't occur.
  findWrapColumn: (line, softWrapColumn=@getSoftWrapColumn()) ->
    return unless @getSoftWrap()
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

  # Calculates a {Range} representing the start of the {TextBuffer} until the end.
  #
  # Returns a {Range}.
  rangeForAllLines: ->
    new Range([0, 0], @clipScreenPosition([Infinity, Infinity]))

  # Retrieves a {DisplayBufferMarker} based on its id.
  #
  # id - A {Number} representing a marker id
  #
  # Returns the {DisplayBufferMarker} (if it exists).
  getMarker: (id) ->
    unless marker = @markers[id]
      if bufferMarker = @buffer.getMarker(id)
        marker = new DisplayBufferMarker({bufferMarker, displayBuffer: this})
        @markers[id] = marker
    marker

  # Retrieves the active markers in the buffer.
  #
  # Returns an {Array} of existing {DisplayBufferMarker}s.
  getMarkers: ->
    @buffer.getMarkers().map ({id}) => @getMarker(id)

  getMarkerCount: ->
    @buffer.getMarkerCount()

  # Constructs a new marker at the given screen range.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {StringMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markScreenRange: (args...) ->
    bufferRange = @bufferRangeForScreenRange(args.shift())
    @markBufferRange(bufferRange, args...)

  # Constructs a new marker at the given buffer range.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {StringMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markBufferRange: (args...) ->
    @getMarker(@buffer.markRange(args...).id)

  # Constructs a new marker at the given screen position.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {StringMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markScreenPosition: (screenPosition, options) ->
    @markBufferPosition(@bufferPositionForScreenPosition(screenPosition), options)

  # Constructs a new marker at the given buffer position.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {StringMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markBufferPosition: (bufferPosition, options) ->
    @getMarker(@buffer.markPosition(bufferPosition, options).id)

  # Removes the marker with the given id.
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
    attributes = @translateToStringMarkerAttributes(attributes)
    @buffer.findMarkers(attributes).map (stringMarker) => @getMarker(stringMarker.id)

  translateToStringMarkerAttributes: (attributes) ->
    stringMarkerAttributes = {}
    for key, value of attributes
      switch key
        when 'startBufferRow'
          key = 'startRow'
        when 'endBufferRow'
          key = 'endRow'
        when 'containsBufferRange'
          key = 'containsRange'
        when 'containsBufferPosition'
          key = 'containsPosition'
      stringMarkerAttributes[key] = value
    stringMarkerAttributes

  findFoldMarker: (attributes) ->
    @findFoldMarkers(attributes)[0]

  findFoldMarkers: (attributes) ->
    @buffer.findMarkers(@getFoldMarkerAttributes(attributes))

  getFoldMarkerAttributes: (attributes={}) ->
    _.extend(attributes, class: 'fold', displayBufferId: @id)

  pauseMarkerObservers: ->
    marker.pauseEvents() for marker in @getMarkers()

  resumeMarkerObservers: ->
    marker.resumeEvents() for marker in @getMarkers()
    @emit 'markers-updated'

  refreshMarkerScreenPositions: ->
    for marker in @getMarkers()
      marker.notifyObservers(textChanged: false)

  destroy: ->
    marker.unsubscribe() for marker in @getMarkers()
    @tokenizedBuffer.destroy()
    @unsubscribe()
    @unobserveConfig()

  logLines: (start=0, end=@getLastRow())->
    for row in [start..end]
      line = @lineForRow(row).text
      console.log row, line, line.length

  getDebugSnapshot: ->
    lines = ["Display Buffer:"]
    for screenLine, row in @linesForRows(0, @getLastRow())
      lines.push "#{row}: #{screenLine.text}"
    lines.join('\n')

  ### Internal ###

  handleTokenizedBufferChange: (tokenizedBufferChange) =>
    {start, end, delta, bufferChange} = tokenizedBufferChange
    @updateScreenLines(start, end + 1, delta, delayChangeEvent: bufferChange?)

  updateScreenLines: (startBufferRow, endBufferRow, bufferDelta=0, options={}) ->
    startBufferRow = @rowMap.bufferRowRangeForBufferRow(startBufferRow)[0]
    startScreenRow = @rowMap.screenRowRangeForBufferRow(startBufferRow)[0]
    endScreenRow = @rowMap.screenRowRangeForBufferRow(endBufferRow - 1)[1]

    @rowMap.applyBufferDelta(startBufferRow, bufferDelta)

    { newScreenLines, newMappings } = @buildScreenLines(startBufferRow, endBufferRow + bufferDelta)
    @screenLines[startScreenRow...endScreenRow] = newScreenLines
    screenDelta = newScreenLines.length - (endScreenRow - startScreenRow)
    @rowMap.applyScreenDelta(startScreenRow, screenDelta)
    @rowMap.mapBufferRowRange(mapping...) for mapping in newMappings
    @findMaxLineLength(startScreenRow, endScreenRow, newScreenLines)

    return if options.suppressChangeEvent

    changeEvent =
      start: startScreenRow
      end: endScreenRow - 1
      screenDelta: screenDelta
      bufferDelta: bufferDelta

    if options.delayChangeEvent
      @pauseMarkerObservers()
      @pendingChangeEvent = changeEvent
    else
      @emitChanged(changeEvent, options.refreshMarkers)

  buildScreenLines: (startBufferRow, endBufferRow) ->
    newScreenLines = []
    newMappings = []
    pendingIsoMapping = null

    pushNewMapping = (startBufferRow, endBufferRow, screenRows) ->
      if endBufferRow - startBufferRow == screenRows
        if pendingIsoMapping
          pendingIsoMapping[1] = endBufferRow
        else
          pendingIsoMapping = [startBufferRow, endBufferRow]
      else
        clearPendingIsoMapping()
        newMappings.push([startBufferRow, endBufferRow, screenRows])

    clearPendingIsoMapping = ->
      if pendingIsoMapping
        [isoStart, isoEnd] = pendingIsoMapping
        pendingIsoMapping.push(isoEnd - isoStart)
        newMappings.push(pendingIsoMapping)
        pendingIsoMapping = null

    bufferRow = startBufferRow
    while bufferRow < endBufferRow
      tokenizedLine = @tokenizedBuffer.lineForScreenRow(bufferRow)

      if fold = @largestFoldStartingAtBufferRow(bufferRow)
        foldLine = tokenizedLine.copy()
        foldLine.fold = fold
        newScreenLines.push(foldLine)
        pushNewMapping(bufferRow, fold.getEndRow() + 1, 1)
        bufferRow = fold.getEndRow() + 1
      else
        softWraps = 0
        while wrapScreenColumn = @findWrapColumn(tokenizedLine.text)
          [wrappedLine, tokenizedLine] = tokenizedLine.softWrapAt(wrapScreenColumn)
          newScreenLines.push(wrappedLine)
          softWraps++
        newScreenLines.push(tokenizedLine)
        pushNewMapping(bufferRow, bufferRow + 1, softWraps + 1)
        bufferRow++
    clearPendingIsoMapping()

    { newScreenLines, newMappings }

  findMaxLineLength: (startScreenRow, endScreenRow, newScreenLines) ->
    if startScreenRow <= @longestScreenRow < endScreenRow
      @longestScreenRow = 0
      @maxLineLength = 0
      maxLengthCandidatesStartRow = 0
      maxLengthCandidates = @screenLines
    else
      maxLengthCandidatesStartRow = startScreenRow
      maxLengthCandidates = newScreenLines

    for screenLine, screenRow in maxLengthCandidates
      length = screenLine.text.length
      if length > @maxLineLength
        @longestScreenRow = maxLengthCandidatesStartRow + screenRow
        @maxLineLength = length

  handleBufferMarkersUpdated: =>
    if event = @pendingChangeEvent
      @pendingChangeEvent = null
      @emitChanged(event, false)

  handleBufferMarkerCreated: (marker) =>
    @createFoldForMarker(marker) if marker.matchesAttributes(@getFoldMarkerAttributes())
    @emit 'marker-created', @getMarker(marker.id)

  createFoldForMarker: (marker) ->
    new Fold(this, marker)

  foldForMarker: (marker) ->
    @foldsByMarkerId[marker.id]
