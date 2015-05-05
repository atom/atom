module.exports =
class LinesPresenter
  startRow: null
  endRow: null
  lineHeight: null

  constructor: (@presenter) ->
    @lines = {}

  getState: ->
    visibleLineIds = {}
    row = @startRow
    while row < @endRow
      line = @presenter.model.tokenizedLineForScreenRow(row)
      unless line?
        throw new Error("No line exists for row #{row}. Last screen row: #{@model.getLastScreenRow()}")

      visibleLineIds[line.id] = true
      if @lines.hasOwnProperty(line.id)
        lineState = @lines[line.id]
        lineState.screenRow = row
        lineState.top = (row - @startRow) * @lineHeight
        lineState.decorationClasses = @presenter.lineDecorationClassesForRow(row)
      else
        @lines[line.id] =
          screenRow: row
          text: line.text
          tokens: line.tokens
          isOnlyWhitespace: line.isOnlyWhitespace()
          endOfLineInvisibles: line.endOfLineInvisibles
          indentLevel: line.indentLevel
          tabLength: line.tabLength
          fold: line.fold
          top: (row - @startRow) * @lineHeight
          decorationClasses: @presenter.lineDecorationClassesForRow(row)
      row++

    for id, line of @lines
      delete @lines[id] unless visibleLineIds.hasOwnProperty(id)

    @lines
