RowMap = require 'row-map'

describe "RowMap", ->
  map = null

  beforeEach ->
    map = new RowMap

  describe "when no mappings have been recorded", ->
    it "maps screen rows to buffer rows 1:1", ->
      expect(map.screenRowRangeForBufferRow(0)).toEqual [0, 1]
      expect(map.bufferRowRangeForScreenRow(0)).toEqual [0, 1]
      expect(map.screenRowRangeForBufferRow(100)).toEqual [100, 101]
      expect(map.bufferRowRangeForScreenRow(100)).toEqual [100, 101]

  describe "when a buffer row range is mapped to a single screen row (like a visible fold)", ->
    beforeEach ->
      map.mapBufferRowRange(4, 9, 1)

    it "accounts for the mapping when translating buffer rows to screen row ranges", ->
      expect(map.screenRowRangeForBufferRow(0)).toEqual [0, 1]
      expect(map.screenRowRangeForBufferRow(3)).toEqual [3, 4]

      expect(map.screenRowRangeForBufferRow(4)).toEqual [4, 5]
      expect(map.screenRowRangeForBufferRow(8)).toEqual [4, 5]

      expect(map.screenRowRangeForBufferRow(9)).toEqual [5, 6]
      expect(map.screenRowRangeForBufferRow(10)).toEqual [6, 7]
