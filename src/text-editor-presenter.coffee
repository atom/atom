{CompositeDisposable} = require 'event-kit'
{Point} = require 'text-buffer'

module.exports =
class TextEditorPresenter
  constructor: ({@model, @clientHeight, @clientWidth, @scrollTop, @lineHeight, @baseCharacterWidth, @lineOverdrawMargin}) ->
    @disposables = new CompositeDisposable
    @state = {}
    @charWidthsByScope = {}
    @subscribeToModel()
    @buildLinesState()

  destroy: ->
    @disposables.dispose()

  subscribeToModel: ->
    @disposables.add @model.onDidChange(@updateLinesState.bind(this))
    @disposables.add @model.onDidChangeSoftWrapped =>
      @computeScrollWidth()
      @updateLinesState()

  buildLinesState: ->
    @state.lines = {}
    @updateLinesState()

  updateLinesState: ->
    visibleLineIds = {}
    startRow = @getStartRow()
    endRow = @getEndRow()

    row = startRow
    while row < endRow
      line = @model.tokenizedLineForScreenRow(row)
      visibleLineIds[line.id] = true
      if @state.lines.hasOwnProperty(line.id)
        @updateLineState(row, line)
      else
        @buildLineState(row, line)
      row++

    for id, line of @state.lines
      unless visibleLineIds.hasOwnProperty(id)
        delete @state.lines[id]

  updateLineState: (row, line) ->
    lineState = @state.lines[line.id]
    lineState.screenRow = row
    lineState.top = row * @getLineHeight()
    lineState.width = @getScrollWidth()

  buildLineState: (row, line) ->
    @state.lines[line.id] =
      screenRow: row
      text: line.text
      tokens: line.tokens
      endOfLineInvisibles: line.endOfLineInvisibles
      indentLevel: line.indentLevel
      tabLength: line.tabLength
      fold: line.fold
      top: row * @getLineHeight()
      width: @getScrollWidth()

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
    @scrollWidth = Math.max(contentWidth, @getClientWidth())

  getScrollWidth: -> @scrollWidth ? @computeScrollWidth()

  setScrollTop: (@scrollTop) ->
    @updateLinesState()

  getScrollTop: -> @scrollTop

  setClientHeight: (@clientHeight) ->
    @updateLinesState()

  getClientHeight: ->
    @clientHeight ? @model.getScreenLineCount() * @getLineHeight()

  setClientWidth: (@clientWidth) ->
    @computeScrollWidth()
    @updateLinesState()

  getClientWidth: -> @clientWidth

  setLineHeight: (@lineHeight) ->
    @updateLinesState()

  getLineHeight: -> @lineHeight

  setBaseCharacterWidth: (@baseCharacterWidth) ->
    @computeScrollWidth()
    @updateLinesState()

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
    @computeScrollWidth()
    @updateLinesState()

  clearScopedCharWidths: ->
    @charWidthsByScope = {}

  pixelPositionForScreenPosition: (screenPosition, clip=true) ->
    screenPosition = Point.fromObject(screenPosition)
    screenPosition = @model.clipScreenPosition(screenPosition) if clip

    targetRow = screenPosition.row
    targetColumn = screenPosition.column
    baseCharacterWidth = @baseCharacterWidth

    top = targetRow * @lineHeightInPixels
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
