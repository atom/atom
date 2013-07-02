{Point, Range} = require 'telepath'

describe "Range", ->
  describe "constructor", ->
    it "ensures that @start <= @end", ->
      range1 = new Range(new Point(0, 1), new Point(0, 4))
      expect(range1.start).toEqual(row: 0, column: 1)

      range2 = new Range(new Point(1, 4), new Point(0, 1))
      expect(range2.start).toEqual(row: 0, column: 1)

  describe ".isEmpty()", ->
    it "returns true if @start equals @end", ->
      expect(new Range(new Point(1, 1), new Point(1, 1)).isEmpty()).toBeTruthy()
      expect(new Range(new Point(1, 1), new Point(1, 2)).isEmpty()).toBeFalsy()

  describe ".intersectsWith(otherRange)", ->
    it "returns true if the ranges intersect or share an endpoint", ->
      expect(new Range([1, 1], [2, 10]).intersectsWith(new Range([2, 1], [3, 10]))).toBeTruthy()
      expect(new Range([2, 1], [3, 10]).intersectsWith(new Range([1, 1], [2, 10]))).toBeTruthy()
      expect(new Range([2, 1], [3, 10]).intersectsWith(new Range([2, 5], [3, 1]))).toBeTruthy()
      expect(new Range([2, 5], [3, 1]).intersectsWith(new Range([2, 1], [3, 10]))).toBeTruthy()
      expect(new Range([2, 5], [3, 1]).intersectsWith(new Range([3, 1], [3, 10]))).toBeTruthy()
      expect(new Range([3, 1], [3, 10]).intersectsWith(new Range([2, 5], [3, 1]))).toBeTruthy()
      expect(new Range([2, 5], [3, 1]).intersectsWith(new Range([3, 2], [3, 10]))).toBeFalsy()
      expect(new Range([3, 2], [3, 10]).intersectsWith(new Range([2, 5], [3, 1]))).toBeFalsy()

  describe ".union(otherRange)", ->
    it "returns the union of the two ranges", ->
      expect(new Range([1, 1], [2, 10]).union(new Range([2, 1], [3, 10]))).toEqual [[1, 1], [3, 10]]
      expect(new Range([2, 1], [3, 10]).union(new Range([1, 1], [2, 10]))).toEqual [[1, 1], [3, 10]]
      expect(new Range([2, 1], [3, 10]).union(new Range([2, 5], [3, 1]))).toEqual [[2, 1], [3, 10]]
      expect(new Range([2, 5], [3, 1]).union(new Range([2, 1], [3, 10]))).toEqual [[2, 1], [3, 10]]

  describe ".compare(otherRange)", ->
    it "sorts earlier ranges first, and larger ranges first if both ranges start at the same place", ->
      expect(new Range([1, 1], [2, 10]).compare(new Range([2, 1], [3, 10]))).toBe -1
      expect(new Range([2, 1], [3, 10]).compare(new Range([1, 1], [2, 10]))).toBe 1
      expect(new Range([1, 1], [3, 10]).compare(new Range([1, 1], [2, 10]))).toBe -1
      expect(new Range([1, 1], [2, 10]).compare(new Range([1, 1], [3, 10]))).toBe 1
      expect(new Range([1, 1], [3, 10]).compare(new Range([1, 1], [3, 10]))).toBe 0

  describe ".translate(startPoint, endPoint)", ->
    it "returns a range translates by the specified start and end points", ->
      expect(new Range([1, 1], [2, 10]).translate([1])).toEqual [[2, 1], [3, 10]]
      expect(new Range([1, 1], [2, 10]).translate([1,2], [3,4])).toEqual [[2, 3], [5, 14]]
