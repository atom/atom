Point = require 'point'
_ = require 'underscore'

module.exports =
class Range
  @fromObject: (object) ->
    if _.isArray(object)
      new Range(object...)
    else
      object


  constructor: (pointA = new Point(0, 0), pointB = new Point(0, 0)) ->
    pointA = Point.fromObject(pointA)
    pointB = Point.fromObject(pointB)

    if pointA.compare(pointB) <= 0
      @start = pointA
      @end = pointB
    else
      @start = pointB
      @end = pointA

  copy: (range) ->
    new Range(@start.copy(), @end.copy())

  isEqual: (other) ->
    if other instanceof Array and other.length == 2
      other = new Range(other...)

    other.start.isEqual(@start) and other.end.isEqual(@end)

  isSingleLine: ->
    @start.row == @end.row

  coversSameRows: (other) ->
    @start.row == other.start.row && @end.row == other.end.row

  inspect: ->
    "[#{@start.inspect()} - #{@end.inspect()}]"

  intersectsWith: (otherRange) ->
    if @start.isLessThanOrEqual(otherRange.start)
      @end.isGreaterThanOrEqual(otherRange.start)
    else
      otherRange.intersectsWith(this)

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

