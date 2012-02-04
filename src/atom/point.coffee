module.exports =
class Point
  @fromObject: (object) ->
    if object instanceof Point
      object
    else
      if object instanceof Array
        [row, column] = object
      else
        { row, column } = object

      new Point(row, column)

  constructor: (@row, @column) ->

  isEqual: (other) ->
    if other instanceof Array
      @row == other[0] and @column == other[1]
    else
      @row == other.row and @column == other.column

  inspect: ->
    "(#{@row}, #{@column})"

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
