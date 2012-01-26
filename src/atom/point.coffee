module.exports =
class Point
  @fromObject: (object) ->
    if object instanceof Point
      object
    else
      { row, column } = object
      new Point(row, column)

  constructor: (@row, @column) ->

  isEqual: (other) ->
    @row == other.row && @column == other.column

  compare: (other) ->
    if @row > other.row
      1
    else if @row < other.row
      -1
    else
      if @column > other.column
        1
      else if @column < other.column
        -1
      else
        0
