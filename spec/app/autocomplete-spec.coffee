$ = require 'jquery'
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

  afterEach ->
    autocomplete.remove()

  describe 'autocomplete:toggle event', ->
    it 'shows autocomplete view', ->
      expect($(document).find('#autocomplete')).not.toExist()
      editor.trigger "autocomplete:toggle"
      expect($(document).find('#autocomplete')).toExist()
      editor.trigger "autocomplete:toggle"
      expect($(document).find('#autocomplete')).not.toExist()

    describe "when no text is selected", ->
      it 'autocompletes word when there is only a prefix', ->
        editor.buffer.insert([10,0] ,"extra:s:extra")
        editor.setCursorBufferPosition([10,7])
        editor.trigger "autocomplete:toggle"

        expect(editor.lineForBufferRow(10)).toBe "extra:sort:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,10]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,7], [10,10]]

      it 'autocompletes word when there is only a suffix', ->
        editor.buffer.insert([10,0] ,"extra:e:extra")
        editor.setCursorBufferPosition([10,6])
        editor.trigger "autocomplete:toggle"

        expect(editor.lineForBufferRow(10)).toBe "extra:while:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,10]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,6], [10,10]]

      it 'autocompletes word when there is a prefix and suffix', ->
        editor.buffer.insert([8,43] ,"q")
        editor.setCursorBufferPosition([8,44])
        editor.trigger "autocomplete:toggle"

        expect(editor.lineForBufferRow(8)).toBe "    return sort(left).concat(pivot).concat(quicksort(right));"
        expect(editor.getCursorBufferPosition()).toEqual [8,48]
        expect(editor.getSelection().getBufferRange()).toEqual [[8,44], [8,48]]

    describe "when text is selected", ->
      it 'autocompletes word when there is only a prefix', ->
        editor.buffer.insert([10,0] ,"extra:sort:extra")
        editor.setSelectionBufferRange [[10,7], [10,10]]
        editor.trigger "autocomplete:toggle"

        expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,11]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,7],[10,11]]

      it 'autocompletes word when there is only a suffix', ->
        editor.buffer.insert([10,0] ,"extra:current:extra")
        editor.setSelectionBufferRange [[10,6],[10,12]]
        editor.trigger "autocomplete:toggle"

        expect(editor.lineForBufferRow(10)).toBe "extra:quicksort:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,14]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,6],[10,14]]

      it 'autocompletes word when there is a prefix and suffix', ->
        editor.setSelectionBufferRange [[5,7],[5,12]]
        editor.trigger "autocomplete:toggle"

        expect(editor.lineForBufferRow(5)).toBe "      concat = items.shift();"
        expect(editor.getCursorBufferPosition()).toEqual [5,11]
        expect(editor.getSelection().getBufferRange()).toEqual [[5,7], [5,11]]

  describe 'autocomplete:select event', ->
    it 'replaces selection with selected match, removes autocomplete view and returns focus to editor', ->
      editor.buffer.insert([10,0] ,"extra:sort:extra")
      editor.setSelectionBufferRange [[10,7], [10,10]]
      editor.trigger "autocomplete:toggle"
      autocomplete.trigger "autocomplete:select"

      expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
      expect(editor.getCursorBufferPosition()).toEqual [10,11]
      expect(editor.getSelection().isEmpty()).toBeTruthy()
      expect($(document).find('#autocomplete')).not.toExist()

  describe 'autocomplete:cancel event', ->
    it 'does not replace selection, removes autocomplete view and returns focus to editor', ->
      editor.buffer.insert([10,0] ,"extra:so:extra")
      editor.setSelectionBufferRange [[10,7], [10,8]]
      originalSelectionBufferRange = editor.getSelection().getBufferRange()

      editor.trigger "autocomplete:toggle"
      autocomplete.trigger "autocomplete:cancel"

      expect(editor.lineForBufferRow(10)).toBe "extra:so:extra"
      expect(editor.getSelection().getBufferRange()).toEqual originalSelectionBufferRange
      expect($(document).find('#autocomplete')).not.toExist()

  describe 'move-up event', ->
    it 'replaces selection with previous match', ->
      editor.buffer.insert([10,0] ,"extra:t:extra")
      editor.setCursorBufferPosition([10,6])
      editor.trigger "autocomplete:toggle"

      autocomplete.trigger "move-up"
      expect(editor.lineForBufferRow(10)).toBe "extra:concat:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(1)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(7)')).toHaveClass('selected')

      autocomplete.trigger "move-up"
      expect(editor.lineForBufferRow(10)).toBe "extra:right:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(7)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(6)')).toHaveClass('selected')

  describe 'move-down event', ->
    it 'replaces selection with next match', ->
      editor.buffer.insert([10,0] ,"extra:s:extra")
      editor.setCursorBufferPosition([10,7])
      editor.trigger "autocomplete:toggle"

      autocomplete.trigger "move-down"
      expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(1)')).toHaveClass('selected')

      autocomplete.trigger "move-down"
      expect(editor.lineForBufferRow(10)).toBe "extra:sort:extra"
      expect(autocomplete.find('li:eq(0)')).toHaveClass('selected')
      expect(autocomplete.find('li:eq(1)')).not.toHaveClass('selected')

  describe 'when changes are made to the buffer', ->
    it 'updates word list', ->
      spyOn(autocomplete, 'buildWordList')
      editor.buffer.change([[0,4],[0,13]], "sauron")
      expect(autocomplete.buildWordList).toHaveBeenCalled()

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

  describe 'when autocomplete changes buffer', ->
    it 'does not rebuild the word list', ->
      editor.buffer.insert([10,0] ,"extra:s:extra")

      spyOn(autocomplete, 'buildWordList')
      editor.setCursorBufferPosition([10,7])
      editor.trigger "autocomplete:toggle"
      expect(autocomplete.buildWordList).not.toHaveBeenCalled()

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

  describe ".show()", ->
    beforeEach ->
      editor.attachToDom()
      editor.buffer.insert([10,0] ,"extra:s:extra")
      editor.setCursorBufferPosition([10,7])
      autocomplete.show()

    it "adds the autocomplete view to the editor", ->
      expect($(document).find('#autocomplete')).toExist()
      expect(autocomplete.position().top).toBeGreaterThan 0
      expect(autocomplete.position().left).toBeGreaterThan 0

    it "displays words that match letters surrounding the current selection", ->
      expect(autocomplete.matchesList.find('li').length).toBe 2
      expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText('sort')
      expect(autocomplete.matchesList.find('li:eq(1)')).toHaveText('shift')

    it "selects the first match and replaces the seleced text with it", ->
      expect(autocomplete.matchesList.find('li').length).toBe 2
      expect(autocomplete.matchesList.find('li:eq(0)')).toHaveClass('selected')
      expect(autocomplete.matchesList.find('li:eq(1)')).not.toHaveClass('selected')

      expect(editor.lineForBufferRow(10)).toBe "extra:sort:extra"