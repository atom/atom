Point = require 'point'
_ = require 'underscore'

module.exports =
class Range
  @fromObject: (object) ->
    if _.isArray(object)
      new Range(object...)
    else if object instanceof Range
      object
    else
      new Range(object.start, object.end)

  @fromPointWithDelta: (point, rowDelta, columnDelta) ->
    pointA = Point.fromObject(point)
    pointB = new Point(point.row + rowDelta, point.column + columnDelta)
    new Range(pointA, pointB)

  constructor: (pointA = new Point(0, 0), pointB = new Point(0, 0)) ->
    pointA = Point.fromObject(pointA)
    pointB = Point.fromObject(pointB)

    if pointA.compare(pointB) <= 0
      @start = pointA
      @end = pointB
    else
      @start = pointB
      @end = pointA

  copy: ->
    new Range(@start.copy(), @end.copy())

  isEqual: (other) ->
    if _.isArray(other) and other.length == 2
      other = new Range(other...)

    other.start.isEqual(@start) and other.end.isEqual(@end)

  isSingleLine: ->
    @start.row == @end.row

  coversSameRows: (other) ->
    @start.row == other.start.row && @end.row == other.end.row

  inspect: ->
    "[#{@start.inspect()} - #{@end.inspect()}]"

  add: (point) ->
    new Range(@start.add(point), @end.add(point))

  translate: (startPoint, endPoint=startPoint) ->
    new Range(@start.translate(startPoint), @end.translate(endPoint))

  intersectsWith: (otherRange) ->
    if @start.isLessThanOrEqual(otherRange.start)
      @end.isGreaterThanOrEqual(otherRange.start)
    else
      otherRange.intersectsWith(this)

  containsRange: (otherRange, {exclusive} = {}) ->
    { start, end } = Range.fromObject(otherRange)
    @containsPoint(start, {exclusive}) and @containsPoint(end, {exclusive})

  containsPoint: (point, {exclusive} = {}) ->
    point = Point.fromObject(point)
    if exclusive
      point.isGreaterThan(@start) and point.isLessThan(@end)
    else
      point.isGreaterThanOrEqual(@start) and point.isLessThanOrEqual(@end)

  containsRow: (row) ->
    @start.row <= row <= @end.row

  union: (otherRange) ->
    start = if @start.isLessThan(otherRange.start) then @start else otherRange.start
    end = if @end.isGreaterThan(otherRange.end) then @end else otherRange.end
    new Range(start, end)

  isEmpty: ->
    @start.isEqual(@end)

  toDelta: ->
    rows = @end.row - @start.row
    if rows == 0
      columns = @end.column - @start.column
    else
      columns = @end.column
    new Point(rows, columns)

  getRowCount: ->
    @end.row - @start.row + 1
