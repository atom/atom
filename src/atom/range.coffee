Point = require 'point'
_ = require 'underscore'

module.exports =
class Range
  constructor: (pointA, pointB) ->
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

  inspect: ->
    "[#{@start.inspect()} - #{@end.inspect()}]"

  isEmpty: ->
    @start.isEqual(@end)

