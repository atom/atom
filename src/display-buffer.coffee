_ = require 'underscore-plus'
Serializable = require 'serializable'
{CompositeDisposable, Emitter} = require 'event-kit'
{Point, Range} = require 'text-buffer'
Grim = require 'grim'
TokenizedBuffer = require './tokenized-buffer'
RowMap = require './row-map'
Fold = require './fold'
Model = require './model'
Token = require './token'
Decoration = require './decoration'
Marker = require './marker'

class BufferToScreenConversionError extends Error
  constructor: (@message, @metadata) ->
    super
    Error.captureStackTrace(this, BufferToScreenConversionError)

module.exports =
class DisplayBuffer extends Model
  Serializable.includeInto(this)

  verticalScrollMargin: 2
  horizontalScrollMargin: 6
  scopedCharacterWidthsChangeCount: 0
  changeCount: 0

  constructor: ({tabLength, @editorWidthInChars, @tokenizedBuffer, buffer, ignoreInvisibles, @largeFileMode}={}) ->
    super

    @emitter = new Emitter
    @disposables = new CompositeDisposable

    @tokenizedBuffer ?= new TokenizedBuffer({tabLength, buffer, ignoreInvisibles, @largeFileMode})
    @buffer = @tokenizedBuffer.buffer
    @charWidthsByScope = {}
    @markers = {}
    @foldsByMarkerId = {}
    @decorationsById = {}
    @decorationsByMarkerId = {}
    @overlayDecorationsById = {}
    @disposables.add @tokenizedBuffer.observeGrammar @subscribeToScopedConfigSettings
    @disposables.add @tokenizedBuffer.onDidChange @handleTokenizedBufferChange
    @disposables.add @buffer.onDidCreateMarker @handleBufferMarkerCreated
    @disposables.add @buffer.onDidUpdateMarkers => @emitter.emit 'did-update-markers'
    @foldMarkerAttributes = Object.freeze({class: 'fold', displayBufferId: @id})
    folds = (new Fold(this, marker) for marker in @buffer.findMarkers(@getFoldMarkerAttributes()))
    @updateAllScreenLines()
    @decorateFold(fold) for fold in folds

  subscribeToScopedConfigSettings: =>
    @scopedConfigSubscriptions?.dispose()
    @scopedConfigSubscriptions = subscriptions = new CompositeDisposable

    scopeDescriptor = @getRootScopeDescriptor()

    oldConfigSettings = @configSettings
    @configSettings =
      scrollPastEnd: atom.config.get('editor.scrollPastEnd', scope: scopeDescriptor)
      softWrap: atom.config.get('editor.softWrap', scope: scopeDescriptor)
      softWrapAtPreferredLineLength: atom.config.get('editor.softWrapAtPreferredLineLength', scope: scopeDescriptor)
      softWrapHangingIndent: atom.config.get('editor.softWrapHangingIndent', scope: scopeDescriptor)
      preferredLineLength: atom.config.get('editor.preferredLineLength', scope: scopeDescriptor)

    subscriptions.add atom.config.onDidChange 'editor.softWrap', scope: scopeDescriptor, ({newValue}) =>
      @configSettings.softWrap = newValue
      @updateWrappedScreenLines()

    subscriptions.add atom.config.onDidChange 'editor.softWrapHangingIndent', scope: scopeDescriptor, ({newValue}) =>
      @configSettings.softWrapHangingIndent = newValue
      @updateWrappedScreenLines()

    subscriptions.add atom.config.onDidChange 'editor.softWrapAtPreferredLineLength', scope: scopeDescriptor, ({newValue}) =>
      @configSettings.softWrapAtPreferredLineLength = newValue
      @updateWrappedScreenLines() if @isSoftWrapped()

    subscriptions.add atom.config.onDidChange 'editor.preferredLineLength', scope: scopeDescriptor, ({newValue}) =>
      @configSettings.preferredLineLength = newValue
      @updateWrappedScreenLines() if @isSoftWrapped() and atom.config.get('editor.softWrapAtPreferredLineLength', scope: scopeDescriptor)

    subscriptions.add atom.config.observe 'editor.scrollPastEnd', scope: scopeDescriptor, (value) =>
      @configSettings.scrollPastEnd = value

    @updateWrappedScreenLines() if oldConfigSettings? and not _.isEqual(oldConfigSettings, @configSettings)

  serializeParams: ->
    id: @id
    softWrapped: @isSoftWrapped()
    editorWidthInChars: @editorWidthInChars
    scrollTop: @scrollTop
    scrollLeft: @scrollLeft
    tokenizedBuffer: @tokenizedBuffer.serialize()
    largeFileMode: @largeFileMode

  deserializeParams: (params) ->
    params.tokenizedBuffer = TokenizedBuffer.deserialize(params.tokenizedBuffer)
    params

  copy: ->
    newDisplayBuffer = new DisplayBuffer({@buffer, tabLength: @getTabLength(), @largeFileMode})
    newDisplayBuffer.setScrollTop(@getScrollTop())
    newDisplayBuffer.setScrollLeft(@getScrollLeft())

    for marker in @findMarkers(displayBufferId: @id)
      marker.copy(displayBufferId: newDisplayBuffer.id)
    newDisplayBuffer

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

  onDidChangeScrollTop: (callback) ->
    @emitter.on 'did-change-scroll-top', callback

  onDidChangeScrollLeft: (callback) ->
    @emitter.on 'did-change-scroll-left', callback

  observeScrollTop: (callback) ->
    callback(@scrollTop)
    @onDidChangeScrollTop(callback)

  observeScrollLeft: (callback) ->
    callback(@scrollLeft)
    @onDidChangeScrollLeft(callback)

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

  emitDidChange: (eventProperties, refreshMarkers=true) ->
    @emit 'changed', eventProperties if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-change', eventProperties
    if refreshMarkers
      @refreshMarkerScreenPositions()
    @emit 'markers-updated' if Grim.includeDeprecatedAPIs
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

  getVerticalScrollMargin: -> Math.min(@verticalScrollMargin, (@getHeight() - @getLineHeightInPixels()) / 2)
  setVerticalScrollMargin: (@verticalScrollMargin) -> @verticalScrollMargin

  getVerticalScrollMarginInPixels: ->
    scrollMarginInPixels = @getVerticalScrollMargin() * @getLineHeightInPixels()
    maxScrollMarginInPixels = (@getHeight() - @getLineHeightInPixels()) / 2
    Math.min(scrollMarginInPixels, maxScrollMarginInPixels)

  getHorizontalScrollMargin: -> Math.min(@horizontalScrollMargin, (@getWidth() - @getDefaultCharWidth()) / 2)
  setHorizontalScrollMargin: (@horizontalScrollMargin) -> @horizontalScrollMargin

  getHorizontalScrollMarginInPixels: ->
    scrollMarginInPixels = @getHorizontalScrollMargin() * @getDefaultCharWidth()
    maxScrollMarginInPixels = (@getWidth() - @getDefaultCharWidth()) / 2
    Math.min(scrollMarginInPixels, maxScrollMarginInPixels)

  getHorizontalScrollbarHeight: -> @horizontalScrollbarHeight
  setHorizontalScrollbarHeight: (@horizontalScrollbarHeight) -> @horizontalScrollbarHeight

  getVerticalScrollbarWidth: -> @verticalScrollbarWidth
  setVerticalScrollbarWidth: (@verticalScrollbarWidth) -> @verticalScrollbarWidth

  getHeight: ->
    if @height?
      @height
    else
      if @horizontallyScrollable()
        @getScrollHeight() + @getHorizontalScrollbarHeight()
      else
        @getScrollHeight()

  setHeight: (@height) -> @height

  getClientHeight: (reentrant) ->
    if @horizontallyScrollable(reentrant)
      @getHeight() - @getHorizontalScrollbarHeight()
    else
      @getHeight()

  getClientWidth: (reentrant) ->
    if @verticallyScrollable(reentrant)
      @getWidth() - @getVerticalScrollbarWidth()
    else
      @getWidth()

  horizontallyScrollable: (reentrant) ->
    return false unless @width?
    return false if @isSoftWrapped()
    if reentrant
      @getScrollWidth() > @getWidth()
    else
      @getScrollWidth() > @getClientWidth(true)

  verticallyScrollable: (reentrant) ->
    return false unless @height?
    if reentrant
      @getScrollHeight() > @getHeight()
    else
      @getScrollHeight() > @getClientHeight(true)

  getWidth: ->
    if @width?
      @width
    else
      if @verticallyScrollable()
        @getScrollWidth() + @getVerticalScrollbarWidth()
      else
        @getScrollWidth()

  setWidth: (newWidth) ->
    oldWidth = @width
    @width = newWidth
    @updateWrappedScreenLines() if newWidth isnt oldWidth and @isSoftWrapped()
    @setScrollTop(@getScrollTop()) # Ensure scrollTop is still valid in case horizontal scrollbar disappeared
    @width

  getScrollTop: -> @scrollTop
  setScrollTop: (scrollTop) ->
    scrollTop = Math.round(Math.max(0, Math.min(@getMaxScrollTop(), scrollTop)))
    unless scrollTop is @scrollTop
      @scrollTop = scrollTop
      @emitter.emit 'did-change-scroll-top', @scrollTop
    @scrollTop

  getMaxScrollTop: ->
    @getScrollHeight() - @getClientHeight()

  getScrollBottom: -> @scrollTop + @getClientHeight()
  setScrollBottom: (scrollBottom) ->
    @setScrollTop(scrollBottom - @getClientHeight())
    @getScrollBottom()

  getScrollLeft: -> @scrollLeft
  setScrollLeft: (scrollLeft) ->
    scrollLeft = Math.round(Math.max(0, Math.min(@getScrollWidth() - @getClientWidth(), scrollLeft)))
    unless scrollLeft is @scrollLeft
      @scrollLeft = scrollLeft
      @emitter.emit 'did-change-scroll-left', @scrollLeft
    @scrollLeft

  getMaxScrollLeft: ->
    @getScrollWidth() - @getClientWidth()

  getScrollRight: -> @scrollLeft + @width
  setScrollRight: (scrollRight) ->
    @setScrollLeft(scrollRight - @width)
    @getScrollRight()

  getLineHeightInPixels: -> @lineHeightInPixels
  setLineHeightInPixels: (@lineHeightInPixels) -> @lineHeightInPixels

  getDefaultCharWidth: -> @defaultCharWidth
  setDefaultCharWidth: (defaultCharWidth) ->
    if defaultCharWidth isnt @defaultCharWidth
      @defaultCharWidth = defaultCharWidth
      @computeScrollWidth()
    defaultCharWidth

  getCursorWidth: -> 1

  getScopedCharWidth: (scopeNames, char) ->
    @getScopedCharWidths(scopeNames)[char]

  getScopedCharWidths: (scopeNames) ->
    scope = @charWidthsByScope
    for scopeName in scopeNames
      scope[scopeName] ?= {}
      scope = scope[scopeName]
    scope.charWidths ?= {}
    scope.charWidths

  batchCharacterMeasurement: (fn) ->
    oldChangeCount = @scopedCharacterWidthsChangeCount
    @batchingCharacterMeasurement = true
    fn()
    @batchingCharacterMeasurement = false
    @characterWidthsChanged() if oldChangeCount isnt @scopedCharacterWidthsChangeCount

  setScopedCharWidth: (scopeNames, char, width) ->
    @getScopedCharWidths(scopeNames)[char] = width
    @scopedCharacterWidthsChangeCount++
    @characterWidthsChanged() unless @batchingCharacterMeasurement

  characterWidthsChanged: ->
    @computeScrollWidth()
    @emit 'character-widths-changed', @scopedCharacterWidthsChangeCount if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-change-character-widths', @scopedCharacterWidthsChangeCount

  clearScopedCharWidths: ->
    @charWidthsByScope = {}

  getScrollHeight: ->
    lineHeight = @getLineHeightInPixels()
    return 0 unless lineHeight > 0

    scrollHeight = @getLineCount() * lineHeight
    if @height? and @configSettings.scrollPastEnd
      scrollHeight = scrollHeight + @height - (lineHeight * 3)

    scrollHeight

  getScrollWidth: ->
    @scrollWidth

  # Returns an {Array} of two numbers representing the first and the last visible rows.
  getVisibleRowRange: ->
    return [0, 0] unless @getLineHeightInPixels() > 0

    startRow = Math.floor(@getScrollTop() / @getLineHeightInPixels())
    endRow = Math.ceil((@getScrollTop() + @getHeight()) / @getLineHeightInPixels()) - 1
    endRow = Math.min(@getLineCount(), endRow)

    [startRow, endRow]

  intersectsVisibleRowRange: (startRow, endRow) ->
    [visibleStart, visibleEnd] = @getVisibleRowRange()
    not (endRow <= visibleStart or visibleEnd <= startRow)

  selectionIntersectsVisibleRowRange: (selection) ->
    {start, end} = selection.getScreenRange()
    @intersectsVisibleRowRange(start.row, end.row + 1)

  scrollToScreenRange: (screenRange, options) ->
    verticalScrollMarginInPixels = @getVerticalScrollMarginInPixels()
    horizontalScrollMarginInPixels = @getHorizontalScrollMarginInPixels()

    {top, left} = @pixelRectForScreenRange(new Range(screenRange.start, screenRange.start))
    {top: endTop, left: endLeft, height: endHeight} = @pixelRectForScreenRange(new Range(screenRange.end, screenRange.end))
    bottom = endTop + endHeight
    right = endLeft

    if options?.center
      desiredScrollCenter = (top + bottom) / 2
      unless @getScrollTop() < desiredScrollCenter < @getScrollBottom()
        desiredScrollTop =  desiredScrollCenter - @getHeight() / 2
        desiredScrollBottom =  desiredScrollCenter + @getHeight() / 2
    else
      desiredScrollTop = top - verticalScrollMarginInPixels
      desiredScrollBottom = bottom + verticalScrollMarginInPixels

    desiredScrollLeft = left - horizontalScrollMarginInPixels
    desiredScrollRight = right + horizontalScrollMarginInPixels

    if options?.reversed ? true
      if desiredScrollBottom > @getScrollBottom()
        @setScrollBottom(desiredScrollBottom)
      if desiredScrollTop < @getScrollTop()
        @setScrollTop(desiredScrollTop)

      if desiredScrollRight > @getScrollRight()
        @setScrollRight(desiredScrollRight)
      if desiredScrollLeft < @getScrollLeft()
        @setScrollLeft(desiredScrollLeft)
    else
      if desiredScrollTop < @getScrollTop()
        @setScrollTop(desiredScrollTop)
      if desiredScrollBottom > @getScrollBottom()
        @setScrollBottom(desiredScrollBottom)

      if desiredScrollLeft < @getScrollLeft()
        @setScrollLeft(desiredScrollLeft)
      if desiredScrollRight > @getScrollRight()
        @setScrollRight(desiredScrollRight)

  scrollToScreenPosition: (screenPosition, options) ->
    @scrollToScreenRange(new Range(screenPosition, screenPosition), options)

  scrollToBufferPosition: (bufferPosition, options) ->
    @scrollToScreenPosition(@screenPositionForBufferPosition(bufferPosition), options)

  pixelRectForScreenRange: (screenRange) ->
    if screenRange.end.row > screenRange.start.row
      top = @pixelPositionForScreenPosition(screenRange.start).top
      left = 0
      height = (screenRange.end.row - screenRange.start.row + 1) * @getLineHeightInPixels()
      width = @getScrollWidth()
    else
      {top, left} = @pixelPositionForScreenPosition(screenRange.start, false)
      height = @getLineHeightInPixels()
      width = @pixelPositionForScreenPosition(screenRange.end, false).left - left

    {top, left, width, height}

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
      @emit 'soft-wrap-changed', softWrapped if Grim.includeDeprecatedAPIs
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
    width = @width ? @getScrollWidth()
    width -= @getVerticalScrollbarWidth()
    if width? and @defaultCharWidth > 0
      Math.max(0, Math.floor(width / @defaultCharWidth))
    else
      @editorWidthInChars

  getSoftWrapColumn: ->
    if @configSettings.softWrapAtPreferredLineLength
      Math.min(@getEditorWidthInChars(), @configSettings.preferredLineLength)
    else
      @getEditorWidthInChars()

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

  pixelRangeForScreenRange: (screenRange, clip=true) ->
    {start, end} = Range.fromObject(screenRange)
    {start: @pixelPositionForScreenPosition(start, clip), end: @pixelPositionForScreenPosition(end, clip)}

  pixelPositionForScreenPosition: (screenPosition, clip=true) ->
    screenPosition = Point.fromObject(screenPosition)
    screenPosition = @clipScreenPosition(screenPosition) if clip

    targetRow = screenPosition.row
    targetColumn = screenPosition.column
    defaultCharWidth = @defaultCharWidth

    top = targetRow * @lineHeightInPixels
    left = 0
    column = 0

    iterator = @tokenizedLineForScreenRow(targetRow).getTokenIterator()
    while iterator.next()
      charWidths = @getScopedCharWidths(iterator.getScopes())
      valueIndex = 0
      value = iterator.getText()
      while valueIndex < value.length
        if iterator.isPairedCharacter()
          char = value
          charLength = 2
          valueIndex += 2
        else
          char = value[valueIndex]
          charLength = 1
          valueIndex++

        return {top, left} if column is targetColumn
        left += charWidths[char] ? defaultCharWidth unless char is '\0'
        column += charLength
    {top, left}

  screenPositionForPixelPosition: (pixelPosition) ->
    targetTop = pixelPosition.top
    targetLeft = pixelPosition.left
    defaultCharWidth = @defaultCharWidth
    row = Math.floor(targetTop / @getLineHeightInPixels())
    targetLeft = 0 if row < 0
    targetLeft = Infinity if row > @getLastRow()
    row = Math.min(row, @getLastRow())
    row = Math.max(0, row)

    left = 0
    column = 0

    iterator = @tokenizedLineForScreenRow(row).getTokenIterator()
    while iterator.next()
      charWidths = @getScopedCharWidths(iterator.getScopes())
      value = iterator.getText()
      valueIndex = 0
      while valueIndex < value.length
        if iterator.isPairedCharacter()
          char = value
          charLength = 2
          valueIndex += 2
        else
          char = value[valueIndex]
          charLength = 1
          valueIndex++

        charWidth = charWidths[char] ? defaultCharWidth
        break if targetLeft <= left + (charWidth / 2)
        left += charWidth
        column += charLength

    new Point(row, column)

  pixelPositionForBufferPosition: (bufferPosition) ->
    @pixelPositionForScreenPosition(@screenPositionForBufferPosition(bufferPosition))

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

  decorateMarker: (marker, decorationParams) ->
    marker = @getMarker(marker.id)
    decoration = new Decoration(marker, this, decorationParams)
    decorationDestroyedDisposable = decoration.onDidDestroy =>
      @removeDecoration(decoration)
      @disposables.remove(decorationDestroyedDisposable)
    @disposables.add(decorationDestroyedDisposable)
    @decorationsByMarkerId[marker.id] ?= []
    @decorationsByMarkerId[marker.id].push(decoration)
    @overlayDecorationsById[decoration.id] = decoration if decoration.isType('overlay')
    @decorationsById[decoration.id] = decoration
    @emit 'decoration-added', decoration if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-add-decoration', decoration
    decoration

  removeDecoration: (decoration) ->
    {marker} = decoration
    return unless decorations = @decorationsByMarkerId[marker.id]
    index = decorations.indexOf(decoration)

    if index > -1
      decorations.splice(index, 1)
      delete @decorationsById[decoration.id]
      @emit 'decoration-removed', decoration if Grim.includeDeprecatedAPIs
      @emitter.emit 'did-remove-decoration', decoration
      delete @decorationsByMarkerId[marker.id] if decorations.length is 0
      delete @overlayDecorationsById[decoration.id]

  decorationsForMarkerId: (markerId) ->
    @decorationsByMarkerId[markerId]

  # Retrieves a {Marker} based on its id.
  #
  # id - A {Number} representing a marker id
  #
  # Returns the {Marker} (if it exists).
  getMarker: (id) ->
    unless marker = @markers[id]
      if bufferMarker = @buffer.getMarker(id)
        marker = new Marker({bufferMarker, displayBuffer: this})
        @markers[id] = marker
    marker

  # Retrieves the active markers in the buffer.
  #
  # Returns an {Array} of existing {Marker}s.
  getMarkers: ->
    @buffer.getMarkers().map ({id}) => @getMarker(id)

  getMarkerCount: ->
    @buffer.getMarkerCount()

  # Public: Constructs a new marker at the given screen range.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {Marker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markScreenRange: (args...) ->
    bufferRange = @bufferRangeForScreenRange(args.shift())
    @markBufferRange(bufferRange, args...)

  # Public: Constructs a new marker at the given buffer range.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {Marker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markBufferRange: (range, options) ->
    @getMarker(@buffer.markRange(range, options).id)

  # Public: Constructs a new marker at the given screen position.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {Marker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markScreenPosition: (screenPosition, options) ->
    @markBufferPosition(@bufferPositionForScreenPosition(screenPosition), options)

  # Public: Constructs a new marker at the given buffer position.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {Marker} constructor
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
  # Refer to {DisplayBuffer::findMarkers} for details.
  #
  # Returns a {Marker} or null
  findMarker: (params) ->
    @findMarkers(params)[0]

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
  # Returns an {Array} of {Marker}s
  findMarkers: (params) ->
    params = @translateToBufferMarkerParams(params)
    @buffer.findMarkers(params).map (stringMarker) => @getMarker(stringMarker.id)

  translateToBufferMarkerParams: (params) ->
    bufferMarkerParams = {}
    for key, value of params
      switch key
        when 'startBufferRow'
          key = 'startRow'
        when 'endBufferRow'
          key = 'endRow'
        when 'startScreenRow'
          key = 'startRow'
          value = @bufferRowForScreenRow(value)
        when 'endScreenRow'
          key = 'endRow'
          value = @bufferRowForScreenRow(value)
        when 'intersectsBufferRowRange'
          key = 'intersectsRowRange'
        when 'intersectsScreenRowRange'
          key = 'intersectsRowRange'
          [startRow, endRow] = value
          value = [@bufferRowForScreenRow(startRow), @bufferRowForScreenRow(endRow)]
        when 'containsBufferRange'
          key = 'containsRange'
        when 'containsBufferPosition'
          key = 'containsPosition'
        when 'containedInBufferRange'
          key = 'containedInRange'
        when 'containedInScreenRange'
          key = 'containedInRange'
          value = @bufferRangeForScreenRange(value)
        when 'intersectsBufferRange'
          key = 'intersectsRange'
        when 'intersectsScreenRange'
          key = 'intersectsRange'
          value = @bufferRangeForScreenRange(value)
      bufferMarkerParams[key] = value

    bufferMarkerParams

  findFoldMarker: (attributes) ->
    @findFoldMarkers(attributes)[0]

  findFoldMarkers: (attributes) ->
    @buffer.findMarkers(@getFoldMarkerAttributes(attributes))

  getFoldMarkerAttributes: (attributes) ->
    if attributes
      _.extend(attributes, @foldMarkerAttributes)
    else
      @foldMarkerAttributes

  refreshMarkerScreenPositions: ->
    for marker in @getMarkers()
      marker.notifyObservers(textChanged: false)
    return

  destroyed: ->
    fold.destroy() for markerId, fold of @foldsByMarkerId
    marker.disposables.dispose() for id, marker of @markers
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
    @setScrollTop(Math.min(@getScrollTop(), @getMaxScrollTop())) if delta < 0

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
          while wrapScreenColumn = tokenizedLine.findWrapColumn(@getSoftWrapColumn())
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

    @computeScrollWidth() if oldMaxLineLength isnt @maxLineLength

  computeScrollWidth: ->
    @scrollWidth = @pixelPositionForScreenPosition([@longestScreenRow, @maxLineLength]).left
    @scrollWidth += 1 unless @isSoftWrapped()
    @setScrollLeft(Math.min(@getScrollLeft(), @getMaxScrollLeft()))

  handleBufferMarkerCreated: (textBufferMarker) =>
    if textBufferMarker.matchesParams(@getFoldMarkerAttributes())
      fold = new Fold(this, textBufferMarker)
      fold.updateDisplayBuffer()
      @decorateFold(fold)

    if marker = @getMarker(textBufferMarker.id)
      # The marker might have been removed in some other handler called before
      # this one. Only emit when the marker still exists.
      @emit 'marker-created', marker if Grim.includeDeprecatedAPIs
      @emitter.emit 'did-create-marker', marker

  decorateFold: (fold) ->
    @decorateMarker(fold.marker, type: 'line-number', class: 'folded')

  foldForMarker: (marker) ->
    @foldsByMarkerId[marker.id]

  decorationDidChangeType: (decoration) ->
    if decoration.isType('overlay')
      @overlayDecorationsById[decoration.id] = decoration
    else
      delete @overlayDecorationsById[decoration.id]

  checkScreenLinesInvariant: ->
    return if @isSoftWrapped()
    return if _.size(@foldsByMarkerId) > 0

    screenLinesCount = @screenLines.length
    tokenizedLinesCount = @tokenizedBuffer.getLineCount()
    bufferLinesCount = @buffer.getLineCount()

    atom.assert screenLinesCount is tokenizedLinesCount, "Display buffer line count out of sync with tokenized buffer", (error) ->
      error.metadata = {screenLinesCount, tokenizedLinesCount, bufferLinesCount}

    atom.assert screenLinesCount is bufferLinesCount, "Display buffer line count out of sync with buffer", (error) ->
      error.metadata = {screenLinesCount, tokenizedLinesCount, bufferLinesCount}

