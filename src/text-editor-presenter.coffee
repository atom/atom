{CompositeDisposable, Emitter} = require 'event-kit'
{Point} = require 'text-buffer'
_ = require 'underscore-plus'

module.exports =
class TextEditorPresenter
  toggleCursorBlinkHandle: null
  startBlinkingCursorsAfterDelay: null

  constructor: ({@model, @clientHeight, @clientWidth, @scrollTop, @scrollLeft, @lineHeight, @baseCharacterWidth, @lineOverdrawMargin, @cursorBlinkPeriod, @cursorBlinkResumeDelay}) ->
    @disposables = new CompositeDisposable
    @emitter = new Emitter
    @charWidthsByScope = {}
    @observeModel()
    @observeConfig()
    @buildState()
    @startBlinkingCursors()

  destroy: ->
    @disposables.dispose()

  onDidUpdateState: (callback) ->
    @emitter.on 'did-update-state', callback

  observeModel: ->
    @disposables.add @model.onDidChange(@updateState.bind(this))
    @disposables.add @model.onDidChangeSoftWrapped(@updateState.bind(this))
    @disposables.add @model.onDidChangeGrammar(@updateContentState.bind(this))
    @disposables.add @model.onDidChangeMini(@updateLinesState.bind(this))
    @disposables.add @model.onDidAddDecoration(@didAddDecoration.bind(this))
    @disposables.add @model.onDidAddCursor(@didAddCursor.bind(this))
    @observeLineDecoration(decoration) for decoration in @model.getLineDecorations()
    @observeHighlightDecoration(decoration) for decoration in @model.getHighlightDecorations()
    @observeCursor(cursor) for cursor in @model.getCursors()

  observeConfig: ->
    @disposables.add atom.config.onDidChange 'editor.showIndentGuide', scope: @model.getRootScopeDescriptor(), @updateContentState.bind(this)

  buildState: ->
    @state =
      content:
        lines: {}
        blinkCursorsOff: false
    @updateState()

  updateState: ->
    @updateContentState()
    @updateLinesState()
    @updateCursorsState()
    @updateHighlightsState()

  updateContentState: ->
    @state.content.scrollWidth = @computeScrollWidth()
    @state.content.scrollHeight = @computeScrollHeight()
    @state.content.scrollTop = @getScrollTop()
    @state.content.scrollLeft = @getScrollLeft()
    @state.content.indentGuidesVisible = atom.config.get('editor.showIndentGuide', scope: @model.getRootScopeDescriptor())
    @emitter.emit 'did-update-state'

  updateLinesState: ->
    visibleLineIds = {}
    startRow = @getStartRow()
    endRow = @getEndRow()

    row = startRow
    while row < endRow
      line = @model.tokenizedLineForScreenRow(row)
      visibleLineIds[line.id] = true
      if @state.content.lines.hasOwnProperty(line.id)
        @updateLineState(row, line)
      else
        @buildLineState(row, line)
      row++

    for id, line of @state.content.lines
      unless visibleLineIds.hasOwnProperty(id)
        delete @state.content.lines[id]

    @emitter.emit 'did-update-state'

  updateLineState: (row, line) ->
    lineState = @state.content.lines[line.id]
    lineState.screenRow = row
    lineState.top = row * @getLineHeight()
    lineState.decorationClasses = @lineDecorationClassesForRow(row)

  buildLineState: (row, line) ->
    @state.content.lines[line.id] =
      screenRow: row
      text: line.text
      tokens: line.tokens
      endOfLineInvisibles: line.endOfLineInvisibles
      indentLevel: line.indentLevel
      tabLength: line.tabLength
      fold: line.fold
      top: row * @getLineHeight()
      decorationClasses: @lineDecorationClassesForRow(row)

  updateCursorsState: ->
    startRow = @getStartRow()
    endRow = @getEndRow()
    @state.content.cursors = {}

    for cursor in @model.getCursors()
      if cursor.isVisible() and startRow <= cursor.getScreenRow() < endRow
        pixelRect = @pixelRectForScreenRange(cursor.getScreenRange())
        pixelRect.width = @getBaseCharacterWidth() if pixelRect.width is 0
        @state.content.cursors[cursor.id] = pixelRect

    @emitter.emit 'did-update-state'

  updateHighlightsState: ->
    startRow = @getStartRow()
    endRow = @getEndRow()
    @state.content.highlights = {}

    for decoration in @model.getHighlightDecorations()
      screenRange = decoration.getMarker().getScreenRange()
      if screenRange.intersectsRowRange(startRow, endRow - 1)
        if screenRange.start.row < startRow
          screenRange.start.row = startRow
          screenRange.start.column = 0
        if screenRange.end.row >= endRow
          screenRange.end.row = endRow
          screenRange.end.column = 0
        continue if screenRange.isEmpty()
        @state.content.highlights[decoration.id] =
          class: decoration.getProperties().class
          regions: @buildHighlightRegions(screenRange)

  buildHighlightRegions: (screenRange) ->
    lineHeightInPixels = @getLineHeight()
    startPixelPosition = @pixelPositionForScreenPosition(screenRange.start, true)
    endPixelPosition = @pixelPositionForScreenPosition(screenRange.end, true)
    spannedRows = screenRange.end.row - screenRange.start.row + 1

    if spannedRows is 1
      [
        top: startPixelPosition.top
        height: lineHeightInPixels
        left: startPixelPosition.left
        width: endPixelPosition.left - startPixelPosition.left
      ]
    else
      regions = []

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
        regions.push(
          top: endPixelPosition.top
          height: lineHeightInPixels
          left: 0
          width: endPixelPosition.left
        )

      regions

  getStartRow: ->
    startRow = Math.floor(@getScrollTop() / @getLineHeight()) - @lineOverdrawMargin
    Math.max(0, startRow)

  getEndRow: ->
    startRow = Math.floor(@getScrollTop() / @getLineHeight())
    visibleLinesCount = Math.ceil(@getClientHeight() / @getLineHeight()) + 1
    endRow = startRow + visibleLinesCount + @lineOverdrawMargin
    Math.min(@model.getScreenLineCount(), endRow)

  computeScrollWidth: ->
    contentWidth = @pixelPositionForScreenPosition([@model.getLongestScreenRow(), Infinity]).left
    contentWidth += 1 unless @model.isSoftWrapped() # account for cursor width
    Math.max(contentWidth, @getClientWidth())

  computeScrollHeight: ->
    @getLineHeight() * @model.getScreenLineCount()

  lineDecorationClassesForRow: (row) ->
    return null if @model.isMini()

    decorationClasses = null
    for markerId, decorations of @model.decorationsForScreenRowRange(row, row) when @model.getMarker(markerId).isValid()
      for decoration in decorations when decoration.isType('line')
        properties = decoration.getProperties()
        range = decoration.getMarker().getScreenRange()

        if range.isEmpty()
          continue if properties.onlyNonEmpty
        else
          continue if properties.onlyEmpty
          continue if row is range.end.row and range.end.column is 0

        decorationClasses ?= []
        decorationClasses.push(properties.class)

    decorationClasses

  getCursorBlinkPeriod: -> @cursorBlinkPeriod

  getCursorBlinkResumeDelay: -> @cursorBlinkResumeDelay

  setScrollTop: (@scrollTop) ->
    @updateContentState()
    @updateLinesState()
    @updateCursorsState()
    @updateHighlightsState()

  getScrollTop: -> @scrollTop

  setScrollLeft: (@scrollLeft) ->
    @updateContentState()

  getScrollLeft: -> @scrollLeft

  setClientHeight: (@clientHeight) ->
    @updateLinesState()
    @updateCursorsState()
    @updateHighlightsState()

  getClientHeight: ->
    @clientHeight ? @model.getScreenLineCount() * @getLineHeight()

  setClientWidth: (@clientWidth) ->
    @updateContentState()
    @updateLinesState()

  getClientWidth: -> @clientWidth

  setLineHeight: (@lineHeight) ->
    @updateContentState()
    @updateLinesState()
    @updateCursorsState()
    @updateHighlightsState()

  getLineHeight: -> @lineHeight

  setBaseCharacterWidth: (@baseCharacterWidth) ->
    @characterWidthsChanged()

  getBaseCharacterWidth: -> @baseCharacterWidth

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
    @updateContentState()
    @updateLinesState()
    @updateCursorsState()
    @updateHighlightsState()

  clearScopedCharWidths: ->
    @charWidthsByScope = {}

  pixelPositionForScreenPosition: (screenPosition, clip=true) ->
    screenPosition = Point.fromObject(screenPosition)
    screenPosition = @model.clipScreenPosition(screenPosition) if clip

    targetRow = screenPosition.row
    targetColumn = screenPosition.column
    baseCharacterWidth = @getBaseCharacterWidth()

    top = targetRow * @getLineHeight()
    left = 0
    column = 0
    for token in @model.tokenizedLineForScreenRow(targetRow).tokens
      charWidths = @getScopedCharWidths(token.scopes)

      valueIndex = 0
      while valueIndex < token.value.length
        if token.hasPairedCharacter
          char = token.value.substr(valueIndex, 2)
          charLength = 2
          valueIndex += 2
        else
          char = token.value[valueIndex]
          charLength = 1
          valueIndex++

        return {top, left} if column is targetColumn

        left += charWidths[char] ? baseCharacterWidth unless char is '\0'
        column += charLength
    {top, left}

  pixelRectForScreenRange: (screenRange) ->
    if screenRange.end.row > screenRange.start.row
      top = @pixelPositionForScreenPosition(screenRange.start).top
      left = 0
      height = (screenRange.end.row - screenRange.start.row + 1) * @getLineHeight()
      width = @getScrollWidth()
    else
      {top, left} = @pixelPositionForScreenPosition(screenRange.start, false)
      height = @getLineHeight()
      width = @pixelPositionForScreenPosition(screenRange.end, false).left - left

    {top, left, width, height}

  observeLineDecoration: (decoration) ->
    markerDidChangeDisposable = decoration.getMarker().onDidChange(@updateLinesState.bind(this))
    didDestroyDisposable = decoration.onDidDestroy =>
      @disposables.remove(markerDidChangeDisposable)
      @disposables.remove(didDestroyDisposable)
      @updateLinesState()

    @disposables.add(markerDidChangeDisposable)
    @disposables.add(didDestroyDisposable)

  observeHighlightDecoration: (decoration) ->
    markerDidChangeDisposable = decoration.getMarker().onDidChange(@updateHighlightsState.bind(this))
    didDestroyDisposable = decoration.onDidDestroy =>
      @disposables.remove(markerDidChangeDisposable)
      @disposables.remove(didDestroyDisposable)
      @updateHighlightsState()

    @disposables.add(markerDidChangeDisposable)
    @disposables.add(didDestroyDisposable)

  didAddDecoration: (decoration) ->
    if decoration.isType('line')
      @observeLineDecoration(decoration)
      @updateLinesState()
    else if decoration.isType('highlight')
      @observeHighlightDecoration(decoration)
      @updateHighlightsState()

  observeCursor: (cursor) ->
    didChangePositionDisposable = cursor.onDidChangePosition =>
      @pauseCursorBlinking()
      @updateCursorsState()

    didChangeVisibilityDisposable = cursor.onDidChangeVisibility(@updateCursorsState.bind(this))

    didDestroyDisposable = cursor.onDidDestroy =>
      @disposables.remove(didChangePositionDisposable)
      @disposables.remove(didChangeVisibilityDisposable)
      @disposables.remove(didDestroyDisposable)
      @updateCursorsState()

    @disposables.add(didChangePositionDisposable)
    @disposables.add(didChangeVisibilityDisposable)
    @disposables.add(didDestroyDisposable)

  didAddCursor: (cursor) ->
    @observeCursor(cursor)
    @pauseCursorBlinking()
    @updateCursorsState()

  startBlinkingCursors: ->
    @toggleCursorBlinkHandle = setInterval(@toggleCursorBlink.bind(this), @getCursorBlinkPeriod() / 2)

  stopBlinkingCursors: ->
    clearInterval(@toggleCursorBlinkHandle)

  toggleCursorBlink: ->
    @state.content.blinkCursorsOff = not @state.content.blinkCursorsOff
    @emitter.emit 'did-update-state'

  pauseCursorBlinking: ->
    @state.content.blinkCursorsOff = false
    @stopBlinkingCursors()
    @startBlinkingCursorsAfterDelay ?= _.debounce(@startBlinkingCursors, @getCursorBlinkResumeDelay())
    @startBlinkingCursorsAfterDelay()
    @emitter.emit 'did-update-state'
