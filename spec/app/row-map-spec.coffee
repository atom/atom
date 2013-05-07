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
      map.mapBufferRowRange(5, 10, 1)
      map.mapBufferRowRange(35, 40, 1)
      map.mapBufferRowRange(25, 30, 1)
      map.mapBufferRowRange(15, 20, 1)

    it "accounts for the mapping when translating buffer rows to screen row ranges", ->
      expect(map.screenRowRangeForBufferRow(0)).toEqual [0, 1]

      expect(map.screenRowRangeForBufferRow(4)).toEqual [4, 5]
      expect(map.screenRowRangeForBufferRow(5)).toEqual [5, 6]
      expect(map.screenRowRangeForBufferRow(9)).toEqual [5, 6]
      expect(map.screenRowRangeForBufferRow(10)).toEqual [6, 7]

      expect(map.screenRowRangeForBufferRow(14)).toEqual [10, 11]
      expect(map.screenRowRangeForBufferRow(15)).toEqual [11, 12]
      expect(map.screenRowRangeForBufferRow(19)).toEqual [11, 12]
      expect(map.screenRowRangeForBufferRow(20)).toEqual [12, 13]

      expect(map.screenRowRangeForBufferRow(24)).toEqual [16, 17]
      expect(map.screenRowRangeForBufferRow(25)).toEqual [17, 18]
      expect(map.screenRowRangeForBufferRow(29)).toEqual [17, 18]
      expect(map.screenRowRangeForBufferRow(30)).toEqual [18, 19]

      expect(map.screenRowRangeForBufferRow(34)).toEqual [22, 23]
      expect(map.screenRowRangeForBufferRow(35)).toEqual [23, 24]
      expect(map.screenRowRangeForBufferRow(39)).toEqual [23, 24]
      expect(map.screenRowRangeForBufferRow(40)).toEqual [24, 25]
