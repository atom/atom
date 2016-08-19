{CompositeDisposable, Disposable, Emitter} = require 'event-kit'
{Point, Range} = require 'text-buffer'
_ = require 'underscore-plus'
Decoration = require './decoration'

module.exports =
class TextEditorPresenter
  toggleCursorBlinkHandle: null
  startBlinkingCursorsAfterDelay: null
  stoppedScrollingTimeoutId: null
  mouseWheelScreenRow: null
  overlayDimensions: {}
  minimumReflowInterval: 200

  constructor: (params) ->
    {@model, @lineTopIndex} = params
    @model.presenter = this
    {@cursorBlinkPeriod, @cursorBlinkResumeDelay, @stoppedScrollingDelay, @tileSize, @autoHeight} = params
    {@contentFrameWidth} = params
    {@displayLayer} = @model

    @gutterWidth = 0
    @tileSize ?= 6
    @realScrollTop = @scrollTop
    @realScrollLeft = @scrollLeft
    @disposables = new CompositeDisposable
    @emitter = new Emitter
    @linesByScreenRow = new Map
    @visibleHighlights = {}
    @characterWidthsByScope = {}
    @lineDecorationsByScreenRow = {}
    @lineNumberDecorationsByScreenRow = {}
    @customGutterDecorationsByGutterName = {}
    @observedBlockDecorations = new Set()
    @invalidatedDimensionsByBlockDecoration = new Set()
    @invalidateAllBlockDecorationsDimensions = false
    @screenRowsToMeasure = []
    @transferMeasurementsToModel()
    @transferMeasurementsFromModel()
    @observeModel()
    @buildState()
    @invalidateState()
    @startBlinkingCursors() if @focused
    @startReflowing() if @continuousReflow
    @updating = false

  setLinesYardstick: (@linesYardstick) ->

  getLinesYardstick: -> @linesYardstick

  destroy: ->
    @disposables.dispose()
    clearTimeout(@stoppedScrollingTimeoutId) if @stoppedScrollingTimeoutId?
    clearInterval(@reflowingInterval) if @reflowingInterval?
    @stopBlinkingCursors()

  # Calls your `callback` when some changes in the model occurred and the current state has been updated.
  onDidUpdateState: (callback) ->
    @emitter.on 'did-update-state', callback

  emitDidUpdateState: ->
    @emitter.emit "did-update-state" if @isBatching()

  transferMeasurementsToModel: ->
    @model.setLineHeightInPixels(@lineHeight) if @lineHeight?
    @model.setDefaultCharWidth(@baseCharacterWidth) if @baseCharacterWidth?

  transferMeasurementsFromModel: ->
    @editorWidthInChars = @model.getEditorWidthInChars()

  # Private: Determines whether {TextEditorPresenter} is currently batching changes.
  # Returns a {Boolean}, `true` if is collecting changes, `false` if is applying them.
  isBatching: ->
    @updating is false

  getPreMeasurementState: ->
    @updating = true

    @updateVerticalDimensions()
    @updateScrollbarDimensions()

    @commitPendingLogicalScrollTopPosition()
    @commitPendingScrollTopPosition()

    @updateStartRow()
    @updateEndRow()
    @updateCommonGutterState()
    @updateReflowState()

    @updateLines()

    if @shouldUpdateDecorations
      @fetchDecorations()
      @updateLineDecorations()
      @updateBlockDecorations()

    @updateTilesState()

    @updating = false
    @state

  getPostMeasurementState: ->
    @updating = true

    @updateHorizontalDimensions()
    @commitPendingLogicalScrollLeftPosition()
    @commitPendingScrollLeftPosition()
    @clearPendingScrollPosition()
    @updateRowsPerPage()

    @updateLines()

    @updateVerticalScrollState()
    @updateHorizontalScrollState()
    @updateScrollbarsState()
    @updateHiddenInputState()
    @updateContentState()
    @updateFocusedState()
    @updateHeightState()
    @updateWidthState()
    @updateHighlightDecorations() if @shouldUpdateDecorations
    @updateTilesState()
    @updateCursorsState()
    @updateOverlaysState()
    @updateLineNumberGutterState()
    @updateGutterOrderState()
    @updateCustomGutterDecorationState()
    @updating = false

    @resetTrackedUpdates()
    @state

  resetTrackedUpdates: ->
    @shouldUpdateDecorations = false

  invalidateState: ->
    @shouldUpdateDecorations = true

  observeModel: ->
    @disposables.add @model.displayLayer.onDidChangeSync (changes) =>
      for change in changes
        startRow = change.start.row
        endRow = startRow + change.oldExtent.row
        @spliceBlockDecorationsInRange(startRow, endRow, change.newExtent.row - change.oldExtent.row)
      @shouldUpdateDecorations = true
      @emitDidUpdateState()

    @disposables.add @model.onDidUpdateDecorations =>
      @shouldUpdateDecorations = true
      @emitDidUpdateState()

    @disposables.add @model.onDidAddDecoration(@didAddBlockDecoration.bind(this))

    for decoration in @model.getDecorations({type: 'block'})
      this.didAddBlockDecoration(decoration)

    @disposables.add @model.onDidChangeGrammar(@didChangeGrammar.bind(this))
    @disposables.add @model.onDidChangePlaceholderText(@emitDidUpdateState.bind(this))
    @disposables.add @model.onDidChangeMini =>
      @shouldUpdateDecorations = true
      @emitDidUpdateState()

    @disposables.add @model.onDidChangeLineNumberGutterVisible(@emitDidUpdateState.bind(this))

    @disposables.add @model.onDidAddCursor(@didAddCursor.bind(this))
    @disposables.add @model.onDidRequestAutoscroll(@requestAutoscroll.bind(this))
    @disposables.add @model.onDidChangeFirstVisibleScreenRow(@didChangeFirstVisibleScreenRow.bind(this))
    @observeCursor(cursor) for cursor in @model.getCursors()
    @disposables.add @model.onDidAddGutter(@didAddGutter.bind(this))
    return

  didChangeScrollPastEnd: ->
    @updateScrollHeight()
    @emitDidUpdateState()

  didChangeShowLineNumbers: ->
    @emitDidUpdateState()

  didChangeGrammar: ->
    @emitDidUpdateState()

  buildState: ->
    @state =
      horizontalScrollbar: {}
      verticalScrollbar: {}
      hiddenInput: {}
      content:
        scrollingVertically: false
        cursorsVisible: false
        tiles: {}
        highlights: {}
        overlays: {}
        cursors: {}
        blockDecorations: {}
      gutters: []
    # Shared state that is copied into ``@state.gutters`.
    @sharedGutterStyles = {}
    @customGutterDecorations = {}
    @lineNumberGutter =
      tiles: {}

  setContinuousReflow: (@continuousReflow) ->
    if @continuousReflow
      @startReflowing()
    else
      @stopReflowing()

  updateReflowState: ->
    @state.content.continuousReflow = @continuousReflow
    @lineNumberGutter.continuousReflow = @continuousReflow

  startReflowing: ->
    @reflowingInterval = setInterval(@emitDidUpdateState.bind(this), @minimumReflowInterval)

  stopReflowing: ->
    clearInterval(@reflowingInterval)
    @reflowingInterval = null

  updateFocusedState: ->
    @state.focused = @focused

  updateHeightState: ->
    if @autoHeight
      @state.height = @contentHeight
    else
      @state.height = null

  updateWidthState: ->
    if @model.getAutoWidth()
      @state.width = @state.content.width + @gutterWidth
    else
      @state.width = null

  updateVerticalScrollState: ->
    @state.content.scrollHeight = @scrollHeight
    @sharedGutterStyles.scrollHeight = @scrollHeight
    @state.verticalScrollbar.scrollHeight = @scrollHeight

    @state.content.scrollTop = @scrollTop
    @sharedGutterStyles.scrollTop = @scrollTop
    @state.verticalScrollbar.scrollTop = @scrollTop

  updateHorizontalScrollState: ->
    @state.content.scrollWidth = @scrollWidth
    @state.horizontalScrollbar.scrollWidth = @scrollWidth

    @state.content.scrollLeft = @scrollLeft
    @state.horizontalScrollbar.scrollLeft = @scrollLeft

  updateScrollbarsState: ->
    @state.horizontalScrollbar.visible = @horizontalScrollbarHeight > 0
    @state.horizontalScrollbar.height = @measuredHorizontalScrollbarHeight
    @state.horizontalScrollbar.right = @verticalScrollbarWidth

    @state.verticalScrollbar.visible = @verticalScrollbarWidth > 0
    @state.verticalScrollbar.width = @measuredVerticalScrollbarWidth
    @state.verticalScrollbar.bottom = @horizontalScrollbarHeight

  updateHiddenInputState: ->
    return unless lastCursor = @model.getLastCursor()

    {top, left, height, width} = @pixelRectForScreenRange(lastCursor.getScreenRange())

    if @focused
      @state.hiddenInput.top = Math.max(Math.min(top, @clientHeight - height), 0)
      @state.hiddenInput.left = Math.max(Math.min(left, @clientWidth - width), 0)
    else
      @state.hiddenInput.top = 0
      @state.hiddenInput.left = 0

    @state.hiddenInput.height = height
    @state.hiddenInput.width = Math.max(width, 2)

  updateContentState: ->
    if @boundingClientRect?
      @sharedGutterStyles.maxHeight = @boundingClientRect.height
      @state.content.maxHeight = @boundingClientRect.height

    verticalScrollbarWidth = @verticalScrollbarWidth ? 0
    contentFrameWidth = @contentFrameWidth ? 0
    contentWidth = @contentWidth ? 0
    if @model.getAutoWidth()
      @state.content.width = contentWidth + verticalScrollbarWidth
    else
      @state.content.width = Math.max(contentWidth + verticalScrollbarWidth, contentFrameWidth)
    @state.content.scrollWidth = @scrollWidth
    @state.content.scrollLeft = @scrollLeft
    @state.content.backgroundColor = if @model.isMini() then null else @backgroundColor
    @state.content.placeholderText = if @model.isEmpty() then @model.getPlaceholderText() else null

  tileForRow: (row) ->
    row - (row % @tileSize)

  constrainRow: (row) ->
    Math.max(0, Math.min(row, @model.getScreenLineCount()))

  getStartTileRow: ->
    @constrainRow(@tileForRow(@startRow ? 0))

  getEndTileRow: ->
    @constrainRow(@tileForRow(@endRow ? 0))

  isValidScreenRow: (screenRow) ->
    screenRow >= 0 and screenRow < @model.getScreenLineCount()

  getScreenRowsToRender: ->
    startRow = @getStartTileRow()
    endRow = @constrainRow(@getEndTileRow() + @tileSize)

    screenRows = [startRow...endRow]
    longestScreenRow = @model.getLongestScreenRow()
    if longestScreenRow?
      screenRows.push(longestScreenRow)
    if @screenRowsToMeasure?
      screenRows.push(@screenRowsToMeasure...)

    screenRows = screenRows.filter @isValidScreenRow.bind(this)
    screenRows.sort (a, b) -> a - b
    _.uniq(screenRows, true)

  getScreenRangesToRender: ->
    screenRows = @getScreenRowsToRender()
    screenRows.push(Infinity) # makes the loop below inclusive

    startRow = screenRows[0]
    endRow = startRow - 1
    screenRanges = []
    for row in screenRows
      if row is endRow + 1
        endRow++
      else
        screenRanges.push([startRow, endRow])
        startRow = endRow = row

    screenRanges

  setScreenRowsToMeasure: (screenRows) ->
    return if not screenRows? or screenRows.length is 0

    @screenRowsToMeasure = screenRows
    @shouldUpdateDecorations = true

  clearScreenRowsToMeasure: ->
    @screenRowsToMeasure = []

  updateTilesState: ->
    return unless @startRow? and @endRow? and @lineHeight?

    screenRows = @getScreenRowsToRender()
    visibleTiles = {}
    startRow = screenRows[0]
    endRow = screenRows[screenRows.length - 1]
    screenRowIndex = screenRows.length - 1
    zIndex = 0

    for tileStartRow in [@tileForRow(endRow)..@tileForRow(startRow)] by -@tileSize
      tileEndRow = @constrainRow(tileStartRow + @tileSize)
      rowsWithinTile = []

      while screenRowIndex >= 0
        currentScreenRow = screenRows[screenRowIndex]
        break if currentScreenRow < tileStartRow
        rowsWithinTile.push(currentScreenRow)
        screenRowIndex--

      continue if rowsWithinTile.length is 0

      top = Math.round(@lineTopIndex.pixelPositionBeforeBlocksForRow(tileStartRow))
      bottom = Math.round(@lineTopIndex.pixelPositionBeforeBlocksForRow(tileEndRow))
      height = bottom - top

      tile = @state.content.tiles[tileStartRow] ?= {}
      tile.top = top - @scrollTop
      tile.left = -@scrollLeft
      tile.height = height
      tile.display = "block"
      tile.zIndex = zIndex
      tile.highlights ?= {}

      gutterTile = @lineNumberGutter.tiles[tileStartRow] ?= {}
      gutterTile.top = top - @scrollTop
      gutterTile.height = height
      gutterTile.display = "block"
      gutterTile.zIndex = zIndex

      @updateLinesState(tile, rowsWithinTile)
      @updateLineNumbersState(gutterTile, rowsWithinTile)

      visibleTiles[tileStartRow] = true
      zIndex++

    if @mouseWheelScreenRow? and 0 <= @mouseWheelScreenRow < @model.getScreenLineCount()
      mouseWheelTile = @tileForRow(@mouseWheelScreenRow)

      unless visibleTiles[mouseWheelTile]?
        @lineNumberGutter.tiles[mouseWheelTile].display = "none"
        @state.content.tiles[mouseWheelTile].display = "none"
        visibleTiles[mouseWheelTile] = true

    for id, tile of @state.content.tiles
      continue if visibleTiles.hasOwnProperty(id)

      delete @state.content.tiles[id]
      delete @lineNumberGutter.tiles[id]

  updateLinesState: (tileState, screenRows) ->
    tileState.lines ?= {}
    visibleLineIds = {}
    for screenRow in screenRows
      line = @linesByScreenRow.get(screenRow)
      unless line?
        throw new Error("No line exists for row #{screenRow}. Last screen row: #{@model.getLastScreenRow()}")

      visibleLineIds[line.id] = true
      precedingBlockDecorations = @precedingBlockDecorationsByScreenRow[screenRow] ? []
      followingBlockDecorations = @followingBlockDecorationsByScreenRow[screenRow] ? []
      if tileState.lines.hasOwnProperty(line.id)
        lineState = tileState.lines[line.id]
        lineState.screenRow = screenRow
        lineState.decorationClasses = @lineDecorationClassesForRow(screenRow)
        lineState.precedingBlockDecorations = precedingBlockDecorations
        lineState.followingBlockDecorations = followingBlockDecorations
        lineState.hasPrecedingBlockDecorations = precedingBlockDecorations.length > 0
        lineState.hasFollowingBlockDecorations = followingBlockDecorations.length > 0
      else
        tileState.lines[line.id] =
          screenRow: screenRow
          lineText: line.lineText
          tagCodes: line.tagCodes
          decorationClasses: @lineDecorationClassesForRow(screenRow)
          precedingBlockDecorations: precedingBlockDecorations
          followingBlockDecorations: followingBlockDecorations
          hasPrecedingBlockDecorations: precedingBlockDecorations.length > 0
          hasFollowingBlockDecorations: followingBlockDecorations.length > 0

    for id, line of tileState.lines
      delete tileState.lines[id] unless visibleLineIds.hasOwnProperty(id)
    return

  updateCursorsState: ->
    return unless @startRow? and @endRow? and @hasPixelRectRequirements() and @baseCharacterWidth?

    @state.content.cursors = {}
    for cursor in @model.cursorsForScreenRowRange(@startRow, @endRow - 1) when cursor.isVisible()
      pixelRect = @pixelRectForScreenRange(cursor.getScreenRange())
      pixelRect.width = Math.round(@baseCharacterWidth) if pixelRect.width is 0
      @state.content.cursors[cursor.id] = pixelRect
    return

  updateOverlaysState: ->
    return unless @hasOverlayPositionRequirements()

    visibleDecorationIds = {}

    for decoration in @model.getOverlayDecorations()
      continue unless decoration.getMarker().isValid()

      {item, position, class: klass} = decoration.getProperties()
      if position is 'tail'
        screenPosition = decoration.getMarker().getTailScreenPosition()
      else
        screenPosition = decoration.getMarker().getHeadScreenPosition()

      pixelPosition = @pixelPositionForScreenPosition(screenPosition)

      # Fixed positioning.
      top = @boundingClientRect.top + pixelPosition.top + @lineHeight
      left = @boundingClientRect.left + pixelPosition.left + @gutterWidth

      if overlayDimensions = @overlayDimensions[decoration.id]
        {itemWidth, itemHeight, contentMargin} = overlayDimensions

        rightDiff = left + itemWidth + contentMargin - @windowWidth
        left -= rightDiff if rightDiff > 0

        leftDiff = left + contentMargin
        left -= leftDiff if leftDiff < 0

        if top + itemHeight > @windowHeight and
           top - (itemHeight + @lineHeight) >= 0
          top -= itemHeight + @lineHeight

      pixelPosition.top = top
      pixelPosition.left = left

      overlayState = @state.content.overlays[decoration.id] ?= {item}
      overlayState.pixelPosition = pixelPosition
      overlayState.class = klass if klass?
      visibleDecorationIds[decoration.id] = true

    for id of @state.content.overlays
      delete @state.content.overlays[id] unless visibleDecorationIds[id]

    for id of @overlayDimensions
      delete @overlayDimensions[id] unless visibleDecorationIds[id]

    return

  updateLineNumberGutterState: ->
    @lineNumberGutter.maxLineNumberDigits = @model.getLineCount().toString().length

  updateCommonGutterState: ->
    @sharedGutterStyles.backgroundColor = if @gutterBackgroundColor isnt "rgba(0, 0, 0, 0)"
      @gutterBackgroundColor
    else
      @backgroundColor

  didAddGutter: (gutter) ->
    gutterDisposables = new CompositeDisposable
    gutterDisposables.add gutter.onDidChangeVisible => @emitDidUpdateState()
    gutterDisposables.add gutter.onDidDestroy =>
      @disposables.remove(gutterDisposables)
      gutterDisposables.dispose()
      @emitDidUpdateState()
      # It is not necessary to @updateCustomGutterDecorationState here.
      # The destroyed gutter will be removed from the list of gutters in @state,
      # and thus will be removed from the DOM.
    @disposables.add(gutterDisposables)
    @emitDidUpdateState()

  updateGutterOrderState: ->
    @state.gutters = []
    if @model.isMini()
      return
    for gutter in @model.getGutters()
      isVisible = @gutterIsVisible(gutter)
      if gutter.name is 'line-number'
        content = @lineNumberGutter
      else
        @customGutterDecorations[gutter.name] ?= {}
        content = @customGutterDecorations[gutter.name]
      @state.gutters.push({
        gutter,
        visible: isVisible,
        styles: @sharedGutterStyles,
        content,
      })

  # Updates the decoration state for the gutter with the given gutterName.
  # @customGutterDecorations is an {Object}, with the form:
  #   * gutterName : {
  #     decoration.id : {
  #       top: # of pixels from top
  #       height: # of pixels height of this decoration
  #       item (optional): HTMLElement
  #       class (optional): {String} class
  #     }
  #   }
  updateCustomGutterDecorationState: ->
    return unless @startRow? and @endRow? and @lineHeight?

    if @model.isMini()
      # Mini editors have no gutter decorations.
      # We clear instead of reassigning to preserve the reference.
      @clearAllCustomGutterDecorations()

    for gutter in @model.getGutters()
      gutterName = gutter.name
      gutterDecorations = @customGutterDecorations[gutterName]
      if gutterDecorations
        # Clear the gutter decorations; they are rebuilt.
        # We clear instead of reassigning to preserve the reference.
        @clearDecorationsForCustomGutterName(gutterName)
      else
        @customGutterDecorations[gutterName] = {}

      continue unless @gutterIsVisible(gutter)
      for decorationId, {properties, screenRange} of @customGutterDecorationsByGutterName[gutterName]
        top = @lineTopIndex.pixelPositionAfterBlocksForRow(screenRange.start.row)
        bottom = @lineTopIndex.pixelPositionBeforeBlocksForRow(screenRange.end.row + 1)
        @customGutterDecorations[gutterName][decorationId] =
          top: top
          height: bottom - top
          item: properties.item
          class: properties.class

  clearAllCustomGutterDecorations: ->
    allGutterNames = Object.keys(@customGutterDecorations)
    for gutterName in allGutterNames
      @clearDecorationsForCustomGutterName(gutterName)

  clearDecorationsForCustomGutterName: (gutterName) ->
    gutterDecorations = @customGutterDecorations[gutterName]
    if gutterDecorations
      allDecorationIds = Object.keys(gutterDecorations)
      for decorationId in allDecorationIds
        delete gutterDecorations[decorationId]

  gutterIsVisible: (gutterModel) ->
    isVisible = gutterModel.isVisible()
    if gutterModel.name is 'line-number'
      isVisible = isVisible and @model.doesShowLineNumbers()
    isVisible

  updateLineNumbersState: (tileState, screenRows) ->
    tileState.lineNumbers ?= {}
    visibleLineNumberIds = {}

    for screenRow in screenRows when @isRowRendered(screenRow)
      lineId = @linesByScreenRow.get(screenRow).id
      {bufferRow, softWrappedAtStart: softWrapped} = @displayLayer.softWrapDescriptorForScreenRow(screenRow)
      foldable = not softWrapped and @model.isFoldableAtBufferRow(bufferRow)
      decorationClasses = @lineNumberDecorationClassesForRow(screenRow)
      blockDecorationsBeforeCurrentScreenRowHeight = @lineTopIndex.pixelPositionAfterBlocksForRow(screenRow) - @lineTopIndex.pixelPositionBeforeBlocksForRow(screenRow)
      blockDecorationsHeight = blockDecorationsBeforeCurrentScreenRowHeight
      if screenRow % @tileSize isnt 0
        blockDecorationsAfterPreviousScreenRowHeight = @lineTopIndex.pixelPositionBeforeBlocksForRow(screenRow) - @lineHeight - @lineTopIndex.pixelPositionAfterBlocksForRow(screenRow - 1)
        blockDecorationsHeight += blockDecorationsAfterPreviousScreenRowHeight

      tileState.lineNumbers[lineId] = {screenRow, bufferRow, softWrapped, decorationClasses, foldable, blockDecorationsHeight}
      visibleLineNumberIds[lineId] = true

    for id of tileState.lineNumbers
      delete tileState.lineNumbers[id] unless visibleLineNumberIds[id]

    return

  updateStartRow: ->
    return unless @scrollTop? and @lineHeight?

    @startRow = Math.max(0, @lineTopIndex.rowForPixelPosition(@scrollTop))

  updateEndRow: ->
    return unless @scrollTop? and @lineHeight? and @height?

    @endRow = Math.min(
      @model.getScreenLineCount(),
      @lineTopIndex.rowForPixelPosition(@scrollTop + @height + @lineHeight - 1) + 1
    )

  updateRowsPerPage: ->
    rowsPerPage = Math.floor(@getClientHeight() / @lineHeight)
    if rowsPerPage isnt @rowsPerPage
      @rowsPerPage = rowsPerPage
      @model.setRowsPerPage(@rowsPerPage)

  updateScrollWidth: ->
    return unless @contentWidth? and @clientWidth?

    scrollWidth = Math.max(@contentWidth, @clientWidth)
    unless @scrollWidth is scrollWidth
      @scrollWidth = scrollWidth
      @updateScrollLeft(@scrollLeft)

  updateScrollHeight: ->
    return unless @contentHeight? and @clientHeight?

    contentHeight = @contentHeight
    if @model.getScrollPastEnd()
      extraScrollHeight = @clientHeight - (@lineHeight * 3)
      contentHeight += extraScrollHeight if extraScrollHeight > 0
    scrollHeight = Math.max(contentHeight, @height)

    unless @scrollHeight is scrollHeight
      @scrollHeight = scrollHeight
      @updateScrollTop(@scrollTop)

  updateVerticalDimensions: ->
    if @lineHeight?
      oldContentHeight = @contentHeight
      @contentHeight = Math.round(@lineTopIndex.pixelPositionAfterBlocksForRow(@model.getScreenLineCount()))

    if @contentHeight isnt oldContentHeight
      @updateHeight()
      @updateScrollbarDimensions()
      @updateScrollHeight()

  updateHorizontalDimensions: ->
    if @baseCharacterWidth?
      oldContentWidth = @contentWidth
      rightmostPosition = @model.getRightmostScreenPosition()
      @contentWidth = @pixelPositionForScreenPosition(rightmostPosition).left
      @contentWidth += @scrollLeft
      @contentWidth += 1 unless @model.isSoftWrapped() # account for cursor width

    if @contentWidth isnt oldContentWidth
      @updateScrollbarDimensions()
      @updateClientWidth()
      @updateScrollWidth()

  updateClientHeight: ->
    return unless @height? and @horizontalScrollbarHeight?

    clientHeight = @height - @horizontalScrollbarHeight
    @model.setHeight(clientHeight, true)

    unless @clientHeight is clientHeight
      @clientHeight = clientHeight
      @updateScrollHeight()
      @updateScrollTop(@scrollTop)

  updateClientWidth: ->
    return unless @contentFrameWidth? and @verticalScrollbarWidth?

    if @model.getAutoWidth()
      clientWidth = @contentWidth
    else
      clientWidth = @contentFrameWidth - @verticalScrollbarWidth

    @model.setWidth(clientWidth, true) unless @editorWidthInChars

    unless @clientWidth is clientWidth
      @clientWidth = clientWidth
      @updateScrollWidth()
      @updateScrollLeft(@scrollLeft)

  updateScrollTop: (scrollTop) ->
    scrollTop = @constrainScrollTop(scrollTop)
    if scrollTop isnt @realScrollTop and not Number.isNaN(scrollTop)
      @realScrollTop = scrollTop
      @scrollTop = Math.round(scrollTop)
      @model.setFirstVisibleScreenRow(Math.round(@scrollTop / @lineHeight), true)

      @updateStartRow()
      @updateEndRow()
      @didStartScrolling()
      @emitter.emit 'did-change-scroll-top', @scrollTop

  constrainScrollTop: (scrollTop) ->
    return scrollTop unless scrollTop? and @scrollHeight? and @clientHeight?
    Math.max(0, Math.min(scrollTop, @scrollHeight - @clientHeight))

  updateScrollLeft: (scrollLeft) ->
    scrollLeft = @constrainScrollLeft(scrollLeft)
    if scrollLeft isnt @realScrollLeft and not Number.isNaN(scrollLeft)
      @realScrollLeft = scrollLeft
      @scrollLeft = Math.round(scrollLeft)
      @model.setFirstVisibleScreenColumn(Math.round(@scrollLeft / @baseCharacterWidth))

      @emitter.emit 'did-change-scroll-left', @scrollLeft

  constrainScrollLeft: (scrollLeft) ->
    return scrollLeft unless scrollLeft? and @scrollWidth? and @clientWidth?
    Math.max(0, Math.min(scrollLeft, @scrollWidth - @clientWidth))

  updateScrollbarDimensions: ->
    return unless @contentFrameWidth? and @height?
    return unless @measuredVerticalScrollbarWidth? and @measuredHorizontalScrollbarHeight?
    return unless @contentWidth? and @contentHeight?

    if @model.getAutoWidth()
      clientWidthWithVerticalScrollbar = @contentWidth + @measuredVerticalScrollbarWidth
    else
      clientWidthWithVerticalScrollbar = @contentFrameWidth
    clientWidthWithoutVerticalScrollbar = clientWidthWithVerticalScrollbar - @measuredVerticalScrollbarWidth
    clientHeightWithHorizontalScrollbar = @height
    clientHeightWithoutHorizontalScrollbar = clientHeightWithHorizontalScrollbar - @measuredHorizontalScrollbarHeight

    horizontalScrollbarVisible =
      not @model.isMini() and
        (@contentWidth > clientWidthWithVerticalScrollbar or
         @contentWidth > clientWidthWithoutVerticalScrollbar and @contentHeight > clientHeightWithHorizontalScrollbar)

    verticalScrollbarVisible =
      not @model.isMini() and
        (@contentHeight > clientHeightWithHorizontalScrollbar or
         @contentHeight > clientHeightWithoutHorizontalScrollbar and @contentWidth > clientWidthWithVerticalScrollbar)

    horizontalScrollbarHeight =
      if horizontalScrollbarVisible
        @measuredHorizontalScrollbarHeight
      else
        0

    verticalScrollbarWidth =
      if verticalScrollbarVisible
        @measuredVerticalScrollbarWidth
      else
        0

    unless @horizontalScrollbarHeight is horizontalScrollbarHeight
      @horizontalScrollbarHeight = horizontalScrollbarHeight
      @updateClientHeight()

    unless @verticalScrollbarWidth is verticalScrollbarWidth
      @verticalScrollbarWidth = verticalScrollbarWidth
      @updateClientWidth()

  lineDecorationClassesForRow: (row) ->
    return null if @model.isMini()

    decorationClasses = null
    for id, properties of @lineDecorationsByScreenRow[row]
      decorationClasses ?= []
      decorationClasses.push(properties.class)
    decorationClasses

  lineNumberDecorationClassesForRow: (row) ->
    return null if @model.isMini()

    decorationClasses = null
    for id, properties of @lineNumberDecorationsByScreenRow[row]
      decorationClasses ?= []
      decorationClasses.push(properties.class)
    decorationClasses

  getCursorBlinkPeriod: -> @cursorBlinkPeriod

  getCursorBlinkResumeDelay: -> @cursorBlinkResumeDelay

  setFocused: (focused) ->
    unless @focused is focused
      @focused = focused
      if @focused
        @startBlinkingCursors()
      else
        @stopBlinkingCursors(false)
      @emitDidUpdateState()

  setScrollTop: (scrollTop) ->
    return unless scrollTop?

    @pendingScrollLogicalPosition = null
    @pendingScrollTop = scrollTop

    @shouldUpdateDecorations = true
    @emitDidUpdateState()

  getScrollTop: ->
    @scrollTop

  getRealScrollTop: ->
    @realScrollTop ? @scrollTop

  didStartScrolling: ->
    if @stoppedScrollingTimeoutId?
      clearTimeout(@stoppedScrollingTimeoutId)
      @stoppedScrollingTimeoutId = null
    @stoppedScrollingTimeoutId = setTimeout(@didStopScrolling.bind(this), @stoppedScrollingDelay)

  didStopScrolling: ->
    if @mouseWheelScreenRow?
      @mouseWheelScreenRow = null
      @shouldUpdateDecorations = true

    @emitDidUpdateState()

  setScrollLeft: (scrollLeft) ->
    return unless scrollLeft?

    @pendingScrollLogicalPosition = null
    @pendingScrollLeft = scrollLeft

    @emitDidUpdateState()

  getScrollLeft: ->
    @scrollLeft

  getRealScrollLeft: ->
    @realScrollLeft ? @scrollLeft

  getClientHeight: ->
    if @clientHeight
      @clientHeight
    else
      @explicitHeight - @horizontalScrollbarHeight

  getClientWidth: ->
    if @clientWidth
      @clientWidth
    else
      @contentFrameWidth - @verticalScrollbarWidth

  getScrollBottom: -> @getScrollTop() + @getClientHeight()
  setScrollBottom: (scrollBottom) ->
    @setScrollTop(scrollBottom - @getClientHeight())
    @getScrollBottom()

  getScrollRight: -> @getScrollLeft() + @getClientWidth()
  setScrollRight: (scrollRight) ->
    @setScrollLeft(scrollRight - @getClientWidth())
    @getScrollRight()

  getScrollHeight: ->
    @scrollHeight

  getScrollWidth: ->
    @scrollWidth

  getMaxScrollTop: ->
    scrollHeight = @getScrollHeight()
    clientHeight = @getClientHeight()
    return 0 unless scrollHeight? and clientHeight?

    scrollHeight - clientHeight

  setHorizontalScrollbarHeight: (horizontalScrollbarHeight) ->
    unless @measuredHorizontalScrollbarHeight is horizontalScrollbarHeight
      oldHorizontalScrollbarHeight = @measuredHorizontalScrollbarHeight
      @measuredHorizontalScrollbarHeight = horizontalScrollbarHeight
      @emitDidUpdateState()

  setVerticalScrollbarWidth: (verticalScrollbarWidth) ->
    unless @measuredVerticalScrollbarWidth is verticalScrollbarWidth
      oldVerticalScrollbarWidth = @measuredVerticalScrollbarWidth
      @measuredVerticalScrollbarWidth = verticalScrollbarWidth
      @emitDidUpdateState()

  setAutoHeight: (autoHeight) ->
    unless @autoHeight is autoHeight
      @autoHeight = autoHeight
      @emitDidUpdateState()

  setExplicitHeight: (explicitHeight) ->
    unless @explicitHeight is explicitHeight
      @explicitHeight = explicitHeight
      @updateHeight()
      @shouldUpdateDecorations = true
      @emitDidUpdateState()

  updateHeight: ->
    height = @explicitHeight ? @contentHeight
    unless @height is height
      @height = height
      @updateScrollbarDimensions()
      @updateClientHeight()
      @updateScrollHeight()
      @updateEndRow()

  didChangeAutoWidth: ->
    @emitDidUpdateState()

  setContentFrameWidth: (contentFrameWidth) ->
    if @contentFrameWidth isnt contentFrameWidth or @editorWidthInChars?
      oldContentFrameWidth = @contentFrameWidth
      @contentFrameWidth = contentFrameWidth
      @editorWidthInChars = null
      @updateScrollbarDimensions()
      @updateClientWidth()
      @invalidateAllBlockDecorationsDimensions = true
      @shouldUpdateDecorations = true
      @emitDidUpdateState()

  setBoundingClientRect: (boundingClientRect) ->
    unless @clientRectsEqual(@boundingClientRect, boundingClientRect)
      @boundingClientRect = boundingClientRect
      @invalidateAllBlockDecorationsDimensions = true
      @shouldUpdateDecorations = true
      @emitDidUpdateState()

  clientRectsEqual: (clientRectA, clientRectB) ->
    clientRectA? and clientRectB? and
      clientRectA.top is clientRectB.top and
      clientRectA.left is clientRectB.left and
      clientRectA.width is clientRectB.width and
      clientRectA.height is clientRectB.height

  setWindowSize: (width, height) ->
    if @windowWidth isnt width or @windowHeight isnt height
      @windowWidth = width
      @windowHeight = height
      @invalidateAllBlockDecorationsDimensions = true
      @shouldUpdateDecorations = true

      @emitDidUpdateState()

  setBackgroundColor: (backgroundColor) ->
    unless @backgroundColor is backgroundColor
      @backgroundColor = backgroundColor
      @emitDidUpdateState()

  setGutterBackgroundColor: (gutterBackgroundColor) ->
    unless @gutterBackgroundColor is gutterBackgroundColor
      @gutterBackgroundColor = gutterBackgroundColor
      @emitDidUpdateState()

  setGutterWidth: (gutterWidth) ->
    if @gutterWidth isnt gutterWidth
      @gutterWidth = gutterWidth
      @updateOverlaysState()

  getGutterWidth: ->
    @gutterWidth

  setLineHeight: (lineHeight) ->
    unless @lineHeight is lineHeight
      @lineHeight = lineHeight
      @model.setLineHeightInPixels(@lineHeight)
      @lineTopIndex.setDefaultLineHeight(@lineHeight)
      @restoreScrollTopIfNeeded()
      @model.setLineHeightInPixels(lineHeight)
      @shouldUpdateDecorations = true
      @emitDidUpdateState()

  setMouseWheelScreenRow: (screenRow) ->
    if @mouseWheelScreenRow isnt screenRow
      @mouseWheelScreenRow = screenRow
      @didStartScrolling()

  setBaseCharacterWidth: (baseCharacterWidth, doubleWidthCharWidth, halfWidthCharWidth, koreanCharWidth) ->
    unless @baseCharacterWidth is baseCharacterWidth and @doubleWidthCharWidth is doubleWidthCharWidth and @halfWidthCharWidth is halfWidthCharWidth and koreanCharWidth is @koreanCharWidth
      @baseCharacterWidth = baseCharacterWidth
      @doubleWidthCharWidth = doubleWidthCharWidth
      @halfWidthCharWidth = halfWidthCharWidth
      @koreanCharWidth = koreanCharWidth
      @model.setDefaultCharWidth(baseCharacterWidth, doubleWidthCharWidth, halfWidthCharWidth, koreanCharWidth)
      @restoreScrollLeftIfNeeded()
      @measurementsChanged()

  measurementsChanged: ->
    @invalidateAllBlockDecorationsDimensions = true
    @shouldUpdateDecorations = true
    @emitDidUpdateState()

  hasPixelPositionRequirements: ->
    @lineHeight? and @baseCharacterWidth?

  pixelPositionForScreenPosition: (screenPosition) ->
    position =
      @linesYardstick.pixelPositionForScreenPosition(screenPosition)
    position.top -= @getScrollTop()
    position.left -= @getScrollLeft()

    position.top = Math.round(position.top)
    position.left = Math.round(position.left)

    position

  hasPixelRectRequirements: ->
    @hasPixelPositionRequirements() and @scrollWidth?

  hasOverlayPositionRequirements: ->
    @hasPixelRectRequirements() and @boundingClientRect? and @windowWidth and @windowHeight

  absolutePixelRectForScreenRange: (screenRange) ->
    lineHeight = @model.getLineHeightInPixels()

    if screenRange.end.row > screenRange.start.row
      top = @linesYardstick.pixelPositionForScreenPosition(screenRange.start).top
      left = 0
      height = (screenRange.end.row - screenRange.start.row + 1) * lineHeight
      width = @getScrollWidth()
    else
      {top, left} = @linesYardstick.pixelPositionForScreenPosition(screenRange.start)
      height = lineHeight
      width = @linesYardstick.pixelPositionForScreenPosition(screenRange.end).left - left

    {top, left, width, height}

  pixelRectForScreenRange: (screenRange) ->
    rect = @absolutePixelRectForScreenRange(screenRange)
    rect.top -= @getScrollTop()
    rect.left -= @getScrollLeft()
    rect.top = Math.round(rect.top)
    rect.left = Math.round(rect.left)
    rect.width = Math.round(rect.width)
    rect.height = Math.round(rect.height)
    rect

  updateLines: ->
    @linesByScreenRow.clear()

    for [startRow, endRow] in @getScreenRangesToRender()
      for line, index in @displayLayer.getScreenLines(startRow, endRow + 1)
        @linesByScreenRow.set(startRow + index, line)

  lineIdForScreenRow: (screenRow) ->
    @linesByScreenRow.get(screenRow)?.id

  fetchDecorations: ->
    return unless 0 <= @startRow <= @endRow <= Infinity
    @decorations = @model.decorationsStateForScreenRowRange(@startRow, @endRow - 1)

  updateBlockDecorations: ->
    @blockDecorationsToRenderById = {}
    @precedingBlockDecorationsByScreenRow = {}
    @followingBlockDecorationsByScreenRow = {}
    visibleDecorationsByMarkerId = @model.decorationsForScreenRowRange(@getStartTileRow(), @getEndTileRow() + @tileSize - 1)

    if @invalidateAllBlockDecorationsDimensions
      for decoration in @model.getDecorations(type: 'block')
        @invalidatedDimensionsByBlockDecoration.add(decoration)
      @invalidateAllBlockDecorationsDimensions = false

    for markerId, decorations of visibleDecorationsByMarkerId
      for decoration in decorations when decoration.isType('block')
        @updateBlockDecorationState(decoration, true)

    @invalidatedDimensionsByBlockDecoration.forEach (decoration) =>
      @updateBlockDecorationState(decoration, false)

    for decorationId, decorationState of @state.content.blockDecorations
      continue if @blockDecorationsToRenderById[decorationId]
      continue if decorationState.screenRow is @mouseWheelScreenRow

      delete @state.content.blockDecorations[decorationId]

  updateBlockDecorationState: (decoration, isVisible) ->
    return if @blockDecorationsToRenderById[decoration.getId()]

    screenRow = decoration.getMarker().getHeadScreenPosition().row
    if decoration.getProperties().position is "after"
      @followingBlockDecorationsByScreenRow[screenRow] ?= []
      @followingBlockDecorationsByScreenRow[screenRow].push(decoration)
    else
      @precedingBlockDecorationsByScreenRow[screenRow] ?= []
      @precedingBlockDecorationsByScreenRow[screenRow].push(decoration)
    @state.content.blockDecorations[decoration.getId()] = {decoration, screenRow, isVisible}
    @blockDecorationsToRenderById[decoration.getId()] = true

  updateLineDecorations: ->
    @lineDecorationsByScreenRow = {}
    @lineNumberDecorationsByScreenRow = {}
    @customGutterDecorationsByGutterName = {}

    for decorationId, decorationState of @decorations
      {properties, bufferRange, screenRange, rangeIsReversed} = decorationState
      if Decoration.isType(properties, 'line') or Decoration.isType(properties, 'line-number')
        @addToLineDecorationCaches(decorationId, properties, bufferRange, screenRange, rangeIsReversed)

      else if Decoration.isType(properties, 'gutter') and properties.gutterName?
        @customGutterDecorationsByGutterName[properties.gutterName] ?= {}
        @customGutterDecorationsByGutterName[properties.gutterName][decorationId] = decorationState

    return

  updateHighlightDecorations: ->
    @visibleHighlights = {}

    for decorationId, {properties, screenRange} of @decorations
      if Decoration.isType(properties, 'highlight')
        @updateHighlightState(decorationId, properties, screenRange)

    for tileId, tileState of @state.content.tiles
      for id, highlight of tileState.highlights
        delete tileState.highlights[id] unless @visibleHighlights[tileId]?[id]?

    return

  addToLineDecorationCaches: (decorationId, properties, bufferRange, screenRange, rangeIsReversed) ->
    if screenRange.isEmpty()
      return if properties.onlyNonEmpty
    else
      return if properties.onlyEmpty
      omitLastRow = screenRange.end.column is 0

    if rangeIsReversed
      headScreenPosition = screenRange.start
    else
      headScreenPosition = screenRange.end

    if properties.class is 'folded' and Decoration.isType(properties, 'line-number')
      screenRow = @model.screenRowForBufferRow(bufferRange.start.row)
      @lineNumberDecorationsByScreenRow[screenRow] ?= {}
      @lineNumberDecorationsByScreenRow[screenRow][decorationId] = properties
    else
      for row in [screenRange.start.row..screenRange.end.row] by 1
        continue if properties.onlyHead and row isnt headScreenPosition.row
        continue if omitLastRow and row is screenRange.end.row

        if Decoration.isType(properties, 'line')
          @lineDecorationsByScreenRow[row] ?= {}
          @lineDecorationsByScreenRow[row][decorationId] = properties

        if Decoration.isType(properties, 'line-number')
          @lineNumberDecorationsByScreenRow[row] ?= {}
          @lineNumberDecorationsByScreenRow[row][decorationId] = properties

    return

  intersectRangeWithTile: (range, tileStartRow) ->
    intersectingStartRow = Math.max(tileStartRow, range.start.row)
    intersectingEndRow = Math.min(tileStartRow + @tileSize - 1, range.end.row)
    intersectingRange = new Range(
      new Point(intersectingStartRow, 0),
      new Point(intersectingEndRow, Infinity)
    )

    if intersectingStartRow is range.start.row
      intersectingRange.start.column = range.start.column

    if intersectingEndRow is range.end.row
      intersectingRange.end.column = range.end.column

    intersectingRange

  updateHighlightState: (decorationId, properties, screenRange) ->
    return unless @startRow? and @endRow? and @lineHeight? and @hasPixelPositionRequirements()

    @constrainRangeToVisibleRowRange(screenRange)

    return if screenRange.isEmpty()

    startTile = @tileForRow(screenRange.start.row)
    endTile = @tileForRow(screenRange.end.row)

    for tileStartRow in [startTile..endTile] by @tileSize
      rangeWithinTile = @intersectRangeWithTile(screenRange, tileStartRow)

      continue if rangeWithinTile.isEmpty()

      tileState = @state.content.tiles[tileStartRow] ?= {highlights: {}}
      highlightState = tileState.highlights[decorationId] ?= {}

      highlightState.flashCount = properties.flashCount
      highlightState.flashClass = properties.flashClass
      highlightState.flashDuration = properties.flashDuration
      highlightState.class = properties.class
      highlightState.deprecatedRegionClass = properties.deprecatedRegionClass
      highlightState.regions = @buildHighlightRegions(rangeWithinTile)

      for region in highlightState.regions
        @repositionRegionWithinTile(region, tileStartRow)

      @visibleHighlights[tileStartRow] ?= {}
      @visibleHighlights[tileStartRow][decorationId] = true

    true

  constrainRangeToVisibleRowRange: (screenRange) ->
    if screenRange.start.row < @startRow
      screenRange.start.row = @startRow
      screenRange.start.column = 0

    if screenRange.end.row < @startRow
      screenRange.end.row = @startRow
      screenRange.end.column = 0

    if screenRange.start.row >= @endRow
      screenRange.start.row = @endRow
      screenRange.start.column = 0

    if screenRange.end.row >= @endRow
      screenRange.end.row = @endRow
      screenRange.end.column = 0

  repositionRegionWithinTile: (region, tileStartRow) ->
    region.top  += @scrollTop - @lineTopIndex.pixelPositionBeforeBlocksForRow(tileStartRow)
    region.left += @scrollLeft

  buildHighlightRegions: (screenRange) ->
    lineHeightInPixels = @lineHeight
    startPixelPosition = @pixelPositionForScreenPosition(screenRange.start)
    endPixelPosition = @pixelPositionForScreenPosition(screenRange.end)
    spannedRows = screenRange.end.row - screenRange.start.row + 1

    regions = []

    if spannedRows is 1
      region =
        top: startPixelPosition.top
        height: lineHeightInPixels
        left: startPixelPosition.left

      if screenRange.end.column is Infinity
        region.right = 0
      else
        region.width = endPixelPosition.left - startPixelPosition.left

      regions.push(region)
    else
      # First row, extending from selection start to the right side of screen
      regions.push(
        top: startPixelPosition.top
        left: startPixelPosition.left
        height: lineHeightInPixels
        right: 0
      )

      # Middle rows, extending from left side to right side of screen
      if spannedRows > 2
        regions.push(
          top: startPixelPosition.top + lineHeightInPixels
          height: endPixelPosition.top - startPixelPosition.top - lineHeightInPixels
          left: 0
          right: 0
        )

      # Last row, extending from left side of screen to selection end
      if screenRange.end.column > 0
        region =
          top: endPixelPosition.top
          height: lineHeightInPixels
          left: 0

        if screenRange.end.column is Infinity
          region.right = 0
        else
          region.width = endPixelPosition.left

        regions.push(region)

    regions

  setOverlayDimensions: (decorationId, itemWidth, itemHeight, contentMargin) ->
    @overlayDimensions[decorationId] ?= {}
    overlayState = @overlayDimensions[decorationId]
    dimensionsAreEqual = overlayState.itemWidth is itemWidth and
      overlayState.itemHeight is itemHeight and
      overlayState.contentMargin is contentMargin
    unless dimensionsAreEqual
      overlayState.itemWidth = itemWidth
      overlayState.itemHeight = itemHeight
      overlayState.contentMargin = contentMargin

      @emitDidUpdateState()

  setBlockDecorationDimensions: (decoration, width, height) ->
    return unless @observedBlockDecorations.has(decoration)

    @lineTopIndex.resizeBlock(decoration.getId(), height)

    @invalidatedDimensionsByBlockDecoration.delete(decoration)
    @shouldUpdateDecorations = true
    @emitDidUpdateState()

  invalidateBlockDecorationDimensions: (decoration) ->
    @invalidatedDimensionsByBlockDecoration.add(decoration)
    @shouldUpdateDecorations = true
    @emitDidUpdateState()

  spliceBlockDecorationsInRange: (start, end, screenDelta) ->
    return if screenDelta is 0

    oldExtent = end - start
    newExtent = end - start + screenDelta
    invalidatedBlockDecorationIds = @lineTopIndex.splice(start, oldExtent, newExtent)
    invalidatedBlockDecorationIds.forEach (id) =>
      decoration = @model.decorationForId(id)
      newScreenPosition = decoration.getMarker().getHeadScreenPosition()
      @lineTopIndex.moveBlock(id, newScreenPosition.row)
      @invalidatedDimensionsByBlockDecoration.add(decoration)

  didAddBlockDecoration: (decoration) ->
    return if not decoration.isType('block') or @observedBlockDecorations.has(decoration)

    didMoveDisposable = decoration.getMarker().bufferMarker.onDidChange (markerEvent) =>
      @didMoveBlockDecoration(decoration, markerEvent)

    didDestroyDisposable = decoration.onDidDestroy =>
      @disposables.remove(didMoveDisposable)
      @disposables.remove(didDestroyDisposable)
      didMoveDisposable.dispose()
      didDestroyDisposable.dispose()
      @didDestroyBlockDecoration(decoration)

    isAfter = decoration.getProperties().position is "after"
    @lineTopIndex.insertBlock(decoration.getId(), decoration.getMarker().getHeadScreenPosition().row, 0, isAfter)

    @observedBlockDecorations.add(decoration)
    @invalidateBlockDecorationDimensions(decoration)
    @disposables.add(didMoveDisposable)
    @disposables.add(didDestroyDisposable)
    @shouldUpdateDecorations = true
    @emitDidUpdateState()

  didMoveBlockDecoration: (decoration, markerEvent) ->
    # Don't move blocks after a text change, because we already splice on buffer
    # change.
    return if markerEvent.textChanged

    @lineTopIndex.moveBlock(decoration.getId(), decoration.getMarker().getHeadScreenPosition().row)
    @shouldUpdateDecorations = true
    @emitDidUpdateState()

  didDestroyBlockDecoration: (decoration) ->
    return unless @observedBlockDecorations.has(decoration)

    @lineTopIndex.removeBlock(decoration.getId())
    @observedBlockDecorations.delete(decoration)
    @invalidatedDimensionsByBlockDecoration.delete(decoration)
    @shouldUpdateDecorations = true
    @emitDidUpdateState()

  observeCursor: (cursor) ->
    didChangePositionDisposable = cursor.onDidChangePosition =>
      @pauseCursorBlinking()

      @emitDidUpdateState()

    didChangeVisibilityDisposable = cursor.onDidChangeVisibility =>

      @emitDidUpdateState()

    didDestroyDisposable = cursor.onDidDestroy =>
      @disposables.remove(didChangePositionDisposable)
      @disposables.remove(didChangeVisibilityDisposable)
      @disposables.remove(didDestroyDisposable)

      @emitDidUpdateState()

    @disposables.add(didChangePositionDisposable)
    @disposables.add(didChangeVisibilityDisposable)
    @disposables.add(didDestroyDisposable)

  didAddCursor: (cursor) ->
    @observeCursor(cursor)
    @pauseCursorBlinking()

    @emitDidUpdateState()

  startBlinkingCursors: ->
    unless @isCursorBlinking()
      @state.content.cursorsVisible = true
      @toggleCursorBlinkHandle = setInterval(@toggleCursorBlink.bind(this), @getCursorBlinkPeriod() / 2)

  isCursorBlinking: ->
    @toggleCursorBlinkHandle?

  stopBlinkingCursors: (visible) ->
    if @isCursorBlinking()
      @state.content.cursorsVisible = visible
      clearInterval(@toggleCursorBlinkHandle)
      @toggleCursorBlinkHandle = null

  toggleCursorBlink: ->
    @state.content.cursorsVisible = not @state.content.cursorsVisible
    @emitDidUpdateState()

  pauseCursorBlinking: ->
    if @isCursorBlinking()
      @stopBlinkingCursors(true)
      @startBlinkingCursorsAfterDelay ?= _.debounce(@startBlinkingCursors, @getCursorBlinkResumeDelay())
      @startBlinkingCursorsAfterDelay()
      @emitDidUpdateState()

  requestAutoscroll: (position) ->
    @pendingScrollLogicalPosition = position
    @pendingScrollTop = null
    @pendingScrollLeft = null
    @shouldUpdateDecorations = true
    @emitDidUpdateState()

  didChangeFirstVisibleScreenRow: (screenRow) ->
    @setScrollTop(@lineTopIndex.pixelPositionAfterBlocksForRow(screenRow))

  getVerticalScrollMarginInPixels: ->
    Math.round(@model.getVerticalScrollMargin() * @lineHeight)

  getHorizontalScrollMarginInPixels: ->
    Math.round(@model.getHorizontalScrollMargin() * @baseCharacterWidth)

  getVerticalScrollbarWidth: ->
    @verticalScrollbarWidth

  getHorizontalScrollbarHeight: ->
    @horizontalScrollbarHeight

  commitPendingLogicalScrollTopPosition: ->
    return unless @pendingScrollLogicalPosition?

    {screenRange, options} = @pendingScrollLogicalPosition

    verticalScrollMarginInPixels = @getVerticalScrollMarginInPixels()

    top = @lineTopIndex.pixelPositionAfterBlocksForRow(screenRange.start.row)
    bottom = @lineTopIndex.pixelPositionAfterBlocksForRow(screenRange.end.row) + @lineHeight

    if options?.center
      desiredScrollCenter = (top + bottom) / 2
      unless @getScrollTop() < desiredScrollCenter < @getScrollBottom()
        desiredScrollTop = desiredScrollCenter - @getClientHeight() / 2
        desiredScrollBottom = desiredScrollCenter + @getClientHeight() / 2
    else
      desiredScrollTop = top - verticalScrollMarginInPixels
      desiredScrollBottom = bottom + verticalScrollMarginInPixels

    if options?.reversed ? true
      if desiredScrollBottom > @getScrollBottom()
        @updateScrollTop(desiredScrollBottom - @getClientHeight())
      if desiredScrollTop < @getScrollTop()
        @updateScrollTop(desiredScrollTop)
    else
      if desiredScrollTop < @getScrollTop()
        @updateScrollTop(desiredScrollTop)
      if desiredScrollBottom > @getScrollBottom()
        @updateScrollTop(desiredScrollBottom - @getClientHeight())

  commitPendingLogicalScrollLeftPosition: ->
    return unless @pendingScrollLogicalPosition?

    {screenRange, options} = @pendingScrollLogicalPosition

    horizontalScrollMarginInPixels = @getHorizontalScrollMarginInPixels()

    {left} = @pixelRectForScreenRange(new Range(screenRange.start, screenRange.start))
    {left: right} = @pixelRectForScreenRange(new Range(screenRange.end, screenRange.end))

    left += @scrollLeft
    right += @scrollLeft

    desiredScrollLeft = left - horizontalScrollMarginInPixels
    desiredScrollRight = right + horizontalScrollMarginInPixels

    if options?.reversed ? true
      if desiredScrollRight > @getScrollRight()
        @updateScrollLeft(desiredScrollRight - @getClientWidth())
      if desiredScrollLeft < @getScrollLeft()
        @updateScrollLeft(desiredScrollLeft)
    else
      if desiredScrollLeft < @getScrollLeft()
        @updateScrollLeft(desiredScrollLeft)
      if desiredScrollRight > @getScrollRight()
        @updateScrollLeft(desiredScrollRight - @getClientWidth())

  commitPendingScrollLeftPosition: ->
    if @pendingScrollLeft?
      @updateScrollLeft(@pendingScrollLeft)
      @pendingScrollLeft = null

  commitPendingScrollTopPosition: ->
    if @pendingScrollTop?
      @updateScrollTop(@pendingScrollTop)
      @pendingScrollTop = null

  clearPendingScrollPosition: ->
    @pendingScrollLogicalPosition = null
    @pendingScrollTop = null
    @pendingScrollLeft = null

  canScrollLeftTo: (scrollLeft) ->
    @scrollLeft isnt @constrainScrollLeft(scrollLeft)

  canScrollTopTo: (scrollTop) ->
    @scrollTop isnt @constrainScrollTop(scrollTop)

  restoreScrollTopIfNeeded: ->
    unless @scrollTop?
      @updateScrollTop(@lineTopIndex.pixelPositionAfterBlocksForRow(@model.getFirstVisibleScreenRow()))

  restoreScrollLeftIfNeeded: ->
    unless @scrollLeft?
      @updateScrollLeft(@model.getFirstVisibleScreenColumn() * @baseCharacterWidth)

  onDidChangeScrollTop: (callback) ->
    @emitter.on 'did-change-scroll-top', callback

  onDidChangeScrollLeft: (callback) ->
    @emitter.on 'did-change-scroll-left', callback

  getVisibleRowRange: ->
    [@startRow, @endRow]

  isRowRendered: (row) ->
    @getStartTileRow() <= row < @constrainRow(@getEndTileRow() + @tileSize)

  isOpenTagCode: (tagCode) ->
    @displayLayer.isOpenTagCode(tagCode)

  isCloseTagCode: (tagCode) ->
    @displayLayer.isCloseTagCode(tagCode)

  tagForCode: (tagCode) ->
    @displayLayer.tagForCode(tagCode)
