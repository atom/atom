module.exports =
class TextEditorPresenter
  constructor: ({@model, @clientHeight, @scrollTop, @lineHeight, @lineOverdrawMargin}) ->
    @state = {}
    @buildLinesState()

  buildLinesState: ->
    @state.lines = {}
    startRow = Math.floor(@scrollTop / @lineHeight) - @lineOverdrawMargin
    startRow = Math.max(0, startRow)
    endRow = startRow + Math.ceil(@clientHeight / @lineHeight) + @lineOverdrawMargin
    endRow = Math.min(@model.getScreenLineCount(), endRow)

    for line, i in @model.tokenizedLinesForScreenRows(startRow, endRow)
      row = startRow + i
      @state.lines[line.id] = {
        screenRow: row
        tokens: line.tokens
        top: row * @lineHeight
      }
