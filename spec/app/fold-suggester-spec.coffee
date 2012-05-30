FoldSuggester = require 'fold-suggester'
Buffer = require 'buffer'

describe "FoldSuggester", ->
  foldSuggester = null

  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    foldSuggester = new FoldSuggester(buffer)

  describe ".isBufferRowFoldable(bufferRow)", ->
    it "returns true only when the buffer row starts a foldable region", ->
      expect(foldSuggester.isBufferRowFoldable(0)).toBeTruthy()
      expect(foldSuggester.isBufferRowFoldable(1)).toBeTruthy()
      expect(foldSuggester.isBufferRowFoldable(2)).toBeFalsy()
      expect(foldSuggester.isBufferRowFoldable(3)).toBeFalsy()
