_ = require 'underscore'

# Public: Represents a coordinate in the editor.
#
# Each `Point` is actually an object with two properties: `row` and `column`.
module.exports =
class Point

  # Constructs a `Point` from a given object.
  #
  # object - This can be an {Array} (`[startRow, startColumn, endRow, endColumn]`) or an object `{row, column}`
  #
  # Returns the new {Point}.
  @fromObject: (object) ->
    if object instanceof Point
      object
    else
      if _.isArray(object)
        [row, column] = object
      else
        { row, column } = object

      new Point(row, column)

  # Identifies which `Point` is smaller.
  #
  # "Smaller" means that both the `row` and `column` values of one `Point` are less than or equal
  # to the other.
  #
  # point1 - The first {Point} to check
  # point2 - The second {Point} to check
  #
  # Returns the smaller {Point}.
  @min: (point1, point2) ->
    point1 = @fromObject(point1)
    point2 = @fromObject(point2)
    if point1.isLessThanOrEqual(point2)
      point1
    else
      point2

  # Creates a new `Point` object.
  #
  # row - A {Number} indicating the row (default: 0)
  # column - A {Number} indicating the column (default: 0)
  #
  # Returns a {Point},
  constructor: (@row=0, @column=0) ->

  # Creates an identical copy of the `Point`.
  #
  # Returns a duplicate {Point}.
  copy: ->
    new Point(@row, @column)

  # Adds the `column`s of two `Point`s together.
  #
  # other - The {Point} to add with
  #
  # Returns the new {Point}.
  add: (other) ->
    other = Point.fromObject(other)
    row = @row + other.row
    if other.row == 0
      column = @column + other.column
    else
      column = other.column

    new Point(row, column)

  # Moves a `Point`.
  #
  # In other words, the `row` values and `column` values are added to each other.
  #
  # other - The {Point} to add with
  #
  # Returns the new {Point}.
  translate: (other) ->
    other = Point.fromObject(other)
    new Point(@row + other.row, @column + other.column)

  # Creates two new `Point`s, split down a `column` value.
  #
  # In other words, given a point, this creates `Point(0, column)` and `Point(row, column)`.
  #
  # column - The {Number} to split at
  #
  # Returns an {Array} of two {Point}s.
  splitAt: (column) ->
    if @row == 0
      rightColumn = @column - column
    else
      rightColumn = @column

    [new Point(0, column), new Point(@row, rightColumn)]

  # Compares two `Point`s.
  #
  # other - The {Point} to compare against
  #
  # Returns a {Number} matching the following rules:
  # * If the first `row` is greater than `other.row`, returns `1`.
  # * If the first `row` is less than `other.row`, returns `-1`.
  # * If the first `column` is greater than `other.column`, returns `1`.
  # * If the first `column` is less than `other.column`, returns `-1`.
  #
  # Otherwise, returns `0`.
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

  # Identifies if two `Point`s are equal.
  #
  # other - The {Point} to compare against
  #
  # Returns a {Boolean}.
  isEqual: (other) ->
    return false unless other
    other = Point.fromObject(other)
    @row == other.row and @column == other.column

  # Identifies if one `Point` is less than another.
  #
  # other - The {Point} to compare against
  #
  # Returns a {Boolean}.
  isLessThan: (other) ->
    @compare(other) < 0

  # Identifies if one `Point` is less than or equal to another.
  #
  # other - The {Point} to compare against
  #
  # Returns a {Boolean}.
  isLessThanOrEqual: (other) ->
    @compare(other) <= 0

  # Identifies if one `Point` is greater than another.
  #
  # other - The {Point} to compare against
  #
  # Returns a {Boolean}.
  isGreaterThan: (other) ->
    @compare(other) > 0

  # Identifies if one `Point` is greater than or equal to another.
  #
  # other - The {Point} to compare against
  #
  # Returns a {Boolean}.
  isGreaterThanOrEqual: (other) ->
    @compare(other) >= 0

  # Converts the {Point} to a String.
  #
  # Returns a {String}.
  toString: ->
    "#{@row},#{@column}"

  # Converts the {Point} to an Array.
  #
  # Returns an {Array}.
  toArray: ->
    [@row, @column]

  ### Internal ###

  inspect: ->
    "(#{@row}, #{@column})"

  # Internal:
  serialize: ->
    @toArray()
