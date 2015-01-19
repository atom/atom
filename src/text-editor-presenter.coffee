{CompositeDisposable} = require 'event-kit'

module.exports =
class TextEditorPresenter
  constructor: ({@model, @clientHeight, @clientWidth, @scrollTop, @lineHeight, @baseCharacterWidth, @lineOverdrawMargin}) ->
    @disposables = new CompositeDisposable
    @state = {}
    @subscribeToModel()
    @buildLinesState()

  destroy: ->
    @disposables.dispose()

  subscribeToModel: ->
    @disposables.add @model.onDidChange(@updateLinesState.bind(this))
    @disposables.add @model.onDidChangeSoftWrapped(@updateLinesState.bind(this))

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

  getScrollWidth: ->
    contentWidth = @model.getMaxScreenLineLength() * @getBaseCharacterWidth()
    contentWidth += 1 unless @model.isSoftWrapped() # account for cursor width
    Math.max(contentWidth, @getClientWidth())

  setScrollTop: (@scrollTop) ->
    @updateLinesState()

  getScrollTop: -> @scrollTop

  setClientHeight: (@clientHeight) ->
    @updateLinesState()

  getClientHeight: ->
    @clientHeight ? @model.getScreenLineCount() * @getLineHeight()

  setClientWidth: (@clientWidth) ->
    @updateLinesState()

  getClientWidth: -> @clientWidth

  setLineHeight: (@lineHeight) ->
    @updateLinesState()

  getLineHeight: -> @lineHeight

  setBaseCharacterWidth: (@baseCharacterWidth) ->
    @updateLinesState()

  getBaseCharacterWidth: -> @baseCharacterWidth
