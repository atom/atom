Point = require 'point'

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

  isEmpty: ->
    @start.isEqual(@end)

