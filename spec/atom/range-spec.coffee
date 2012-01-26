Range = require 'range'
Point = require 'point'

describe "Range", ->
  describe "constructor", ->
    it "ensures that @start <= @end", ->
      range1 = new Range(new Point(0, 1), new Point(0, 4))
      expect(range1.start).toEqual(row: 0, column: 1)

      range2 = new Range(new Point(1, 4), new Point(0, 1))
      expect(range2.start).toEqual(row: 0, column: 1)

  describe "isEmpty", ->
    it "returns true if @start equals @end", ->
      expect(new Range(new Point(1, 1), new Point(1, 1)).isEmpty()).toBeTruthy()
      expect(new Range(new Point(1, 1), new Point(1, 2)).isEmpty()).toBeFalsy()

