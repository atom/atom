Point = require 'point'

describe "Point", ->
  describe "compare", ->
    it "returns 1, 0, or -1 based on whether the given point precedes, equals, or follows the receivers location in the buffer", ->
      expect(new Point(5, 0).compare(new Point(5, 0))).toBe 0
      expect(new Point(5, 0).compare(new Point(6, 0))).toBe -1
      expect(new Point(5, 0).compare(new Point(5, 1))).toBe -1
      expect(new Point(5, 0).compare(new Point(6, 1))).toBe -1
      expect(new Point(5, 5).compare(new Point(4, 1))).toBe 1
      expect(new Point(5, 5).compare(new Point(5, 3))).toBe 1
