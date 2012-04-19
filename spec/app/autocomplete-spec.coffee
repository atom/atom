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
    it "shows autocomplete view and adds 'autocomplete' class to editor", ->
      expect($(document).find('#autocomplete')).not.toExist()
      expect(editor).not.toHaveClass('autocomplete')

      editor.trigger "autocomplete:toggle"
      expect($(document).find('#autocomplete')).toExist()
      expect(editor).toHaveClass('autocomplete')

      editor.trigger "autocomplete:toggle"
      expect($(document).find('#autocomplete')).not.toExist()
      expect(editor).not.toHaveClass('autocomplete')

    describe "when no text is selected", ->
      it 'autocompletes word when there is only a prefix', ->
        editor.buffer.insert([10,0] ,"extra:s:extra")
        editor.setCursorBufferPosition([10,7])
        editor.trigger "autocomplete:toggle"

        expect(editor.lineForBufferRow(10)).toBe "extra:sort:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,10]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,7], [10,10]]

        expect(autocomplete.matchesList.find('li').length).toBe 2
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText('sort')
        expect(autocomplete.matchesList.find('li:eq(1)')).toHaveText('shift')

      it 'autocompletes word when there is only a suffix', ->
        editor.buffer.insert([10,0] ,"extra:e:extra")
        editor.setCursorBufferPosition([10,6])
        editor.trigger "autocomplete:toggle"

        expect(editor.lineForBufferRow(10)).toBe "extra:while:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,10]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,6], [10,10]]

        expect(autocomplete.matchesList.find('li').length).toBe 1
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText('while')

      it 'autocompletes word when there is a prefix and suffix', ->
        editor.buffer.insert([8,43] ,"q")
        editor.setCursorBufferPosition([8,44])
        editor.trigger "autocomplete:toggle"

        expect(editor.lineForBufferRow(8)).toBe "    return sort(left).concat(pivot).concat(quicksort(right));"
        expect(editor.getCursorBufferPosition()).toEqual [8,48]
        expect(editor.getSelection().getBufferRange()).toEqual [[8,44], [8,48]]

        expect(autocomplete.matchesList.find('li').length).toBe 1
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText('quicksort')

    describe "when text is selected", ->
      it 'autocompletes word when there is only a prefix', ->
        editor.buffer.insert([10,0] ,"extra:sort:extra")
        editor.setSelectionBufferRange [[10,7], [10,10]]
        editor.trigger "autocomplete:toggle"

        expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,11]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,7],[10,11]]

        expect(autocomplete.matchesList.find('li').length).toBe 1
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText('shift')

      it 'autocompletes word when there is only a suffix', ->
        editor.buffer.insert([10,0] ,"extra:current:extra")
        editor.setSelectionBufferRange [[10,6],[10,12]]
        editor.trigger "autocomplete:toggle"

        expect(editor.lineForBufferRow(10)).toBe "extra:quicksort:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,14]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,6],[10,14]]

        expect(autocomplete.matchesList.find('li').length).toBe 7
        expect(autocomplete.matchesList.find('li:contains(current)')).not.toExist()

      it 'autocompletes word when there is a prefix and suffix', ->
        editor.setSelectionBufferRange [[5,7],[5,12]]
        editor.trigger "autocomplete:toggle"

        expect(editor.lineForBufferRow(5)).toBe "      concat = items.shift();"
        expect(editor.getCursorBufferPosition()).toEqual [5,11]
        expect(editor.getSelection().getBufferRange()).toEqual [[5,7], [5,11]]

        expect(autocomplete.matchesList.find('li').length).toBe 1
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText('concat')

  describe 'autocomplete:select event', ->
    it 'replaces selection with selected match, removes autocomplete view and returns focus to editor', ->
      editor.buffer.insert([10,0] ,"extra:sort:extra")
      editor.setSelectionBufferRange [[10,7], [10,10]]
      editor.trigger "autocomplete:toggle"
      editor.trigger "autocomplete:select"

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
      editor.trigger "autocomplete:cancel"

      expect(editor.lineForBufferRow(10)).toBe "extra:so:extra"
      expect(editor.getSelection().getBufferRange()).toEqual originalSelectionBufferRange
      expect($(document).find('#autocomplete')).not.toExist()

  describe 'move-up event', ->
    it 'replaces selection with previous match', ->
      editor.buffer.insert([10,0] ,"extra:t:extra")
      editor.setCursorBufferPosition([10,6])
      editor.trigger "autocomplete:toggle"

      editor.trigger "move-up"
      expect(editor.lineForBufferRow(10)).toBe "extra:concat:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(1)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(7)')).toHaveClass('selected')

      editor.trigger "move-up"
      expect(editor.lineForBufferRow(10)).toBe "extra:right:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(7)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(6)')).toHaveClass('selected')

  describe 'move-down event', ->
    it 'replaces selection with next match', ->
      editor.buffer.insert([10,0] ,"extra:s:extra")
      editor.setCursorBufferPosition([10,7])
      editor.trigger "autocomplete:toggle"

      editor.trigger "move-down"
      expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(1)')).toHaveClass('selected')

      editor.trigger "move-down"
      expect(editor.lineForBufferRow(10)).toBe "extra:sort:extra"
      expect(autocomplete.find('li:eq(0)')).toHaveClass('selected')
      expect(autocomplete.find('li:eq(1)')).not.toHaveClass('selected')

  describe 'when the cursor is moved', ->
    it "cancels the autocomplete", ->
      editor.buffer.insert([10,0] ,"extra:s:extra")
      editor.setCursorBufferPosition([10,7])
      editor.trigger "autocomplete:toggle"

      spyOn(autocomplete, "cancel").andCallThrough()
      editor.moveCursorRight()
      expect(autocomplete.cancel).toHaveBeenCalled()
      expect(editor.lineForBufferRow(10)).toBe "extra:s:extra"

  describe 'when changes are made to the buffer', ->
    describe "when the autocomplete menu is detached", ->
      it 'updates word list', ->
        spyOn(autocomplete, 'buildWordList')
        editor.buffer.change([[0,4],[0,13]], "sauron")
        expect(autocomplete.buildWordList).toHaveBeenCalled()

    describe "when the autocomplete menu is attached", ->
      describe 'when the change was caused by autocomplete', ->
        it 'does not rebuild the word list', ->
          editor.buffer.insert([10,0] ,"extra:s:extra")

          spyOn(autocomplete, 'buildWordList')
          editor.setCursorBufferPosition([10,7])
          editor.trigger "autocomplete:toggle"
          expect(autocomplete.buildWordList).not.toHaveBeenCalled()

      describe "when the change was not caused by autocomplete", ->
        it "rebuilds the match list based on the new prefix and suffix", ->
          editor.buffer.insert([10, 0] ,"t")
          editor.setCursorBufferPosition [10, 0]
          editor.trigger "autocomplete:toggle"
          expect($(document).find('#autocomplete')).toExist()

          console.log "inserting!!!!!!!!!!!"
          editor.insertText('c')

          expect($(document).find('#autocomplete')).toExist()

          expect(editor.lineForBufferRow(10)).toBe "current"
          # expect(editor.getCursorBufferPosition()).toEqual [10,10]
          # expect(editor.getSelection().getBufferRange()).toEqual [[10,7], [10,10]]

          # expect(autocomplete.matchesList.find('li').length).toBe 2
          # expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText('sort')
          # expect(autocomplete.matchesList.find('li:eq(1)')).toHaveText('shift')

  describe "when editor's buffer is assigned a new buffer", ->
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

  describe 'when the editor is removed', ->
    it 'removes event listeners from its buffer', ->
      spyOn(autocomplete, 'buildWordList').andCallThrough()
      editor.buffer.insert([0,0], "s")
      expect(autocomplete.buildWordList).toHaveBeenCalled()

      autocomplete.buildWordList.reset()
      editor.remove()
      editor.buffer.insert([0,0], "s")
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

  describe ".attach()", ->
    beforeEach ->
      editor.attachToDom()
      autocomplete.attach()

    it "adds the autocomplete view to the editor", ->
      expect($(document).find('#autocomplete')).toExist()
      expect(autocomplete.position().top).toBeGreaterThan 0
      expect(autocomplete.position().left).toBeGreaterThan 0

  describe ".detach()", ->
    it "unbinds autocomplete event handlers for move-up and move-down", ->
      autocomplete.attach()
      autocomplete.detach()

      editor.trigger 'move-down'
      expect(editor.getCursorBufferPosition().row).toBe 1

      editor.trigger 'move-up'
      expect(editor.getCursorBufferPosition().row).toBe 0


