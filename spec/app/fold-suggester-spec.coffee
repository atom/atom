FoldSuggester = require 'fold-suggester'
Buffer = require 'buffer'
Highlighter = require 'highlighter'

describe "FoldSuggester", ->
  foldSuggester = null

  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    highlighter = new Highlighter(buffer)
    foldSuggester = new FoldSuggester(highlighter)

  describe ".isBufferRowFoldable(bufferRow)", ->
    it "returns true only when the buffer row starts a foldable region", ->
      expect(foldSuggester.isBufferRowFoldable(0)).toBeTruthy()
      expect(foldSuggester.isBufferRowFoldable(1)).toBeTruthy()
      expect(foldSuggester.isBufferRowFoldable(2)).toBeFalsy()
      expect(foldSuggester.isBufferRowFoldable(3)).toBeFalsy()

  describe ".rowRangeForFoldAtBufferRow(bufferRow)", ->
    it "returns the start/end rows of the foldable region starting at the given row", ->
      expect(foldSuggester.rowRangeForFoldAtBufferRow(0)).toEqual [0, 12]
      expect(foldSuggester.rowRangeForFoldAtBufferRow(1)).toEqual [1, 9]
      expect(foldSuggester.rowRangeForFoldAtBufferRow(2)).toBeNull()
      expect(foldSuggester.rowRangeForFoldAtBufferRow(4)).toEqual [4, 7]

