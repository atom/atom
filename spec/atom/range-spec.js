(function() {
  var Point, Range;

  Range = require('range');

  Point = require('point');

  describe("Range", function() {
    describe("constructor", function() {
      return it("ensures that @start <= @end", function() {
        var range1, range2;
        range1 = new Range(new Point(0, 1), new Point(0, 4));
        expect(range1.start).toEqual({
          row: 0,
          column: 1
        });
        range2 = new Range(new Point(1, 4), new Point(0, 1));
        return expect(range2.start).toEqual({
          row: 0,
          column: 1
        });
      });
    });
    describe(".isEmpty()", function() {
      return it("returns true if @start equals @end", function() {
        expect(new Range(new Point(1, 1), new Point(1, 1)).isEmpty()).toBeTruthy();
        return expect(new Range(new Point(1, 1), new Point(1, 2)).isEmpty()).toBeFalsy();
      });
    });
    return describe(".intersectsWith(otherRange)", function() {
      return fit("returns the intersection of the two ranges", function() {
        var range1, range2;
        range1 = new Range([1, 1], [2, 10]);
        range2 = new Range([2, 1], [3, 10]);
        expect(range1.intersectsWith(range2)).toBeTruth;
        range2 = range1 = new Range([2, 1], [3, 10]);
        return expect(range1.intersectsWith(range2)).toBeTruth;
      });
    });
  });

}).call(this);
