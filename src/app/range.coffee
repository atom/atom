Point = require 'point'
_ = require 'underscore'

# Public: Indicates a region within the editor.
#
# To better visualize how this works, imagine a rectangle.
# Each quadrant of the rectangle is analogus to a range, as ranges contain a
# starting row and a starting column, as well as an ending row, and an ending column.
#
# Each `Range` is actually constructed of two `Point` objects, labelled `start` and `end`.
module.exports =
class Range

  # Constructs a `Range` from a given object.
  #
  # object - This can be an {Array} (`[startRow, startColumn, endRow, endColumn]`) or an object `{start: Point, end: Point}`
  #
  # Returns the new {Range}.
  @fromObject: (object) ->
    if _.isArray(object)
      new Range(object...)
    else if object instanceof Range
      object
    else
      new Range(object.start, object.end)

  # Constructs a `Range` from a {Point}, and the delta values beyond that point.
  #
  # point - A {Point} to start with
  # rowDelta - A {Number} indicating how far from the starting {Point} the range's row should be
  # columnDelta - A {Number} indicating how far from the starting {Point} the range's column should be
  #
  # Returns the new {Range}.
  @fromPointWithDelta: (pointA, rowDelta, columnDelta) ->
    pointA = Point.fromObject(pointA)
    pointB = new Point(pointA.row + rowDelta, pointA.column + columnDelta)
    new Range(pointA, pointB)

  # Creates a new `Range` object based on two {Point}s.
  #
  # pointA - The first {Point} (default: `0, 0`)
  # pointB - The second {Point} (default: `0, 0`)
  constructor: (pointA = new Point(0, 0), pointB = new Point(0, 0)) ->
    pointA = Point.fromObject(pointA)
    pointB = Point.fromObject(pointB)

    if pointA.compare(pointB) <= 0
      @start = pointA
      @end = pointB
    else
      @start = pointB
      @end = pointA

  # Creates an identical copy of the `Range`.
  #
  # Returns a duplicate {Range}.
  copy: ->
    new Range(@start.copy(), @end.copy())

  # Identifies if two `Range`s are equal.
  #
  # All four points (`start.row`, `start.column`, `end.row`, `end.column`) must be
  # equal for this method to return `true`.
  #
  # other - A different {Range} to check against
  #
  # Returns a {Boolean}.
  isEqual: (other) ->
    if _.isArray(other) and other.length == 2
      other = new Range(other...)

    other.start.isEqual(@start) and other.end.isEqual(@end)

  # Returns an integer (-1, 0, 1) indicating whether this range is less than, equal,
  # or greater than the given range when sorting.
  #
  # Ranges that start earlier are considered "less than" ranges that start later.
  # If ranges start at the same location, the larger range sorts before the smaller
  # range.
  #
  # other - A {Range} to compare against.
  #
  # Returns a {Number}, either -1, 0, or 1.
  compare: (other) ->
    other = Range.fromObject(other)
    if value = @start.compare(other.start)
      value
    else
      other.end.compare(@end)

  # Identifies if the `Range` is on the same line.
  #
  # In other words, if `start.row` is equal to `end.row`.
  #
  # Returns a {Boolean}.
  isSingleLine: ->
    @start.row == @end.row

  # Identifies if two `Range`s are on the same line.
  #
  # other - A different {Range} to check against
  #
  # Returns a {Boolean}.
  coversSameRows: (other) ->
    @start.row == other.start.row && @end.row == other.end.row

  # Adds a new point to the `Range`s `start` and `end`.
  #
  # point - A new {Point} to add
  #
  # Returns the new {Range}.
  add: (point) ->
    new Range(@start.add(point), @end.add(point))

  # Moves a `Range`.
  #
  # In other words, the starting and ending `row` values, and the starting and ending
  # `column` values, are added to each other.
  #
  # startPoint - The {Point} to move the `Range`s `start` by
  # endPoint - The {Point} to move the `Range`s `end` by
  #
  # Returns the new {Range}.
  translate: (startPoint, endPoint=startPoint) ->
    new Range(@start.translate(startPoint), @end.translate(endPoint))

  # Identifies if two `Range`s intersect each other.
  #
  # otherRange - A different {Range} to check against
  #
  # Returns a {Boolean}.
  intersectsWith: (otherRange) ->
    if @start.isLessThanOrEqual(otherRange.start)
      @end.isGreaterThanOrEqual(otherRange.start)
    else
      otherRange.intersectsWith(this)

  # Identifies if a second `Range` is contained within a first.
  #
  # otherRange - A different {Range} to check against
  # options - A hash with a single option:
  #          exclusive: A {Boolean} which, if `true`, indicates that no {Point}s in the `Range` can be equal
  #
  # Returns a {Boolean}.
  containsRange: (otherRange, {exclusive} = {}) ->
    { start, end } = Range.fromObject(otherRange)
    @containsPoint(start, {exclusive}) and @containsPoint(end, {exclusive})

  # Identifies if a `Range` contains a {Point}.
  #
  # point - A {Point} to check against
  # options - A hash with a single option:
  #          exclusive: A {Boolean} which, if `true`, indicates that no {Point}s in the `Range` can be equal
  #
  # Returns a {Boolean}.
  containsPoint: (point, {exclusive} = {}) ->
    point = Point.fromObject(point)
    if exclusive
      point.isGreaterThan(@start) and point.isLessThan(@end)
    else
      point.isGreaterThanOrEqual(@start) and point.isLessThanOrEqual(@end)

  # Identifies if a `Range` contains a row.
  #
  # row - A row {Number} to check against
  # options - A hash with a single option:
  #
  # Returns a {Boolean}.
  containsRow: (row) ->
    @start.row <= row <= @end.row

  # Constructs a union between two `Range`s.
  #
  # otherRange - A different {Range} to unionize with
  #
  # Returns the new {Range}.
  union: (otherRange) ->
    start = if @start.isLessThan(otherRange.start) then @start else otherRange.start
    end = if @end.isGreaterThan(otherRange.end) then @end else otherRange.end
    new Range(start, end)

  # Identifies if a `Range` is empty.
  #
  # A `Range` is empty if its start {Point} matches its end.
  #
  # Returns a {Boolean}.
  isEmpty: ->
    @start.isEqual(@end)

  # Calculates the difference between a `Range`s `start` and `end` points.
  #
  # Returns a {Point}.
  toDelta: ->
    rows = @end.row - @start.row
    if rows == 0
      columns = @end.column - @start.column
    else
      columns = @end.column
    new Point(rows, columns)

  # Calculates the number of rows a `Range`s contains.
  #
  # Returns a {Number}.
  getRowCount: ->
    @end.row - @start.row + 1

  # Returns an array of all rows in a `Range`
  #
  # Returns an {Array}
  getRows: ->
    [@start.row..@end.row]

  ### Internal ###

  inspect: ->
    "[#{@start.inspect()} - #{@end.inspect()}]"
