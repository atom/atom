module.exports =
class Delta
  @fromObject: (object) ->
    if object instanceof Delta
      object
    else
      new Delta(object[0], object[1])

  constructor: (@rows=0, @columns=0) ->

  add: (other) ->
    rows = @rows + other.rows
    if other.rows == 0
      columns = @columns + other.columns
    else
      columns = other.columns

    new Delta(rows, columns)

  splitAt: (column) ->
    if @rows == 0
      rightColumns = @columns - column
    else
      rightColumns = @columns

    [new Delta(0, column), new Delta(@rows, rightColumns)]

  isEqual: (other) ->
    other = Delta.fromObject(other)
    @rows == other.rows and @columns == other.columns
