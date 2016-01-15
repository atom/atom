_ = require 'underscore-plus'
{CompositeDisposable, Emitter} = require 'event-kit'
{Point, Range} = require 'text-buffer'
TokenizedBuffer = require './tokenized-buffer'
RowMap = require './row-map'
Fold = require './fold'
Model = require './model'
Token = require './token'
Decoration = require './decoration'
LayerDecoration = require './layer-decoration'
TextEditorMarkerLayer = require './text-editor-marker-layer'

class BufferToScreenConversionError extends Error
  constructor: (@message, @metadata) ->
    super
    Error.captureStackTrace(this, BufferToScreenConversionError)

module.exports =
class DisplayBuffer extends Model
  verticalScrollMargin: 2
  horizontalScrollMargin: 6
  changeCount: 0
  softWrapped: null
  editorWidthInChars: null
  lineHeightInPixels: null
  defaultCharWidth: null
  height: null
  width: null
  didUpdateDecorationsEventScheduled: false
  updatedSynchronously: false

  @deserialize: (state, atomEnvironment) ->
    state.tokenizedBuffer = TokenizedBuffer.deserialize(state.tokenizedBuffer, atomEnvironment)
    state.foldsMarkerLayer = state.tokenizedBuffer.buffer.getMarkerLayer(state.foldsMarkerLayerId)
    state.config = atomEnvironment.config
    state.assert = atomEnvironment.assert
    state.grammarRegistry = atomEnvironment.grammars
    state.packageManager = atomEnvironment.packages
    new this(state)

  constructor: (params={}) ->
    super

    {
      tabLength, @editorWidthInChars, @tokenizedBuffer, @foldsMarkerLayer, buffer,
      ignoreInvisibles, @largeFileMode, @config, @assert, @grammarRegistry, @packageManager
    } = params

    @emitter = new Emitter
    @disposables = new CompositeDisposable

    @tokenizedBuffer ?= new TokenizedBuffer({
      tabLength, buffer, ignoreInvisibles, @largeFileMode, @config,
      @grammarRegistry, @packageManager, @assert
    })
    @buffer = @tokenizedBuffer.buffer
    @charWidthsByScope = {}
    @defaultMarkerLayer = new TextEditorMarkerLayer(this, @buffer.getDefaultMarkerLayer(), true)
    @customMarkerLayersById = {}
    @foldsByMarkerId = {}
    @decorationsById = {}
    @decorationsByMarkerId = {}
    @overlayDecorationsById = {}
    @layerDecorationsByMarkerLayerId = {}
    @decorationCountsByLayerId = {}
    @layerUpdateDisposablesByLayerId = {}

    @disposables.add @tokenizedBuffer.observeGrammar @subscribeToScopedConfigSettings
    @disposables.add @tokenizedBuffer.onDidChange @handleTokenizedBufferChange
    @disposables.add @buffer.onDidCreateMarker @didCreateDefaultLayerMarker

    @foldsMarkerLayer ?= @buffer.addMarkerLayer()
    folds = (new Fold(this, marker) for marker in @foldsMarkerLayer.getMarkers())
    @updateAllScreenLines()
    @decorateFold(fold) for fold in folds

  subscribeToScopedConfigSettings: =>
    @scopedConfigSubscriptions?.dispose()
    @scopedConfigSubscriptions = subscriptions = new CompositeDisposable

    scopeDescriptor = @getRootScopeDescriptor()

    oldConfigSettings = @configSettings
    @configSettings =
      scrollPastEnd: @config.get('editor.scrollPastEnd', scope: scopeDescriptor)
      softWrap: @config.get('editor.softWrap', scope: scopeDescriptor)
      softWrapAtPreferredLineLength: @config.get('editor.softWrapAtPreferredLineLength', scope: scopeDescriptor)
      softWrapHangingIndent: @config.get('editor.softWrapHangingIndent', scope: scopeDescriptor)
      preferredLineLength: @config.get('editor.preferredLineLength', scope: scopeDescriptor)

    subscriptions.add @config.onDidChange 'editor.softWrap', scope: scopeDescriptor, ({newValue}) =>
      @configSettings.softWrap = newValue
      @updateWrappedScreenLines()

    subscriptions.add @config.onDidChange 'editor.softWrapHangingIndent', scope: scopeDescriptor, ({newValue}) =>
      @configSettings.softWrapHangingIndent = newValue
      @updateWrappedScreenLines()

    subscriptions.add @config.onDidChange 'editor.softWrapAtPreferredLineLength', scope: scopeDescriptor, ({newValue}) =>
      @configSettings.softWrapAtPreferredLineLength = newValue
      @updateWrappedScreenLines() if @isSoftWrapped()

    subscriptions.add @config.onDidChange 'editor.preferredLineLength', scope: scopeDescriptor, ({newValue}) =>
      @configSettings.preferredLineLength = newValue
      @updateWrappedScreenLines() if @isSoftWrapped() and @config.get('editor.softWrapAtPreferredLineLength', scope: scopeDescriptor)

    subscriptions.add @config.observe 'editor.scrollPastEnd', scope: scopeDescriptor, (value) =>
      @configSettings.scrollPastEnd = value

    @updateWrappedScreenLines() if oldConfigSettings? and not _.isEqual(oldConfigSettings, @configSettings)

  serialize: ->
    deserializer: 'DisplayBuffer'
    id: @id
    softWrapped: @isSoftWrapped()
    editorWidthInChars: @editorWidthInChars
    tokenizedBuffer: @tokenizedBuffer.serialize()
    largeFileMode: @largeFileMode
    foldsMarkerLayerId: @foldsMarkerLayer.id

  copy: ->
    foldsMarkerLayer = @foldsMarkerLayer.copy()
    new DisplayBuffer({
      @buffer, tabLength: @getTabLength(), @largeFileMode, @config, @assert,
      @grammarRegistry, @packageManager, foldsMarkerLayer
    })

  updateAllScreenLines: ->
    @maxLineLength = 0
    @screenLines = []
    @rowMap = new RowMap
    @updateScreenLines(0, @buffer.getLineCount(), null, suppressChangeEvent: true)

  onDidChangeSoftWrapped: (callback) ->
    @emitter.on 'did-change-soft-wrapped', callback

  onDidChangeGrammar: (callback) ->
    @tokenizedBuffer.onDidChangeGrammar(callback)

  onDidTokenize: (callback) ->
    @tokenizedBuffer.onDidTokenize(callback)

  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  onDidChangeCharacterWidths: (callback) ->
    @emitter.on 'did-change-character-widths', callback

  onDidRequestAutoscroll: (callback) ->
    @emitter.on 'did-request-autoscroll', callback

  observeDecorations: (callback) ->
    callback(decoration) for decoration in @getDecorations()
    @onDidAddDecoration(callback)

  onDidAddDecoration: (callback) ->
    @emitter.on 'did-add-decoration', callback

  onDidRemoveDecoration: (callback) ->
    @emitter.on 'did-remove-decoration', callback

  onDidCreateMarker: (callback) ->
    @emitter.on 'did-create-marker', callback

  onDidUpdateMarkers: (callback) ->
    @emitter.on 'did-update-markers', callback

  onDidUpdateDecorations: (callback) ->
    @emitter.on 'did-update-decorations', callback

  emitDidChange: (eventProperties, refreshMarkers=true) ->
    @emitter.emit 'did-change', eventProperties
    if refreshMarkers
      @refreshMarkerScreenPositions()
    @emitter.emit 'did-update-markers'

  updateWrappedScreenLines: ->
    start = 0
    end = @getLastRow()
    @updateAllScreenLines()
    screenDelta = @getLastRow() - end
    bufferDelta = 0
    @emitDidChange({start, end, screenDelta, bufferDelta})

  # Sets the visibility of the tokenized buffer.
  #
  # visible - A {Boolean} indicating of the tokenized buffer is shown
  setVisible: (visible) -> @tokenizedBuffer.setVisible(visible)

  setUpdatedSynchronously: (@updatedSynchronously) ->

  getVerticalScrollMargin: ->
    maxScrollMargin = Math.floor(((@getHeight() / @getLineHeightInPixels()) - 1) / 2)
    Math.min(@verticalScrollMargin, maxScrollMargin)

  setVerticalScrollMargin: (@verticalScrollMargin) -> @verticalScrollMargin

  getHorizontalScrollMargin: -> Math.min(@horizontalScrollMargin, Math.floor(((@getWidth() / @getDefaultCharWidth()) - 1) / 2))
  setHorizontalScrollMargin: (@horizontalScrollMargin) -> @horizontalScrollMargin

  getHeight: ->
    @height

  setHeight: (@height) ->
    @height

  getWidth: ->
    @width

  setWidth: (newWidth) ->
    oldWidth = @width
    @width = newWidth
    @updateWrappedScreenLines() if newWidth isnt oldWidth and @isSoftWrapped()
    @width

  getLineHeightInPixels: -> @lineHeightInPixels
  setLineHeightInPixels: (@lineHeightInPixels) -> @lineHeightInPixels

  getKoreanCharWidth: -> @koreanCharWidth

  getHalfWidthCharWidth: -> @halfWidthCharWidth

  getDoubleWidthCharWidth: -> @doubleWidthCharWidth

  getDefaultCharWidth: -> @defaultCharWidth

  setDefaultCharWidth: (defaultCharWidth, doubleWidthCharWidth, halfWidthCharWidth, koreanCharWidth) ->
    doubleWidthCharWidth ?= defaultCharWidth
    halfWidthCharWidth ?= defaultCharWidth
    koreanCharWidth ?= defaultCharWidth
    if defaultCharWidth isnt @defaultCharWidth or doubleWidthCharWidth isnt @doubleWidthCharWidth and halfWidthCharWidth isnt @halfWidthCharWidth and koreanCharWidth isnt @koreanCharWidth
      @defaultCharWidth = defaultCharWidth
      @doubleWidthCharWidth = doubleWidthCharWidth
      @halfWidthCharWidth = halfWidthCharWidth
      @koreanCharWidth = koreanCharWidth
      @updateWrappedScreenLines() if @isSoftWrapped() and @getEditorWidthInChars()?
    defaultCharWidth

  getCursorWidth: -> 1

  scrollToScreenRange: (screenRange, options = {}) ->
    scrollEvent = {screenRange, options}
    @emitter.emit "did-request-autoscroll", scrollEvent

  scrollToScreenPosition: (screenPosition, options) ->
    @scrollToScreenRange(new Range(screenPosition, screenPosition), options)

  scrollToBufferPosition: (bufferPosition, options) ->
    @scrollToScreenPosition(@screenPositionForBufferPosition(bufferPosition), options)

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

  setIgnoreInvisibles: (ignoreInvisibles) ->
    @tokenizedBuffer.setIgnoreInvisibles(ignoreInvisibles)

  setSoftWrapped: (softWrapped) ->
    if softWrapped isnt @softWrapped
      @softWrapped = softWrapped
      @updateWrappedScreenLines()
      softWrapped = @isSoftWrapped()
      @emitter.emit 'did-change-soft-wrapped', softWrapped
      softWrapped
    else
      @isSoftWrapped()

  isSoftWrapped: ->
    if @largeFileMode
      false
    else
      @softWrapped ? @configSettings.softWrap ? false

  # Set the number of characters that fit horizontally in the editor.
  #
  # editorWidthInChars - A {Number} of characters.
  setEditorWidthInChars: (editorWidthInChars) ->
    if editorWidthInChars > 0
      previousWidthInChars = @editorWidthInChars
      @editorWidthInChars = editorWidthInChars
      if editorWidthInChars isnt previousWidthInChars and @isSoftWrapped()
        @updateWrappedScreenLines()

  # Returns the editor width in characters for soft wrap.
  getEditorWidthInChars: ->
    width = @getWidth()
    if width? and @defaultCharWidth > 0
      Math.max(0, Math.floor(width / @defaultCharWidth))
    else
      @editorWidthInChars

  getSoftWrapColumn: ->
    if @configSettings.softWrapAtPreferredLineLength
      Math.min(@getEditorWidthInChars(), @configSettings.preferredLineLength)
    else
      @getEditorWidthInChars()

  getSoftWrapColumnForTokenizedLine: (tokenizedLine) ->
    lineMaxWidth = @getSoftWrapColumn() * @getDefaultCharWidth()

    return if Number.isNaN(lineMaxWidth)
    return 0 if lineMaxWidth is 0

    iterator = tokenizedLine.getTokenIterator(false)
    column = 0
    currentWidth = 0
    while iterator.next()
      textIndex = 0
      text = iterator.getText()
      while textIndex < text.length
        if iterator.isPairedCharacter()
          charLength = 2
        else
          charLength = 1

        if iterator.hasDoubleWidthCharacterAt(textIndex)
          charWidth = @getDoubleWidthCharWidth()
        else if iterator.hasHalfWidthCharacterAt(textIndex)
          charWidth = @getHalfWidthCharWidth()
        else if iterator.hasKoreanCharacterAt(textIndex)
          charWidth = @getKoreanCharWidth()
        else
          charWidth = @getDefaultCharWidth()

        return column if currentWidth + charWidth > lineMaxWidth

        currentWidth += charWidth
        column += charLength
        textIndex += charLength
    column

  # Gets the screen line for the given screen row.
  #
  # * `screenRow` - A {Number} indicating the screen row.
  #
  # Returns {TokenizedLine}
  tokenizedLineForScreenRow: (screenRow) ->
    if @largeFileMode
      if line = @tokenizedBuffer.tokenizedLineForRow(screenRow)
        if line.text.length > @maxLineLength
          @maxLineLength = line.text.length
          @longestScreenRow = screenRow
        line
    else
      @screenLines[screenRow]

  # Gets the screen lines for the given screen row range.
  #
  # startRow - A {Number} indicating the beginning screen row.
  # endRow - A {Number} indicating the ending screen row.
  #
  # Returns an {Array} of {TokenizedLine}s.
  tokenizedLinesForScreenRows: (startRow, endRow) ->
    if @largeFileMode
      @tokenizedBuffer.tokenizedLinesForRows(startRow, endRow)
    else
      @screenLines[startRow..endRow]

  # Gets all the screen lines.
  #
  # Returns an {Array} of {TokenizedLine}s.
  getTokenizedLines: ->
    if @largeFileMode
      @tokenizedBuffer.tokenizedLinesForRows(0, @getLastRow())
    else
      new Array(@screenLines...)

  indentLevelForLine: (line) ->
    @tokenizedBuffer.indentLevelForLine(line)

  # Given starting and ending screen rows, this returns an array of the
  # buffer rows corresponding to every screen row in the range
  #
  # startScreenRow - The screen row {Number} to start at
  # endScreenRow - The screen row {Number} to end at (default: the last screen row)
  #
  # Returns an {Array} of buffer rows as {Numbers}s.
  bufferRowsForScreenRows: (startScreenRow, endScreenRow) ->
    if @largeFileMode
      [startScreenRow..endScreenRow]
    else
      for screenRow in [startScreenRow..endScreenRow]
        @rowMap.bufferRowRangeForScreenRow(screenRow)[0]

  # Creates a new fold between two row numbers.
  #
  # startRow - The row {Number} to start folding at
  # endRow - The row {Number} to end the fold
  #
  # Returns the new {Fold}.
  createFold: (startRow, endRow) ->
    unless @largeFileMode
      if foldMarker = @findFoldMarker({startRow, endRow})
        @foldForMarker(foldMarker)
      else
        foldMarker = @foldsMarkerLayer.markRange([[startRow, 0], [endRow, Infinity]])
        fold = new Fold(this, foldMarker)
        fold.updateDisplayBuffer()
        @decorateFold(fold)
        fold

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
  unfoldBufferRow: (bufferRow) ->
    fold.destroy() for fold in @foldsContainingBufferRow(bufferRow)
    return

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

  # Returns the folds in the given row range (exclusive of end row) that are
  # not contained by any other folds.
  outermostFoldsInBufferRowRange: (startRow, endRow) ->
    folds = []
    lastFoldEndRow = -1

    for marker in @findFoldMarkers(intersectsRowRange: [startRow, endRow])
      range = marker.getRange()
      if range.start.row > lastFoldEndRow
        lastFoldEndRow = range.end.row
        if startRow <= range.start.row <= range.end.row < endRow
          folds.push(@foldForMarker(marker))

    folds

  # Returns all the folds that intersect the given row range.
  foldsIntersectingBufferRowRange: (startRow, endRow) ->
    @foldForMarker(marker) for marker in @findFoldMarkers(intersectsRowRange: [startRow, endRow])

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
    if @largeFileMode
      bufferRow
    else
      @rowMap.screenRowRangeForBufferRow(bufferRow)[0]

  lastScreenRowForBufferRow: (bufferRow) ->
    if @largeFileMode
      bufferRow
    else
      @rowMap.screenRowRangeForBufferRow(bufferRow)[1] - 1

  # Given a screen row, this converts it into a buffer row.
  #
  # screenRow - A {Number} representing a screen row
  #
  # Returns a {Number}.
  bufferRowForScreenRow: (screenRow) ->
    if @largeFileMode
      screenRow
    else
      @rowMap.bufferRowRangeForScreenRow(screenRow)[0]

  # Given a buffer range, this converts it into a screen position.
  #
  # bufferRange - The {Range} to convert
  #
  # Returns a {Range}.
  screenRangeForBufferRange: (bufferRange, options) ->
    bufferRange = Range.fromObject(bufferRange)
    start = @screenPositionForBufferPosition(bufferRange.start, options)
    end = @screenPositionForBufferPosition(bufferRange.end, options)
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
    if @largeFileMode
      @tokenizedBuffer.getLineCount()
    else
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

  # Gets the row number of the longest screen line.
  #
  # Return a {}
  getLongestScreenRow: ->
    @longestScreenRow

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
    throw new Error("This TextEditor has been destroyed") if @isDestroyed()

    {row, column} = @buffer.clipPosition(bufferPosition)
    [startScreenRow, endScreenRow] = @rowMap.screenRowRangeForBufferRow(row)
    for screenRow in [startScreenRow...endScreenRow]
      screenLine = @tokenizedLineForScreenRow(screenRow)

      unless screenLine?
        throw new BufferToScreenConversionError "No screen line exists when converting buffer row to screen row",
          softWrapEnabled: @isSoftWrapped()
          foldCount: @findFoldMarkers().length
          lastBufferRow: @buffer.getLastRow()
          lastScreenRow: @getLastRow()
          bufferRow: row
          screenRow: screenRow
          displayBufferChangeCount: @changeCount
          tokenizedBufferChangeCount: @tokenizedBuffer.changeCount
          bufferChangeCount: @buffer.changeCount

      maxBufferColumn = screenLine.getMaxBufferColumn()
      if screenLine.isSoftWrapped() and column > maxBufferColumn
        continue
      else
        if column <= maxBufferColumn
          screenColumn = screenLine.screenColumnForBufferColumn(column)
        else
          screenColumn = Infinity
        break

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
    {row, column} = @clipScreenPosition(Point.fromObject(screenPosition), options)
    [bufferRow] = @rowMap.bufferRowRangeForScreenRow(row)
    new Point(bufferRow, @tokenizedLineForScreenRow(row).bufferColumnForScreenColumn(column))

  # Retrieves the grammar's token scopeDescriptor for a buffer position.
  #
  # bufferPosition - A {Point} in the {TextBuffer}
  #
  # Returns a {ScopeDescriptor}.
  scopeDescriptorForBufferPosition: (bufferPosition) ->
    @tokenizedBuffer.scopeDescriptorForPosition(bufferPosition)

  bufferRangeForScopeAtPosition: (selector, position) ->
    @tokenizedBuffer.bufferRangeForScopeAtPosition(selector, position)

  # Retrieves the grammar's token for a buffer position.
  #
  # bufferPosition - A {Point} in the {TextBuffer}.
  #
  # Returns a {Token}.
  tokenForBufferPosition: (bufferPosition) ->
    @tokenizedBuffer.tokenForPosition(bufferPosition)

  # Get the grammar for this buffer.
  #
  # Returns the current {Grammar} or the {NullGrammar}.
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
  #           skipSoftWrapIndentation: if `true`, skips soft wrap indentation without wrapping to the previous line
  #           screenLine: if `true`, indicates that you're using a line number, not a row number
  #
  # Returns the new, clipped {Point}. Note that this could be the same as `position` if no clipping was performed.
  clipScreenPosition: (screenPosition, options={}) ->
    {wrapBeyondNewlines, wrapAtSoftNewlines, skipSoftWrapIndentation} = options
    {row, column} = Point.fromObject(screenPosition)

    if row < 0
      row = 0
      column = 0
    else if row > @getLastRow()
      row = @getLastRow()
      column = Infinity
    else if column < 0
      column = 0

    screenLine = @tokenizedLineForScreenRow(row)
    unless screenLine?
      error = new Error("Undefined screen line when clipping screen position")
      Error.captureStackTrace(error)
      error.metadata = {
        screenRow: row
        screenColumn: column
        maxScreenRow: @getLastRow()
        screenLinesDefined: @screenLines.map (sl) -> sl?
        displayBufferChangeCount: @changeCount
        tokenizedBufferChangeCount: @tokenizedBuffer.changeCount
        bufferChangeCount: @buffer.changeCount
      }
      throw error

    maxScreenColumn = screenLine.getMaxScreenColumn()

    if screenLine.isSoftWrapped() and column >= maxScreenColumn
      if wrapAtSoftNewlines
        row++
        column = @tokenizedLineForScreenRow(row).clipScreenColumn(0)
      else
        column = screenLine.clipScreenColumn(maxScreenColumn - 1)
    else if screenLine.isColumnInsideSoftWrapIndentation(column)
      if skipSoftWrapIndentation
        column = screenLine.clipScreenColumn(0)
      else
        row--
        column = @tokenizedLineForScreenRow(row).getMaxScreenColumn() - 1
    else if wrapBeyondNewlines and column > maxScreenColumn and row < @getLastRow()
      row++
      column = 0
    else
      column = screenLine.clipScreenColumn(column, options)
    new Point(row, column)

  # Clip the start and end of the given range to valid positions on screen.
  # See {::clipScreenPosition} for more information.
  #
  # * `range` The {Range} to clip.
  # * `options` (optional) See {::clipScreenPosition} `options`.
  # Returns a {Range}.
  clipScreenRange: (range, options) ->
    start = @clipScreenPosition(range.start, options)
    end = @clipScreenPosition(range.end, options)

    new Range(start, end)

  # Calculates a {Range} representing the start of the {TextBuffer} until the end.
  #
  # Returns a {Range}.
  rangeForAllLines: ->
    new Range([0, 0], @clipScreenPosition([Infinity, Infinity]))

  decorationForId: (id) ->
    @decorationsById[id]

  getDecorations: (propertyFilter) ->
    allDecorations = []
    for markerId, decorations of @decorationsByMarkerId
      allDecorations.push(decorations...) if decorations?
    if propertyFilter?
      allDecorations = allDecorations.filter (decoration) ->
        for key, value of propertyFilter
          return false unless decoration.properties[key] is value
        true
    allDecorations

  getLineDecorations: (propertyFilter) ->
    @getDecorations(propertyFilter).filter (decoration) -> decoration.isType('line')

  getLineNumberDecorations: (propertyFilter) ->
    @getDecorations(propertyFilter).filter (decoration) -> decoration.isType('line-number')

  getHighlightDecorations: (propertyFilter) ->
    @getDecorations(propertyFilter).filter (decoration) -> decoration.isType('highlight')

  getOverlayDecorations: (propertyFilter) ->
    result = []
    for id, decoration of @overlayDecorationsById
      result.push(decoration)
    if propertyFilter?
      result.filter (decoration) ->
        for key, value of propertyFilter
          return false unless decoration.properties[key] is value
        true
    else
      result

  decorationsForScreenRowRange: (startScreenRow, endScreenRow) ->
    decorationsByMarkerId = {}
    for marker in @findMarkers(intersectsScreenRowRange: [startScreenRow, endScreenRow])
      if decorations = @decorationsByMarkerId[marker.id]
        decorationsByMarkerId[marker.id] = decorations
    decorationsByMarkerId

  decorationsStateForScreenRowRange: (startScreenRow, endScreenRow) ->
    decorationsState = {}

    for layerId of @decorationCountsByLayerId
      layer = @getMarkerLayer(layerId)

      for marker in layer.findMarkers(intersectsScreenRowRange: [startScreenRow, endScreenRow]) when marker.isValid()
        screenRange = marker.getScreenRange()
        rangeIsReversed = marker.isReversed()

        if decorations = @decorationsByMarkerId[marker.id]
          for decoration in decorations
            decorationsState[decoration.id] = {
              properties: decoration.properties
              screenRange, rangeIsReversed
            }

        if layerDecorations = @layerDecorationsByMarkerLayerId[layerId]
          for layerDecoration in layerDecorations
            decorationsState["#{layerDecoration.id}-#{marker.id}"] = {
              properties: layerDecoration.overridePropertiesByMarkerId[marker.id] ? layerDecoration.properties
              screenRange, rangeIsReversed
            }

    decorationsState

  decorateMarker: (marker, decorationParams) ->
    throw new Error("Cannot decorate a destroyed marker") if marker.isDestroyed()
    marker = @getMarkerLayer(marker.layer.id).getMarker(marker.id)
    decoration = new Decoration(marker, this, decorationParams)
    @decorationsByMarkerId[marker.id] ?= []
    @decorationsByMarkerId[marker.id].push(decoration)
    @overlayDecorationsById[decoration.id] = decoration if decoration.isType('overlay')
    @decorationsById[decoration.id] = decoration
    @observeDecoratedLayer(marker.layer)
    @scheduleUpdateDecorationsEvent()
    @emitter.emit 'did-add-decoration', decoration
    decoration

  decorateMarkerLayer: (markerLayer, decorationParams) ->
    decoration = new LayerDecoration(markerLayer, this, decorationParams)
    @layerDecorationsByMarkerLayerId[markerLayer.id] ?= []
    @layerDecorationsByMarkerLayerId[markerLayer.id].push(decoration)
    @observeDecoratedLayer(markerLayer)
    @scheduleUpdateDecorationsEvent()
    decoration

  decorationsForMarkerId: (markerId) ->
    @decorationsByMarkerId[markerId]

  # Retrieves a {TextEditorMarker} based on its id.
  #
  # id - A {Number} representing a marker id
  #
  # Returns the {TextEditorMarker} (if it exists).
  getMarker: (id) ->
    @defaultMarkerLayer.getMarker(id)

  # Retrieves the active markers in the buffer.
  #
  # Returns an {Array} of existing {TextEditorMarker}s.
  getMarkers: ->
    @defaultMarkerLayer.getMarkers()

  getMarkerCount: ->
    @buffer.getMarkerCount()

  # Public: Constructs a new marker at the given screen range.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {TextEditorMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markScreenRange: (screenRange, options) ->
    @defaultMarkerLayer.markScreenRange(screenRange, options)

  # Public: Constructs a new marker at the given buffer range.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {TextEditorMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markBufferRange: (bufferRange, options) ->
    @defaultMarkerLayer.markBufferRange(bufferRange, options)

  # Public: Constructs a new marker at the given screen position.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {TextEditorMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markScreenPosition: (screenPosition, options) ->
    @defaultMarkerLayer.markScreenPosition(screenPosition, options)

  # Public: Constructs a new marker at the given buffer position.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {TextEditorMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markBufferPosition: (bufferPosition, options) ->
    @defaultMarkerLayer.markBufferPosition(bufferPosition, options)

  # Finds the first marker satisfying the given attributes
  #
  # Refer to {DisplayBuffer::findMarkers} for details.
  #
  # Returns a {TextEditorMarker} or null
  findMarker: (params) ->
    @defaultMarkerLayer.findMarkers(params)[0]

  # Public: Find all markers satisfying a set of parameters.
  #
  # params - An {Object} containing parameters that all returned markers must
  #   satisfy. Unreserved keys will be compared against the markers' custom
  #   properties. There are also the following reserved keys with special
  #   meaning for the query:
  #   :startBufferRow - A {Number}. Only returns markers starting at this row in
  #     buffer coordinates.
  #   :endBufferRow - A {Number}. Only returns markers ending at this row in
  #     buffer coordinates.
  #   :containsBufferRange - A {Range} or range-compatible {Array}. Only returns
  #     markers containing this range in buffer coordinates.
  #   :containsBufferPosition - A {Point} or point-compatible {Array}. Only
  #     returns markers containing this position in buffer coordinates.
  #   :containedInBufferRange - A {Range} or range-compatible {Array}. Only
  #     returns markers contained within this range.
  #
  # Returns an {Array} of {TextEditorMarker}s
  findMarkers: (params) ->
    @defaultMarkerLayer.findMarkers(params)

  addMarkerLayer: (options) ->
    bufferLayer = @buffer.addMarkerLayer(options)
    @getMarkerLayer(bufferLayer.id)

  getMarkerLayer: (id) ->
    if layer = @customMarkerLayersById[id]
      layer
    else if bufferLayer = @buffer.getMarkerLayer(id)
      @customMarkerLayersById[id] = new TextEditorMarkerLayer(this, bufferLayer)

  getDefaultMarkerLayer: -> @defaultMarkerLayer

  findFoldMarker: (params) ->
    @findFoldMarkers(params)[0]

  findFoldMarkers: (params) ->
    @foldsMarkerLayer.findMarkers(params)

  refreshMarkerScreenPositions: ->
    @defaultMarkerLayer.refreshMarkerScreenPositions()
    layer.refreshMarkerScreenPositions() for id, layer of @customMarkerLayersById
    return

  destroyed: ->
    @defaultMarkerLayer.destroy()
    @foldsMarkerLayer.destroy()
    @scopedConfigSubscriptions.dispose()
    @disposables.dispose()
    @tokenizedBuffer.destroy()

  logLines: (start=0, end=@getLastRow()) ->
    for row in [start..end]
      line = @tokenizedLineForScreenRow(row).text
      console.log row, @bufferRowForScreenRow(row), line, line.length
    return

  getRootScopeDescriptor: ->
    @tokenizedBuffer.rootScopeDescriptor

  handleTokenizedBufferChange: (tokenizedBufferChange) =>
    @changeCount = @tokenizedBuffer.changeCount
    {start, end, delta, bufferChange} = tokenizedBufferChange
    @updateScreenLines(start, end + 1, delta, refreshMarkers: false)

  updateScreenLines: (startBufferRow, endBufferRow, bufferDelta=0, options={}) ->
    return if @largeFileMode
    return if @isDestroyed()

    startBufferRow = @rowMap.bufferRowRangeForBufferRow(startBufferRow)[0]
    endBufferRow = @rowMap.bufferRowRangeForBufferRow(endBufferRow - 1)[1]
    startScreenRow = @rowMap.screenRowRangeForBufferRow(startBufferRow)[0]
    endScreenRow = @rowMap.screenRowRangeForBufferRow(endBufferRow - 1)[1]
    {screenLines, regions} = @buildScreenLines(startBufferRow, endBufferRow + bufferDelta)
    screenDelta = screenLines.length - (endScreenRow - startScreenRow)

    _.spliceWithArray(@screenLines, startScreenRow, endScreenRow - startScreenRow, screenLines, 10000)

    @checkScreenLinesInvariant()

    @rowMap.spliceRegions(startBufferRow, endBufferRow - startBufferRow, regions)
    @findMaxLineLength(startScreenRow, endScreenRow, screenLines, screenDelta)

    return if options.suppressChangeEvent

    changeEvent =
      start: startScreenRow
      end: endScreenRow - 1
      screenDelta: screenDelta
      bufferDelta: bufferDelta

    @emitDidChange(changeEvent, options.refreshMarkers)

  buildScreenLines: (startBufferRow, endBufferRow) ->
    screenLines = []
    regions = []
    rectangularRegion = null

    foldsByStartRow = {}
    for fold in @outermostFoldsInBufferRowRange(startBufferRow, endBufferRow)
      foldsByStartRow[fold.getStartRow()] = fold

    bufferRow = startBufferRow
    while bufferRow < endBufferRow
      tokenizedLine = @tokenizedBuffer.tokenizedLineForRow(bufferRow)

      if fold = foldsByStartRow[bufferRow]
        foldLine = tokenizedLine.copy()
        foldLine.fold = fold
        screenLines.push(foldLine)

        if rectangularRegion?
          regions.push(rectangularRegion)
          rectangularRegion = null

        foldedRowCount = fold.getBufferRowCount()
        regions.push(bufferRows: foldedRowCount, screenRows: 1)
        bufferRow += foldedRowCount
      else
        softWraps = 0
        if @isSoftWrapped()
          while wrapScreenColumn = tokenizedLine.findWrapColumn(@getSoftWrapColumnForTokenizedLine(tokenizedLine))
            [wrappedLine, tokenizedLine] = tokenizedLine.softWrapAt(
              wrapScreenColumn,
              @configSettings.softWrapHangingIndent
            )
            break if wrappedLine.hasOnlySoftWrapIndentation()
            screenLines.push(wrappedLine)
            softWraps++
        screenLines.push(tokenizedLine)

        if softWraps > 0
          if rectangularRegion?
            regions.push(rectangularRegion)
            rectangularRegion = null
          regions.push(bufferRows: 1, screenRows: softWraps + 1)
        else
          rectangularRegion ?= {bufferRows: 0, screenRows: 0}
          rectangularRegion.bufferRows++
          rectangularRegion.screenRows++

        bufferRow++

    if rectangularRegion?
      regions.push(rectangularRegion)

    {screenLines, regions}

  findMaxLineLength: (startScreenRow, endScreenRow, newScreenLines, screenDelta) ->
    oldMaxLineLength = @maxLineLength

    if startScreenRow <= @longestScreenRow < endScreenRow
      @longestScreenRow = 0
      @maxLineLength = 0
      maxLengthCandidatesStartRow = 0
      maxLengthCandidates = @screenLines
    else
      @longestScreenRow += screenDelta if endScreenRow <= @longestScreenRow
      maxLengthCandidatesStartRow = startScreenRow
      maxLengthCandidates = newScreenLines

    for screenLine, i in maxLengthCandidates
      screenRow = maxLengthCandidatesStartRow + i
      length = screenLine.text.length
      if length > @maxLineLength
        @longestScreenRow = screenRow
        @maxLineLength = length

  didCreateDefaultLayerMarker: (textBufferMarker) =>
    if marker = @getMarker(textBufferMarker.id)
      # The marker might have been removed in some other handler called before
      # this one. Only emit when the marker still exists.
      @emitter.emit 'did-create-marker', marker

  scheduleUpdateDecorationsEvent: ->
    if @updatedSynchronously
      @emitter.emit 'did-update-decorations'
      return

    unless @didUpdateDecorationsEventScheduled
      @didUpdateDecorationsEventScheduled = true
      process.nextTick =>
        @didUpdateDecorationsEventScheduled = false
        @emitter.emit 'did-update-decorations'

  decorateFold: (fold) ->
    @decorateMarker(fold.marker, type: 'line-number', class: 'folded')

  foldForMarker: (marker) ->
    @foldsByMarkerId[marker.id]

  decorationDidChangeType: (decoration) ->
    if decoration.isType('overlay')
      @overlayDecorationsById[decoration.id] = decoration
    else
      delete @overlayDecorationsById[decoration.id]

  didDestroyDecoration: (decoration) ->
    {marker} = decoration
    return unless decorations = @decorationsByMarkerId[marker.id]
    index = decorations.indexOf(decoration)

    if index > -1
      decorations.splice(index, 1)
      delete @decorationsById[decoration.id]
      @emitter.emit 'did-remove-decoration', decoration
      delete @decorationsByMarkerId[marker.id] if decorations.length is 0
      delete @overlayDecorationsById[decoration.id]
      @unobserveDecoratedLayer(marker.layer)
    @scheduleUpdateDecorationsEvent()

  didDestroyLayerDecoration: (decoration) ->
    {markerLayer} = decoration
    return unless decorations = @layerDecorationsByMarkerLayerId[markerLayer.id]
    index = decorations.indexOf(decoration)

    if index > -1
      decorations.splice(index, 1)
      delete @layerDecorationsByMarkerLayerId[markerLayer.id] if decorations.length is 0
      @unobserveDecoratedLayer(markerLayer)
    @scheduleUpdateDecorationsEvent()

  observeDecoratedLayer: (layer) ->
    @decorationCountsByLayerId[layer.id] ?= 0
    if ++@decorationCountsByLayerId[layer.id] is 1
      @layerUpdateDisposablesByLayerId[layer.id] = layer.onDidUpdate(@scheduleUpdateDecorationsEvent.bind(this))

  unobserveDecoratedLayer: (layer) ->
    if --@decorationCountsByLayerId[layer.id] is 0
      @layerUpdateDisposablesByLayerId[layer.id].dispose()
      delete @decorationCountsByLayerId[layer.id]
      delete @layerUpdateDisposablesByLayerId[layer.id]

  checkScreenLinesInvariant: ->
    return if @isSoftWrapped()
    return if _.size(@foldsByMarkerId) > 0

    screenLinesCount = @screenLines.length
    tokenizedLinesCount = @tokenizedBuffer.getLineCount()
    bufferLinesCount = @buffer.getLineCount()

    @assert screenLinesCount is tokenizedLinesCount, "Display buffer line count out of sync with tokenized buffer", (error) ->
      error.metadata = {screenLinesCount, tokenizedLinesCount, bufferLinesCount}

    @assert screenLinesCount is bufferLinesCount, "Display buffer line count out of sync with buffer", (error) ->
      error.metadata = {screenLinesCount, tokenizedLinesCount, bufferLinesCount}
