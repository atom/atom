Autocomplete = require 'autocomplete'
Buffer = require 'buffer'
Editor = require 'editor'

describe "Autocomplete", ->
  autocomplete = null
  editor = null

  beforeEach ->
    editor = new Editor()
    editor.setBuffer new Buffer(require.resolve('fixtures/sample.js'))
    autocomplete = new Autocomplete(editor)

  describe '.wordMatches(prefix, suffix)', ->
    it 'returns wordMatches on buffer starting with given prefix and ending with given suffix', ->
      wordMatches = autocomplete.wordMatches("s", "").map (match) -> match[0]
      expect(wordMatches.length).toBe 2
      expect(wordMatches).toContain("sort")
      expect(wordMatches).toContain("shift")

      wordMatches = autocomplete.wordMatches("l", "t").map (match) -> match[0]
      expect(wordMatches.length).toBe 1
      expect(wordMatches).toContain("left")

    it 'ignores case when finding matches', ->
      wordMatches = autocomplete.wordMatches("S", "").map (match) -> match[0]
      expect(wordMatches.length).toBe 2
      expect(wordMatches).toContain("sort")
      expect(wordMatches).toContain("shift")

      wordMatches = autocomplete.wordMatches("l", "t").map (match) -> match[0]
      expect(wordMatches.length).toBe 1
      expect(wordMatches).toContain("left")

  describe ".completeWord()", ->
    describe "when no text is selected", ->
      it 'autocompletes word when there is only a prefix', ->
        editor.buffer.insert([10,0] ,"extra:s:extra")
        editor.setCursorBufferPosition([10,7])
        autocomplete.completeWord()

        expect(editor.lineForBufferRow(10)).toBe "extra:sort:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,10]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,7], [10,10]]

      it 'autocompletes word when there is only a suffix', ->
        editor.buffer.insert([10,0] ,"extra:e:extra")
        editor.setCursorBufferPosition([10,6])
        autocomplete.completeWord()

        expect(editor.lineForBufferRow(10)).toBe "extra:while:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,10]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,6], [10,10]]

      it 'autocompletes word when there is a prefix and suffix', ->
        editor.buffer.insert([8,43] ,"q")
        editor.setCursorBufferPosition([8,44])
        autocomplete.completeWord()

        expect(editor.lineForBufferRow(8)).toBe "    return sort(left).concat(pivot).concat(quicksort(right));"
        expect(editor.getCursorBufferPosition()).toEqual [8,48]
        expect(editor.getSelection().getBufferRange()).toEqual [[8,44], [8,48]]

    describe "when text is selected", ->
      it 'autocompletes word when there is only a prefix', ->
        editor.buffer.insert([10,0] ,"extra:sort:extra")
        editor.setSelectionBufferRange [[10,7], [10,10]]
        autocomplete.completeWord()

        expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,11]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,7],[10,11]]

      it 'autocompletes word when there is only a suffix', ->
        editor.buffer.insert([10,0] ,"extra:current:extra")
        editor.setSelectionBufferRange [[10,6],[10,12]]
        autocomplete.completeWord()

        expect(editor.lineForBufferRow(10)).toBe "extra:quicksort:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,14]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,6],[10,14]]

      it 'autocompletes word when there is a prefix and suffix', ->
        editor.setSelectionBufferRange [[5,7],[5,12]]
        autocomplete.completeWord()

        expect(editor.lineForBufferRow(5)).toBe "      concat = items.shift();"
        expect(editor.getCursorBufferPosition()).toEqual [5,11]
        expect(editor.getSelection().getBufferRange()).toEqual [[5,7], [5,11]]

  describe 'when changes are made to the buffer', ->
    it 'updates word list', ->
      wordList = autocomplete.wordList
      expect(wordList).toContain "quicksort"
      expect(wordList).not.toContain "sauron"

      editor.buffer.change([[0,4],[0,13]], "sauron")

      wordList = autocomplete.wordList
      expect(wordList).not.toContain "quicksort"
      expect(wordList).toContain "sauron"

  describe "when editor's buffer is changed", ->
    it 'creates and uses a new word list based on new buffer', ->
      wordList = autocomplete.wordList
      expect(wordList).toContain "quicksort"
      expect(wordList).not.toContain "Some"

      editor.setBuffer new Buffer(require.resolve('fixtures/sample.txt'))

      wordList = autocomplete.wordList
      expect(wordList).not.toContain "quicksort"
      expect(wordList).toContain "Some"

    it 'stops listening to previous buffers change events', ->
      previousBuffer = editor.buffer
      editor.setBuffer new Buffer(require.resolve('fixtures/sample.txt'))
      spyOn(autocomplete, "buildWordList")

      previousBuffer.change([[0,0],[0,1]], "sauron")

      expect(autocomplete.buildWordList).not.toHaveBeenCalled()