if Grim.includeDeprecatedAPIs
  DisplayBuffer.properties
    softWrapped: null
    editorWidthInChars: null
    lineHeightInPixels: null
    defaultCharWidth: null
    height: null
    width: null
    scrollTop: 0
    scrollLeft: 0
    scrollWidth: 0
    verticalScrollbarWidth: 15
    horizontalScrollbarHeight: 15

  EmitterMixin = require('emissary').Emitter

  DisplayBuffer::on = (eventName) ->
    switch eventName
      when 'changed'
        Grim.deprecate("Use DisplayBuffer::onDidChange instead")
      when 'grammar-changed'
        Grim.deprecate("Use DisplayBuffer::onDidChangeGrammar instead")
      when 'soft-wrap-changed'
        Grim.deprecate("Use DisplayBuffer::onDidChangeSoftWrap instead")
      when 'character-widths-changed'
        Grim.deprecate("Use DisplayBuffer::onDidChangeCharacterWidths instead")
      when 'decoration-added'
        Grim.deprecate("Use DisplayBuffer::onDidAddDecoration instead")
      when 'decoration-removed'
        Grim.deprecate("Use DisplayBuffer::onDidRemoveDecoration instead")
      when 'decoration-changed'
        Grim.deprecate("Use decoration.getMarker().onDidChange() instead")
      when 'decoration-updated'
        Grim.deprecate("Use Decoration::onDidChangeProperties instead")
      when 'marker-created'
        Grim.deprecate("Use Decoration::onDidCreateMarker instead")
      when 'markers-updated'
        Grim.deprecate("Use Decoration::onDidUpdateMarkers instead")
      else
        Grim.deprecate("DisplayBuffer::on is deprecated. Use event subscription methods instead.")

    EmitterMixin::on.apply(this, arguments)
else
  DisplayBuffer::softWrapped = null
  DisplayBuffer::editorWidthInChars = null
  DisplayBuffer::lineHeightInPixels = null
  DisplayBuffer::defaultCharWidth = null
  DisplayBuffer::height = null
  DisplayBuffer::width = null
  DisplayBuffer::scrollTop = 0
  DisplayBuffer::scrollLeft = 0
  DisplayBuffer::scrollWidth = 0
  DisplayBuffer::verticalScrollbarWidth = 15
  DisplayBuffer::horizontalScrollbarHeight = 15
