module.exports =
class Range
  constructor: (pointA, pointB) ->
    if pointA.compare(pointB) <= 0
      @start = pointA
      @end = pointB
    else
      @start = pointB
      @end = pointA

  isEmpty: ->
    @start.isEqual(@end)

