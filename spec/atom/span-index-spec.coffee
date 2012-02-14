SpanIndex = require 'span-index'

describe "SpanIndex", ->
  index = null
  beforeEach ->
    index = new SpanIndex

  describe ".sliceBySpan(start, end)", ->
    describe "when the index contains values that start and end evenly on the given start/end span indices", ->
      it "returns the spanning values with a start and end offset of 0", ->
        index.insert(0, [1, 2, 3, 1, 2], ['a', 'b', 'c', 'd', 'e'])
        { values, startOffset, endOffset } = index.sliceBySpan(1, 6)

        expect(values).toEqual ['b', 'c', 'd']
        expect(startOffset).toBe 0
        expect(endOffset).toBe 0

    describe "when the index contains values that overlap the given start/end span indices", ->
      it "includes the overlapping values, assigning the start and end offsets to indicate where they overlap the desired span indices", ->
        index.insert(0, [3, 1, 1, 3, 1], ['a', 'b', 'c', 'd', 'e'])
        { values, startOffset, endOffset } = index.sliceBySpan(1, 7)

        expect(values).toEqual ['a', 'b', 'c', 'd']
        expect(startOffset).toBe 1
        expect(endOffset).toBe 2

        index.clear()
        index.insert(0, [1, 4, 1], ['a', 'b', 'c'])
        { values, startOffset, endOffset } = index.sliceBySpan(3, 4)

        expect(values).toEqual ['b']
        expect(startOffset).toBe 2
        expect(endOffset).toBe 3

      describe "when the index contains values with a span of 0", ->
        it "treats 0-spanning values as having no width", ->
          index.insert(0, [0, 0, 3, 2, 3, 1], ['a', 'b', 'c', 'd', 'e', 'f'])
          { values, startOffset, endOffset } = index.sliceBySpan(1, 7)
          expect(values).toEqual ['c', 'd', 'e']
          expect(startOffset).toBe 1
          expect(endOffset).toBe 2

        it "does not include 0-spanning values in the returned slice", ->
          index.insert(0, [3, 0, 2, 0, 3, 1], ['a', 'b', 'c', 'd', 'e', 'f'])
          { values, startOffset, endOffset } = index.sliceBySpan(1, 7)
          expect(values).toEqual ['a', 'c', 'e']
          expect(startOffset).toBe 1
          expect(endOffset).toBe 2

  describe ".lengthBySpan()", ->
    it "returns the sum the spans of all entries in the index", ->
      index.insert(0, [3, 0, 2, 0, 3, 1], ['a', 'b', 'c', 'd', 'e', 'f'])
      expect(index.lengthBySpan()).toBe 9

  describe ".indexForSpan(span)", ->
    it "returns the index of the entry whose aggregated span meets or exceeds the given span, plus an offset", ->
      index.insert(0, [3, 0, 2, 1], ['a', 'b', 'c', 'd'])
      expect(index.indexForSpan(0)).toEqual(index: 0, offset: 0)
      expect(index.indexForSpan(2)).toEqual(index: 0, offset: 2)
      expect(index.indexForSpan(3)).toEqual(index: 2, offset: 0)
      expect(index.indexForSpan(4)).toEqual(index: 2, offset: 1)
      expect(index.indexForSpan(5)).toEqual(index: 3, offset: 0)

  describe ".spanForIndex(index)", ->
    it "returns the aggregate of spans for elements preceding the given index", ->
      index.insert(0, [3, 0, 2, 0, 3, 1], ['a', 'b', 'c', 'd', 'e', 'f'])
      expect(index.spanForIndex(0)).toBe 0
      expect(index.spanForIndex(1)).toBe 3
      expect(index.spanForIndex(2)).toBe 3
      expect(index.spanForIndex(3)).toBe 5






