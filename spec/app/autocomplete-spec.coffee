$ = require 'jquery'
Autocomplete = require 'autocomplete'
Buffer = require 'buffer'
Editor = require 'editor'
RootView = require 'root-view'

describe "Autocomplete", ->
  autocomplete = null
  editor = null
  miniEditor = null

  beforeEach ->
    editor = new Editor()
    editor.setBuffer new Buffer(require.resolve('fixtures/sample.js'))
    autocomplete = new Autocomplete(editor)
    miniEditor = autocomplete.miniEditor

  describe "@activate(rootView)", ->
    it "activates autocomplete on all existing and future editors (but not on autocomplete's own mini editor)", ->
      rootView = new RootView(pathToOpen: require.resolve('fixtures/sample.js'))
      rootView.simulateDomAttachment()
      Autocomplete.activate(rootView)
      leftEditor = rootView.activeEditor()
      rightEditor = rootView.activeEditor().splitRight()

      spyOn(Autocomplete.prototype, 'initialize')

      leftEditor.trigger 'autocomplete:attach'
      expect(leftEditor.find('.autocomplete')).toExist()
      expect(rightEditor.find('.autocomplete')).not.toExist()

      leftEditor.trigger 'autocomplete:cancel'
      rightEditor.trigger 'autocomplete:attach'
      expect(leftEditor.find('.autocomplete')).not.toExist()
      expect(rightEditor.find('.autocomplete')).toExist()

      expect(Autocomplete.prototype.initialize).not.toHaveBeenCalled()

  describe 'autocomplete:attach event', ->
    it "shows autocomplete view and focuses its mini-editor", ->
      expect(editor.find('.autocomplete')).not.toExist()

      editor.trigger "autocomplete:attach"
      expect(editor.find('.autocomplete')).toExist()
      expect(autocomplete.editor.isFocused).toBeFalsy()
      expect(autocomplete.miniEditor.isFocused).toBeTruthy()

    describe "when no text is selected", ->
      it 'autocompletes word when there is only a prefix', ->
        editor.buffer.insert([10,0] ,"extra:s:extra")
        editor.setCursorBufferPosition([10,7])
        autocomplete.attach()

        expect(editor.lineForBufferRow(10)).toBe "extra:sort:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,10]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,7], [10,10]]

        expect(autocomplete.matchesList.find('li').length).toBe 2
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText('sort')
        expect(autocomplete.matchesList.find('li:eq(1)')).toHaveText('shift')

      it 'autocompletes word when there is only a suffix', ->
        editor.buffer.insert([10,0] ,"extra:e:extra")
        editor.setCursorBufferPosition([10,6])
        autocomplete.attach()

        expect(editor.lineForBufferRow(10)).toBe "extra:while:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,10]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,6], [10,10]]

        expect(autocomplete.matchesList.find('li').length).toBe 1
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText('while')

      it 'autocompletes word when there is a prefix and suffix', ->
        editor.buffer.insert([8,43] ,"q")
        editor.setCursorBufferPosition([8,44])
        autocomplete.attach()

        expect(editor.lineForBufferRow(8)).toBe "    return sort(left).concat(pivot).concat(quicksort(right));"
        expect(editor.getCursorBufferPosition()).toEqual [8,48]
        expect(editor.getSelection().getBufferRange()).toEqual [[8,44], [8,48]]

        expect(autocomplete.matchesList.find('li').length).toBe 1
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText('quicksort')

      it "show's that there are no matches found when there is no prefix or suffix", ->
        editor.setCursorBufferPosition([10, 0])
        autocomplete.attach()

        expect(autocomplete.matchesList.find('li').length).toBe 1
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText "No matches found"

    describe "when text is selected", ->
      it 'autocompletes word when there is only a prefix', ->
        editor.buffer.insert([10,0] ,"extra:sort:extra")
        editor.setSelectionBufferRange [[10,7], [10,10]]
        autocomplete.attach()

        expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,11]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,7],[10,11]]

        expect(autocomplete.matchesList.find('li').length).toBe 1
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText('shift')

      it 'autocompletes word when there is only a suffix', ->
        editor.buffer.insert([10,0] ,"extra:current:extra")
        editor.setSelectionBufferRange [[10,6],[10,12]]
        autocomplete.attach()

        expect(editor.lineForBufferRow(10)).toBe "extra:quicksort:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,14]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,6],[10,14]]

        expect(autocomplete.matchesList.find('li').length).toBe 7
        expect(autocomplete.matchesList.find('li:contains(current)')).not.toExist()

      it 'autocompletes word when there is a prefix and suffix', ->
        editor.setSelectionBufferRange [[5,7],[5,12]]
        autocomplete.attach()

        expect(editor.lineForBufferRow(5)).toBe "      concat = items.shift();"
        expect(editor.getCursorBufferPosition()).toEqual [5,11]
        expect(editor.getSelection().getBufferRange()).toEqual [[5,7], [5,11]]

        expect(autocomplete.matchesList.find('li').length).toBe 1
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText('concat')

  describe 'autocomplete:confirm event', ->
    it 'replaces selection with selected match, moves the cursor to the end of the match, and removes the autocomplete menu', ->
      editor.buffer.insert([10,0] ,"extra:sort:extra")
      editor.setSelectionBufferRange [[10,7], [10,9]]
      autocomplete.attach()
      miniEditor.trigger "autocomplete:confirm"

      expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
      expect(editor.getCursorBufferPosition()).toEqual [10,11]
      expect(editor.getSelection().isEmpty()).toBeTruthy()
      expect(editor.find('.autocomplete')).not.toExist()

    describe "when there are no matches", ->
      it "closes the menu without changing the buffer", ->
        editor.buffer.insert([10,0] ,"xxx")
        editor.setCursorBufferPosition [10, 3]
        autocomplete.attach()
        expect(autocomplete.matchesList.find('li').length).toBe 1
        expect(autocomplete.matchesList.find('li')).toHaveText ('No matches found')

        miniEditor.trigger "autocomplete:confirm"

        expect(editor.lineForBufferRow(10)).toBe "xxx"
        expect(editor.getCursorBufferPosition()).toEqual [10,3]
        expect(editor.getSelection().isEmpty()).toBeTruthy()
        expect(editor.find('.autocomplete')).not.toExist()

  describe 'autocomplete:cancel event', ->
    it 'does not replace selection, removes autocomplete view and returns focus to editor', ->
      editor.buffer.insert([10,0] ,"extra:so:extra")
      editor.setSelectionBufferRange [[10,7], [10,8]]
      originalSelectionBufferRange = editor.getSelection().getBufferRange()

      autocomplete.attach()
      editor.setCursorBufferPosition [0, 0] # even if selection changes before cancel, it should work
      miniEditor.trigger "autocomplete:cancel"

      expect(editor.lineForBufferRow(10)).toBe "extra:so:extra"
      expect(editor.getSelection().getBufferRange()).toEqual originalSelectionBufferRange
      expect(editor.find('.autocomplete')).not.toExist()

  describe 'move-up event', ->
    it "highlights the previous match and replaces the selection with it", ->
      editor.buffer.insert([10,0] ,"extra:t:extra")
      editor.setCursorBufferPosition([10,6])
      autocomplete.attach()

      miniEditor.trigger "move-up"
      expect(editor.lineForBufferRow(10)).toBe "extra:concat:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(1)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(7)')).toHaveClass('selected')

      miniEditor.trigger "move-up"
      expect(editor.lineForBufferRow(10)).toBe "extra:right:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(7)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(6)')).toHaveClass('selected')

    it "scrolls to the selected match if it is out of view", ->
      editor.buffer.insert([10,0] ,"t")
      editor.setCursorBufferPosition([10, 0])
      editor.attachToDom()
      autocomplete.attach()

      matchesList = autocomplete.matchesList
      matchesList.height(100)
      expect(matchesList.height()).toBeLessThan matchesList[0].scrollHeight

      matchCount = matchesList.find('li').length
      miniEditor.trigger 'move-up'
      expect(matchesList.scrollBottom()).toBe matchesList[0].scrollHeight

      miniEditor.trigger 'move-up' for i in [1...matchCount]
      expect(matchesList.scrollTop()).toBe 0

  describe 'move-down event', ->
    it "highlights the next match and replaces the selection with it", ->
      editor.buffer.insert([10,0] ,"extra:s:extra")
      editor.setCursorBufferPosition([10,7])
      autocomplete.attach()

      miniEditor.trigger "move-down"
      expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(1)')).toHaveClass('selected')

      miniEditor.trigger "move-down"
      expect(editor.lineForBufferRow(10)).toBe "extra:sort:extra"
      expect(autocomplete.find('li:eq(0)')).toHaveClass('selected')
      expect(autocomplete.find('li:eq(1)')).not.toHaveClass('selected')

    it "scrolls to the selected match if it is out of view", ->
      editor.buffer.insert([10,0] ,"t")
      editor.setCursorBufferPosition([10, 0])
      editor.attachToDom()
      autocomplete.attach()

      matchesList = autocomplete.matchesList
      matchesList.height(100)
      expect(matchesList.height()).toBeLessThan matchesList[0].scrollHeight

      matchCount = matchesList.find('li').length
      miniEditor.trigger 'move-down' for i in [1...matchCount]
      expect(matchesList.scrollBottom()).toBe matchesList[0].scrollHeight

      miniEditor.trigger 'move-down'
      expect(matchesList.scrollTop()).toBe 0

  describe "when a match is clicked in the match list", ->
    it "selects and confirms the match", ->
      editor.buffer.insert([10,0] ,"t")
      editor.setCursorBufferPosition([10, 0])
      autocomplete.attach()

      matchToSelect = autocomplete.matchesList.find('li:eq(1)')
      matchToSelect.mousedown()
      expect(matchToSelect).toMatchSelector('.selected')
      matchToSelect.mouseup()

      expect(autocomplete.parent()).not.toExist()
      expect(editor.lineForBufferRow(10)).toBe matchToSelect.text()

    it "cancels the autocomplete when clicking on the 'No matches found' li", ->
      editor.buffer.insert([10,0] ,"t")
      editor.setCursorBufferPosition([10, 0])
      autocomplete.attach()

      miniEditor.insertText('xxx')
      autocomplete.matchesList.find('li').mousedown().mouseup()

      expect(autocomplete.parent()).not.toExist()
      expect(editor.lineForBufferRow(10)).toBe "t"

  describe "when the mini-editor receives keyboard input", ->
    describe "when text is removed from the mini-editor", ->
      it "reloads the match list based on the mini-editor's text", ->
        editor.buffer.insert([10,0] ,"t")
        editor.setCursorBufferPosition([10,0])
        autocomplete.attach()

        expect(autocomplete.matchesList.find('li').length).toBe 8
        miniEditor.textInput('c')
        expect(autocomplete.matchesList.find('li').length).toBe 3
        miniEditor.backspace()
        expect(autocomplete.matchesList.find('li').length).toBe 8

    describe "when the text contains only word characters", ->
      it "narrows the list of completions with the fuzzy match algorithm", ->
        editor.buffer.insert([10,0] ,"t")
        editor.setCursorBufferPosition([10,0])
        autocomplete.attach()

        expect(autocomplete.matchesList.find('li').length).toBe 8
        miniEditor.textInput('i')
        expect(autocomplete.matchesList.find('li').length).toBe 4
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText 'pivot'
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveClass 'selected'
        expect(autocomplete.matchesList.find('li:eq(1)')).toHaveText 'shift'
        expect(autocomplete.matchesList.find('li:eq(2)')).toHaveText 'right'
        expect(autocomplete.matchesList.find('li:eq(3)')).toHaveText 'quicksort'
        expect(editor.lineForBufferRow(10)).toEqual 'pivot'

        miniEditor.textInput('o')
        expect(autocomplete.matchesList.find('li').length).toBe 2
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText 'pivot'
        expect(autocomplete.matchesList.find('li:eq(1)')).toHaveText 'quicksort'

    describe "when a non-word character is typed in the mini-editor", ->
      it "immediately confirms the current completion choice and inserts that character into the buffer", ->
        editor.buffer.insert([10,0] ,"t")
        editor.setCursorBufferPosition([10,0])
        autocomplete.attach()

        miniEditor.textInput('iv')
        expect(autocomplete.matchesList.find('li:eq(0)')).toHaveText 'pivot'

        miniEditor.textInput(' ')
        expect(autocomplete.parent()).not.toExist()
        expect(editor.lineForBufferRow(10)).toEqual 'pivot '

  describe 'when the editor is focused', ->
    it "cancels the autocomplete", ->
      autocomplete.attach()

      spyOn(autocomplete, "cancel")

      editor.focus()

      expect(autocomplete.cancel).toHaveBeenCalled()

  describe 'when changes are made to the buffer', ->
    describe "when the autocomplete menu is detached", ->
      it 'updates word list', ->
        spyOn(autocomplete, 'buildWordList')
        editor.buffer.change([[0,4],[0,13]], "sauron")
        expect(autocomplete.buildWordList).toHaveBeenCalled()

    describe "when the autocomplete menu is attached and the change was caused by autocomplete itself", ->
      it 'does not rebuild the word list', ->
        editor.buffer.insert([10,0] ,"extra:s:extra")

        spyOn(autocomplete, 'buildWordList')
        editor.setCursorBufferPosition([10,7])
        autocomplete.attach()
        expect(autocomplete.buildWordList).not.toHaveBeenCalled()

  describe "when a new buffer is assigned on editor", ->
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

  describe ".attach()", ->
    beforeEach ->
      editor.attachToDom()
      setEditorHeightInLines(editor, 8)
      editor.setCursorBufferPosition [1, 1]

    describe "when the autocomplete view fits below the cursor", ->
      it "adds the autocomplete view to the editor below the cursor", ->
        cursorPixelPosition = editor.pixelPositionForScreenPosition(editor.getCursorScreenPosition())
        autocomplete.attach()
        expect(editor.find('.autocomplete')).toExist()

        expect(autocomplete.position().top).toBe cursorPixelPosition.top + editor.lineHeight
        expect(autocomplete.position().left).toBe cursorPixelPosition.left

    describe "when the autocomplete view does not fit below the cursor", ->
      it "adds the autocomplete view to the editor above the cursor", ->
        editor.setCursorScreenPosition([6, 0])
        editor.insertText('t ')
        editor.setCursorScreenPosition([6, 0])
        cursorPixelPosition = editor.pixelPositionForScreenPosition(editor.getCursorScreenPosition())
        autocomplete.attach()

        expect(autocomplete.parent()).toExist()
        autocompleteBottom = autocomplete.position().top + autocomplete.outerHeight()
        expect(autocompleteBottom).toBe cursorPixelPosition.top
        expect(autocomplete.position().left).toBe cursorPixelPosition.left

  describe ".detach()", ->
    it "clears the mini-editor and unbinds autocomplete event handlers for move-up and move-down", ->
      autocomplete.attach()
      miniEditor.buffer.setText('foo')

      autocomplete.detach()
      expect(miniEditor.buffer.getText()).toBe ''

      editor.trigger 'move-down'
      expect(editor.getCursorBufferPosition().row).toBe 1

      editor.trigger 'move-up'
      expect(editor.getCursorBufferPosition().row).toBe 0


