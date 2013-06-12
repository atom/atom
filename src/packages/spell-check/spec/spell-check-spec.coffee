RootView = require 'root-view'

fdescribe "Spell check", ->
  [editor] = []

  beforeEach ->
    atom.activatePackage('text-tmbundle', sync: true)
    atom.activatePackage('javascript-tmbundle', sync: true)
    window.rootView = new RootView
    rootView.open('sample.js')
    config.set('spell-check.grammars', [])
    atom.activatePackage('spell-check', immediate: true)
    rootView.attachToDom()
    editor = rootView.getActiveView()

  it "decorates all misspelled words", ->
    editor.setText("This middle of thiss sentencts has issues.")
    config.set('spell-check.grammars', ['source.js'])

    waitsFor ->
      editor.find('.misspelling').length > 0

    runs ->
      expect(editor.find('.misspelling').length).toBe 2

      typo1StartPosition = editor.pixelPositionForBufferPosition([0, 15])
      typo1EndPosition = editor.pixelPositionForBufferPosition([0, 20])
      expect(editor.find('.misspelling:eq(0)').position()).toEqual typo1StartPosition
      expect(editor.find('.misspelling:eq(0)').width()).toBe typo1EndPosition.left - typo1StartPosition.left

      typo2StartPosition = editor.pixelPositionForBufferPosition([0, 21])
      typo2EndPosition = editor.pixelPositionForBufferPosition([0, 30])
      expect(editor.find('.misspelling:eq(1)').position()).toEqual typo2StartPosition
      expect(editor.find('.misspelling:eq(1)').width()).toBe typo2EndPosition.left - typo2StartPosition.left

  it "hides decorations when a misspelled word is edited", ->
    editor.setText('notaword')
    advanceClock(editor.getBuffer().stoppedChangingDelay)
    config.set('spell-check.grammars', ['source.js'])

    waitsFor ->
      editor.find('.misspelling').length > 0

    runs ->
      expect(editor.find('.misspelling').length).toBe 1
      editor.moveCursorToEndOfLine()
      editor.insertText('a')
      advanceClock(editor.getBuffer().stoppedChangingDelay)
      expect(editor.find('.misspelling')).toBeHidden()

  describe "when spell checking for a grammar is removed", ->
    it "removes all current decorations", ->
      editor.setText('notaword')
      advanceClock(editor.getBuffer().stoppedChangingDelay)
      config.set('spell-check.grammars', ['source.js'])

      waitsFor ->
        editor.find('.misspelling').length > 0

      runs ->
        expect(editor.find('.misspelling').length).toBe 1
        config.set('spell-check.grammars', [])
        expect(editor.find('.misspelling').length).toBe 0

  describe "when 'editor:correct-misspelling' is triggered on the editor", ->
    describe "when the cursor touches a misspelling that has corrections", ->
      it "displays the corrections for the misspelling and replaces the misspelling when a correction is selected", ->
        editor.setText('fryday')
        advanceClock(editor.getBuffer().stoppedChangingDelay)
        config.set('spell-check.grammars', ['source.js'])

        waitsFor ->
          editor.find('.misspelling').length > 0

        runs ->
          editor.trigger 'editor:correct-misspelling'
          expect(editor.find('.corrections').length).toBe 1
          expect(editor.find('.corrections li').length).toBeGreaterThan 0
          expect(editor.find('.corrections li:first').text()).toBe "Friday"
          editor.find('.corrections').view().confirmSelection()
          expect(editor.getText()).toBe 'Friday'
          expect(editor.getCursorBufferPosition()).toEqual [0, 6]
          advanceClock(editor.getBuffer().stoppedChangingDelay)
          expect(editor.find('.misspelling')).toBeHidden()
          expect(editor.find('.corrections').length).toBe 0

    describe "when the cursor touches a misspelling that has no corrections", ->
      it "displays a message saying no corrections found", ->
        editor.setText('asdfasdf')
        advanceClock(editor.getBuffer().stoppedChangingDelay)
        config.set('spell-check.grammars', ['source.js'])

        waitsFor ->
          editor.find('.misspelling').length > 0

        runs ->
          editor.trigger 'editor:correct-misspelling'
          expect(editor.find('.corrections').length).toBe 1
          expect(editor.find('.corrections li').length).toBe 0
          expect(editor.find('.corrections').view().error.text()).toBe "No corrections"

  describe "when the edit session is destroyed", ->
    it "destroys all misspelling markers", ->
      editor.setText("mispelling")
      config.set('spell-check.grammars', ['source.js'])

      waitsFor ->
        editor.find('.misspelling').length > 0

      runs ->
        expect(editor.find('.misspelling').length).toBe 1
        view = editor.find('.misspelling').view()
        buffer = editor.getBuffer()
        expect(view.marker.isDestroyed()).toBeFalsy()
        editor.remove()
        expect(view.marker.isDestroyed()).toBeTruthy()
