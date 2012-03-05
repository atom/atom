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
    new Range(_.clone(@start), _.clone(@end))

  isEqual: (other) ->
    if other instanceof Array and other.length == 2
      other = new Range(other...)

    other.start.isEqual(@start) and other.end.isEqual(@end)

  inspect: ->
    "[#{@start.inspect()} - #{@end.inspect()}]"

  isEmpty: ->
    @start.isEqual(@end)

  toDelta: ->
    rows = @end.row - @start.row
    if rows == 0
      columns = @end.column - @start.column
    else
      columns = @end.column
    new Point(rows, columns)

