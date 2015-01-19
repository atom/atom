module.exports =
class TextEditorPresenter
  constructor: ({@model, @clientHeight, @scrollTop, @lineHeight, @lineOverdrawMargin}) ->
    @state = {}
    @buildLinesState()

  buildLinesState: ->
    @state.lines = {}
    @updateLinesState()

  updateLinesState: ->
    visibleLineIds = {}
    endRow = @getEndRow()
    startRow = @getStartRow()

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
    lineState.top = row * @lineHeight

  buildLineState: (row, line) ->
    @state.lines[line.id] =
      screenRow: row
      tokens: line.tokens
      top: row * @lineHeight

  getStartRow: ->
    startRow = Math.floor(@scrollTop / @lineHeight) - @lineOverdrawMargin
    Math.max(0, startRow)

  getEndRow: ->
    endRow = @getStartRow() + Math.ceil(@clientHeight / @lineHeight) + @lineOverdrawMargin
    Math.min(@model.getScreenLineCount(), endRow)

  setScrollTop: (@scrollTop) ->
    @updateLinesState()

  setClientHeight: (@clientHeight) ->
    @updateLinesState()

  setLineHeight: (@lineHeight) ->
    @updateLinesState()
