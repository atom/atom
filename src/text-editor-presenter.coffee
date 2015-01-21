{CompositeDisposable} = require 'event-kit'
{Point} = require 'text-buffer'

module.exports =
class TextEditorPresenter
  constructor: ({@model, @clientHeight, @clientWidth, @scrollTop, @lineHeight, @baseCharacterWidth, @lineOverdrawMargin}) ->
    @disposables = new CompositeDisposable
    @charWidthsByScope = {}
    @observeModel()
    @observeConfig()
    @buildState()

  destroy: ->
    @disposables.dispose()

  observeModel: ->
    @disposables.add @model.onDidChange(@updateState.bind(this))
    @disposables.add @model.onDidChangeSoftWrapped(@updateState.bind(this))
    @disposables.add @model.onDidChangeGrammar(@updateContentState.bind(this))
    @disposables.add @model.onDidAddDecoration(@didAddDecoration.bind(this))
    @disposables.add @model.onDidChangeMini(@updateLinesState.bind(this))
    @observeDecoration(decoration) for decoration in @model.getLineDecorations()

  observeConfig: ->
    @disposables.add atom.config.onDidChange 'editor.showIndentGuide', scope: @model.getRootScopeDescriptor(), @updateContentState.bind(this)

  buildState: ->
    @state = {}
    @buildContentState()
    @buildLinesState()

  buildContentState: ->
    @state.content = {}
    @updateContentState()

  buildLinesState: ->
    @state.content.lines = {}
    @updateLinesState()

  updateState: ->
    @updateContentState()
    @updateLinesState()

  updateContentState: ->
    @state.content.scrollWidth = @computeScrollWidth()
    @state.content.scrollHeight = @computeScrollHeight()
    @state.content.indentGuidesVisible = atom.config.get('editor.showIndentGuide', scope: @model.getRootScopeDescriptor())

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

  setScrollTop: (@scrollTop) ->
    @updateLinesState()

  getScrollTop: -> @scrollTop

  setClientHeight: (@clientHeight) ->
    @updateLinesState()

  getClientHeight: ->
    @clientHeight ? @model.getScreenLineCount() * @getLineHeight()

  setClientWidth: (@clientWidth) ->
    @updateContentState()
    @updateLinesState()

  getClientWidth: -> @clientWidth

  setLineHeight: (@lineHeight) ->
    @updateContentState()
    @updateLinesState()

  getLineHeight: -> @lineHeight

  setBaseCharacterWidth: (@baseCharacterWidth) ->
    @updateContentState()
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
    @updateContentState()
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

  observeDecoration: (decoration) ->
    markerChangeDisposable = decoration.getMarker().onDidChange(@updateLinesState.bind(this))
    destroyDisposable = decoration.onDidDestroy =>
      @disposables.remove(markerChangeDisposable)
      @disposables.remove(destroyDisposable)
      @updateLinesState()

    @disposables.add(markerChangeDisposable)
    @disposables.add(destroyDisposable)

  didAddDecoration: (decoration) ->
    if decoration.isType('line')
      @observeDecoration(decoration)
      @updateLinesState()
