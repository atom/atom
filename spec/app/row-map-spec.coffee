RowMap = require 'row-map'

describe "RowMap", ->
  map = null

  beforeEach ->
    map = new RowMap

  describe "when no mappings have been recorded", ->
    it "maps buffer rows to screen rows 1:1", ->
      expect(map.screenRowRangeForBufferRow(0)).toEqual [0, 1]
      expect(map.screenRowRangeForBufferRow(100)).toEqual [100, 101]

  describe ".mapBufferRowRange(startBufferRow, endBufferRow, screenRows)", ->
    describe "when mapping to a single screen row (like a visible fold)", ->
      beforeEach ->
        map.mapBufferRowRange(5, 10, 1)
        map.mapBufferRowRange(15, 20, 1)
        map.mapBufferRowRange(25, 30, 1)

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

      it "accounts for the mapping when translating screen rows to buffer row ranges", ->
        expect(map.bufferRowRangeForScreenRow(0)).toEqual [0, 1]

        expect(map.bufferRowRangeForScreenRow(4)).toEqual [4, 5]
        expect(map.bufferRowRangeForScreenRow(5)).toEqual [5, 10]
        expect(map.bufferRowRangeForScreenRow(6)).toEqual [10, 11]

        expect(map.bufferRowRangeForScreenRow(10)).toEqual [14, 15]
        expect(map.bufferRowRangeForScreenRow(11)).toEqual [15, 20]
        expect(map.bufferRowRangeForScreenRow(12)).toEqual [20, 21]

        expect(map.bufferRowRangeForScreenRow(16)).toEqual [24, 25]
        expect(map.bufferRowRangeForScreenRow(17)).toEqual [25, 30]
        expect(map.bufferRowRangeForScreenRow(18)).toEqual [30, 31]

    describe "when mapping to zero screen rows (like an invisible fold)", ->
      beforeEach ->
        map.mapBufferRowRange(5, 10, 0)
        map.mapBufferRowRange(15, 20, 0)
        map.mapBufferRowRange(25, 30, 0)

      it "accounts for the mapping when translating buffer rows to screen row ranges", ->
        expect(map.screenRowRangeForBufferRow(0)).toEqual [0, 1]

        expect(map.screenRowRangeForBufferRow(4)).toEqual [4, 5]
        expect(map.screenRowRangeForBufferRow(5)).toEqual [5, 5]
        expect(map.screenRowRangeForBufferRow(9)).toEqual [5, 5]
        expect(map.screenRowRangeForBufferRow(10)).toEqual [5, 6]

        expect(map.screenRowRangeForBufferRow(14)).toEqual [9, 10]
        expect(map.screenRowRangeForBufferRow(15)).toEqual [10, 10]
        expect(map.screenRowRangeForBufferRow(19)).toEqual [10, 10]
        expect(map.screenRowRangeForBufferRow(20)).toEqual [10, 11]

        expect(map.screenRowRangeForBufferRow(24)).toEqual [14, 15]
        expect(map.screenRowRangeForBufferRow(25)).toEqual [15, 15]
        expect(map.screenRowRangeForBufferRow(29)).toEqual [15, 15]
        expect(map.screenRowRangeForBufferRow(30)).toEqual [15, 16]

      it "accounts for the mapping when translating screen rows to buffer row ranges", ->
        expect(map.bufferRowRangeForScreenRow(0)).toEqual [0, 1]

        expect(map.bufferRowRangeForScreenRow(4)).toEqual [4, 5]
        expect(map.bufferRowRangeForScreenRow(5)).toEqual [10, 11]

        expect(map.bufferRowRangeForScreenRow(9)).toEqual [14, 15]
        expect(map.bufferRowRangeForScreenRow(10)).toEqual [20, 21]

        expect(map.bufferRowRangeForScreenRow(14)).toEqual [24, 25]
        expect(map.bufferRowRangeForScreenRow(15)).toEqual [30, 31]

    describe "when mapping a single buffer row to multiple screen rows (like a wrapped line)", ->
      beforeEach ->
        map.mapBufferRowRange(5, 6, 3)
        map.mapBufferRowRange(10, 11, 2)
        map.mapBufferRowRange(20, 21, 5)

      it "accounts for the mapping when translating buffer rows to screen row ranges", ->
        expect(map.screenRowRangeForBufferRow(0)).toEqual [0, 1]

        expect(map.screenRowRangeForBufferRow(4)).toEqual [4, 5]
        expect(map.screenRowRangeForBufferRow(5)).toEqual [5, 8]
        expect(map.screenRowRangeForBufferRow(6)).toEqual [8, 9]

        expect(map.screenRowRangeForBufferRow(9)).toEqual [11, 12]
        expect(map.screenRowRangeForBufferRow(10)).toEqual [12, 14]
        expect(map.screenRowRangeForBufferRow(11)).toEqual [14, 15]

        expect(map.screenRowRangeForBufferRow(19)).toEqual [22, 23]
        expect(map.screenRowRangeForBufferRow(20)).toEqual [23, 28]
        expect(map.screenRowRangeForBufferRow(21)).toEqual [28, 29]

      it "accounts for the mapping when translating screen rows to buffer row ranges", ->
        expect(map.bufferRowRangeForScreenRow(0)).toEqual [0, 1]

        expect(map.bufferRowRangeForScreenRow(4)).toEqual [4, 5]
        expect(map.bufferRowRangeForScreenRow(5)).toEqual [5, 6]
        expect(map.bufferRowRangeForScreenRow(7)).toEqual [5, 6]
        expect(map.bufferRowRangeForScreenRow(8)).toEqual [6, 7]

        expect(map.bufferRowRangeForScreenRow(11)).toEqual [9, 10]
        expect(map.bufferRowRangeForScreenRow(12)).toEqual [10, 11]
        expect(map.bufferRowRangeForScreenRow(13)).toEqual [10, 11]
        expect(map.bufferRowRangeForScreenRow(14)).toEqual [11, 12]

        expect(map.bufferRowRangeForScreenRow(22)).toEqual [19, 20]
        expect(map.bufferRowRangeForScreenRow(23)).toEqual [20, 21]
        expect(map.bufferRowRangeForScreenRow(27)).toEqual [20, 21]
        expect(map.bufferRowRangeForScreenRow(28)).toEqual [21, 22]

      describe "after re-mapping a row range to a new number of screen rows", ->
        beforeEach ->
          map.mapBufferRowRange(10, 11, 4)

        it "updates translation accordingly", ->
          expect(map.screenRowRangeForBufferRow(4)).toEqual [4, 5]
          expect(map.screenRowRangeForBufferRow(5)).toEqual [5, 8]
          expect(map.screenRowRangeForBufferRow(6)).toEqual [8, 9]

          expect(map.screenRowRangeForBufferRow(9)).toEqual [11, 12]
          expect(map.screenRowRangeForBufferRow(10)).toEqual [12, 16]
          expect(map.screenRowRangeForBufferRow(11)).toEqual [16, 17]

          expect(map.screenRowRangeForBufferRow(19)).toEqual [24, 25]
          expect(map.screenRowRangeForBufferRow(20)).toEqual [25, 30]
          expect(map.screenRowRangeForBufferRow(21)).toEqual [30, 31]

    describe "when the row range is inside an existing 1:1 region", ->
      it "preserves the starting screen row of subsequent 1:N mappings", ->
        map.mapBufferRowRange(5, 10, 1)
        map.mapBufferRowRange(25, 30, 1)

        expect(map.bufferRowRangeForScreenRow(5)).toEqual [5, 10]
        expect(map.bufferRowRangeForScreenRow(21)).toEqual [25, 30]

        map.mapBufferRowRange(15, 20, 1)

        expect(map.bufferRowRangeForScreenRow(11)).toEqual [15, 20]
        expect(map.bufferRowRangeForScreenRow(5)).toEqual [5, 10]
        expect(map.bufferRowRangeForScreenRow(21)).toEqual [25, 30]

    describe "when the row range surrounds existing regions", ->
      it "replaces the regions inside the given buffer row range with a single region", ->
        map.mapBufferRowRange(5, 10, 1)  # inner fold 1
        map.mapBufferRowRange(11, 13, 1)  # inner fold 2
        map.mapBufferRowRange(15, 20, 1) # inner fold 3
        map.mapBufferRowRange(22, 27, 1) # following fold

        map.mapBufferRowRange(5, 20, 1)

        expect(map.bufferRowRangeForScreenRow(5)).toEqual [5, 20]
        expect(map.bufferRowRangeForScreenRow(6)).toEqual [20, 21]
        expect(map.bufferRowRangeForScreenRow(7)).toEqual [21, 22]
        expect(map.bufferRowRangeForScreenRow(8)).toEqual [22, 27]

  describe ".applyScreenDelta(startScreenRow, delta)", ->
    describe "when applying a positive delta", ->
      it "can enlarge the screen side of existing mappings", ->
        map.mapBufferRowRange(5, 6, 3) # wrapped line
        map.applyScreenDelta(5, 2) # wrap it twice more
        expect(map.screenRowRangeForBufferRow(5)).toEqual [5, 10]

    describe "when applying a negative delta", ->
      it "can collapse the screen side of multiple mappings to 0 until the entire delta has been applied", ->
        map.mapBufferRowRange(5, 10, 1)  # inner fold 1
        map.mapBufferRowRange(11, 13, 1)  # inner fold 2
        map.mapBufferRowRange(15, 20, 1) # inner fold 3
        map.mapBufferRowRange(22, 27, 1) # following fold

        map.applyScreenDelta(6, -5)

        expect(map.screenRowRangeForBufferRow(5)).toEqual [5, 6]
        expect(map.screenRowRangeForBufferRow(9)).toEqual [5, 6]
        expect(map.screenRowRangeForBufferRow(10)).toEqual [6, 6]
        expect(map.screenRowRangeForBufferRow(19)).toEqual [6, 6]
        expect(map.screenRowRangeForBufferRow(22)).toEqual [8, 9]
        expect(map.screenRowRangeForBufferRow(26)).toEqual [8, 9]

    it "does not throw an exception when applying a delta beyond the last mapping", ->
      map.mapBufferRowRange(5, 10, 1)  # inner fold 1
      map.applyScreenDelta(15, 10)
