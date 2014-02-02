RowMap = require '../src/row-map'

describe "RowMap", ->
  map = null

  beforeEach ->
    map = new RowMap

  describe "::screenRowRangeForBufferRow(bufferRow)", ->
    it "returns the range of screen rows corresponding to the given buffer row", ->
      map.spliceRegions(0, 0, [
        {bufferRows: 5, screenRows: 5}
        {bufferRows: 1, screenRows: 5}
        {bufferRows: 5, screenRows: 5}
        {bufferRows: 5, screenRows: 1}
      ])

      expect(map.screenRowRangeForBufferRow(0)).toEqual [0, 1]
      expect(map.screenRowRangeForBufferRow(5)).toEqual [5, 10]
      expect(map.screenRowRangeForBufferRow(6)).toEqual [10, 11]
      expect(map.screenRowRangeForBufferRow(11)).toEqual [15, 16]
      expect(map.screenRowRangeForBufferRow(12)).toEqual [15, 16]
      expect(map.screenRowRangeForBufferRow(16)).toEqual [16, 17]

  describe "::bufferRowRangeForScreenRow(screenRow)", ->
    it "returns the range of buffer rows corresponding to the given screen row", ->
      map.spliceRegions(0, 0, [
        {bufferRows: 5, screenRows: 5}
        {bufferRows: 1, screenRows: 5}
        {bufferRows: 5, screenRows: 5}
        {bufferRows: 5, screenRows: 1}
      ])

      expect(map.bufferRowRangeForScreenRow(0)).toEqual [0, 1]
      expect(map.bufferRowRangeForScreenRow(5)).toEqual [5, 6]
      expect(map.bufferRowRangeForScreenRow(6)).toEqual [5, 6]
      expect(map.bufferRowRangeForScreenRow(10)).toEqual [6, 7]
      expect(map.bufferRowRangeForScreenRow(14)).toEqual [10, 11]
      expect(map.bufferRowRangeForScreenRow(15)).toEqual [11, 16]
      expect(map.bufferRowRangeForScreenRow(16)).toEqual [16, 17]

  describe "::spliceRegions(startBufferRow, bufferRowCount, regions)", ->
    it "can insert regions when empty", ->
      regions = [
        {bufferRows: 5, screenRows: 5}
        {bufferRows: 1, screenRows: 5}
        {bufferRows: 5, screenRows: 5}
        {bufferRows: 5, screenRows: 1}
      ]
      map.spliceRegions(0, 0, regions)
      expect(map.getRegions()).toEqual regions

    it "can insert wrapped lines into rectangular regions", ->
      map.spliceRegions(0, 0, [{bufferRows: 10, screenRows: 10}])
      map.spliceRegions(5, 0, [{bufferRows: 1, screenRows: 3}])
      expect(map.getRegions()).toEqual [
        {bufferRows: 5, screenRows: 5}
        {bufferRows: 1, screenRows: 3}
        {bufferRows: 5, screenRows: 5}
      ]

    it "can splice wrapped lines into rectangular regions", ->
      map.spliceRegions(0, 0, [{bufferRows: 10, screenRows: 10}])
      map.spliceRegions(5, 1, [{bufferRows: 1, screenRows: 3}])
      expect(map.getRegions()).toEqual [
        {bufferRows: 5, screenRows: 5}
        {bufferRows: 1, screenRows: 3}
        {bufferRows: 4, screenRows: 4}
      ]

    it "can splice folded lines into rectangular regions", ->
      map.spliceRegions(0, 0, [{bufferRows: 10, screenRows: 10}])
      map.spliceRegions(5, 3, [{bufferRows: 3, screenRows: 1}])
      expect(map.getRegions()).toEqual [
        {bufferRows: 5, screenRows: 5}
        {bufferRows: 3, screenRows: 1}
        {bufferRows: 2, screenRows: 2}
      ]

    it "can replace folded regions with a folded region that surrounds them", ->
      map.spliceRegions(0, 0, [
        {bufferRows: 3, screenRows: 3}
        {bufferRows: 3, screenRows: 1}
        {bufferRows: 1, screenRows: 1}
        {bufferRows: 3, screenRows: 1}
        {bufferRows: 3, screenRows: 3}
      ])
      map.spliceRegions(2, 8, [{bufferRows: 8, screenRows: 1}])
      expect(map.getRegions()).toEqual [
        {bufferRows: 2, screenRows: 2}
        {bufferRows: 8, screenRows: 1}
        {bufferRows: 3, screenRows: 3}
      ]

    it "merges adjacent rectangular regions", ->
      map.spliceRegions(0, 0, [
        {bufferRows: 3, screenRows: 3}
        {bufferRows: 3, screenRows: 1}
        {bufferRows: 1, screenRows: 1}
        {bufferRows: 3, screenRows: 1}
        {bufferRows: 3, screenRows: 3}
      ])

      map.spliceRegions(3, 7, [{bufferRows: 5, screenRows: 5}])
