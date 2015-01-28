TextBuffer = require 'text-buffer'
TextEditor = require '../src/text-editor'
TextEditorPresenter = require '../src/text-editor-presenter'

describe "TextEditorPresenter", ->
  [buffer, editor] = []

  beforeEach ->
    # These *should* be mocked in the spec helper, but changing that now would break packages :-(
    spyOn(window, "setInterval").andCallFake window.fakeSetInterval
    spyOn(window, "clearInterval").andCallFake window.fakeClearInterval

    buffer = new TextBuffer(filePath: require.resolve('./fixtures/sample.js'))
    editor = new TextEditor({buffer})
    waitsForPromise -> buffer.load()

  afterEach ->
    editor.destroy()
    buffer.destroy()

  expectValues = (actual, expected) ->
    for key, value of expected
      expect(actual[key]).toEqual value

  expectStateUpdate = (presenter, fn) ->
    updatedState = false
    disposable = presenter.onDidUpdateState ->
      updatedState = true
      disposable.dispose()
    fn()
    expect(updatedState).toBe true

  # These `describe` and `it` blocks mirror the structure of the ::state object.
  # Please maintain this structure when adding specs for new state fields.
  describe "::state", ->
    describe ".scrollHeight", ->
      it "is initialized based on the lineHeight, the number of lines, and the clientHeight", ->
        presenter = new TextEditorPresenter(model: editor, scrollTop: 0, lineHeight: 10)
        expect(presenter.state.scrollHeight).toBe editor.getScreenLineCount() * 10

        presenter = new TextEditorPresenter(model: editor, scrollTop: 0, lineHeight: 10, clientHeight: 500)
        expect(presenter.state.scrollHeight).toBe 500

      it "updates when the ::lineHeight changes", ->
        presenter = new TextEditorPresenter(model: editor, scrollTop: 0, lineHeight: 10)
        expectStateUpdate presenter, -> presenter.setLineHeight(20)
        expect(presenter.state.scrollHeight).toBe editor.getScreenLineCount() * 20

      it "updates when the line count changes", ->
        presenter = new TextEditorPresenter(model: editor, scrollTop: 0, lineHeight: 10)
        expectStateUpdate presenter, -> editor.getBuffer().append("\n\n\n")
        expect(presenter.state.scrollHeight).toBe editor.getScreenLineCount() * 10

      it "updates when ::clientHeight changes", ->
        presenter = new TextEditorPresenter(model: editor, scrollTop: 0, lineHeight: 10)
        expectStateUpdate presenter, -> presenter.setClientHeight(500)
        expect(presenter.state.scrollHeight).toBe 500

    describe ".scrollTop", ->
      it "tracks the value of ::scrollTop", ->
        presenter = new TextEditorPresenter(model: editor, scrollTop: 10, lineHeight: 10)
        expect(presenter.state.scrollTop).toBe 10
        expectStateUpdate presenter, -> presenter.setScrollTop(50)
        expect(presenter.state.scrollTop).toBe 50

    describe ".scrollingVertically", ->
      it "is true for ::stoppedScrollingDelay milliseconds following a changes to ::scrollTop", ->
        presenter = new TextEditorPresenter(model: editor, scrollTop: 10, stoppedScrollingDelay: 200)
        expect(presenter.state.scrollingVertically).toBe false
        expectStateUpdate presenter, -> presenter.setScrollTop(0)
        expect(presenter.state.scrollingVertically).toBe true
        advanceClock(100)
        expect(presenter.state.scrollingVertically).toBe true
        presenter.setScrollTop(10)
        advanceClock(100)
        expect(presenter.state.scrollingVertically).toBe true
        expectStateUpdate presenter, -> advanceClock(100)
        expect(presenter.state.scrollingVertically).toBe false

    describe ".mousewheelScreenRow", ->
      it "reflects the most recently assigned ::mousewheelScreenRow while .scrollingVertically is true", ->
        presenter = new TextEditorPresenter(model: editor, scrollTop: 10, stoppedScrollingDelay: 200)
        presenter.setMousewheelScreenRow(3)
        expect(presenter.state.scrollingVertically).toBe false
        expect(presenter.state.mousewheelScreenRow).toBeNull()

        expectStateUpdate presenter, -> presenter.setScrollTop(0)
        expect(presenter.state.scrollingVertically).toBe true
        expect(presenter.state.mousewheelScreenRow).toBe 3

        presenter.setMousewheelScreenRow(5)
        expect(presenter.state.scrollingVertically).toBe true
        expect(presenter.state.mousewheelScreenRow).toBe 5

        advanceClock(100)
        expect(presenter.state.scrollingVertically).toBe true
        expect(presenter.state.mousewheelScreenRow).toBe 5

        # should wait 200ms after the last scroll to clear
        presenter.setScrollTop(10)

        advanceClock(100) # so not yet...
        expect(presenter.state.scrollingVertically).toBe true
        expect(presenter.state.mousewheelScreenRow).toBe 5

        expectStateUpdate presenter, -> advanceClock(100) # clear now
        expect(presenter.state.scrollingVertically).toBe false
        expect(presenter.state.mousewheelScreenRow).toBeNull()

        # should be cleared even when we scroll again
        expectStateUpdate presenter, -> presenter.setScrollTop(20)
        expect(presenter.state.scrollingVertically).toBe true
        expect(presenter.state.mousewheelScreenRow).toBeNull()

    describe ".content", ->
      describe ".scrollWidth", ->
        it "is initialized as the max of the clientWidth and the width of the longest line", ->
          maxLineLength = editor.getMaxScreenLineLength()

          presenter = new TextEditorPresenter(model: editor, clientWidth: 50, baseCharacterWidth: 10)
          expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 1

          presenter = new TextEditorPresenter(model: editor, clientWidth: 10 * maxLineLength + 20, baseCharacterWidth: 10)
          expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 20

        it "updates when the ::clientWidth changes", ->
          maxLineLength = editor.getMaxScreenLineLength()
          presenter = new TextEditorPresenter(model: editor, clientWidth: 50, baseCharacterWidth: 10)

          expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 1
          expectStateUpdate presenter, -> presenter.setClientWidth(10 * maxLineLength + 20)
          expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 20

        it "updates when the ::baseCharacterWidth changes", ->
          maxLineLength = editor.getMaxScreenLineLength()
          presenter = new TextEditorPresenter(model: editor, clientWidth: 50, baseCharacterWidth: 10)

          expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 1
          expectStateUpdate presenter, -> presenter.setBaseCharacterWidth(15)
          expect(presenter.state.content.scrollWidth).toBe 15 * maxLineLength + 1

        it "updates when the scoped character widths change", ->
          waitsForPromise -> atom.packages.activatePackage('language-javascript')

          runs ->
            maxLineLength = editor.getMaxScreenLineLength()
            presenter = new TextEditorPresenter(model: editor, clientWidth: 50, baseCharacterWidth: 10)

            expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 1
            expectStateUpdate presenter, -> presenter.setScopedCharWidth(['source.js', 'support.function.js'], 'p', 20)
            expect(presenter.state.content.scrollWidth).toBe (10 * (maxLineLength - 2)) + (20 * 2) + 1 # 2 of the characters are 20px wide now instead of 10px wide

        it "updates when ::softWrapped changes on the editor", ->
          presenter = new TextEditorPresenter(model: editor, clientWidth: 50, baseCharacterWidth: 10)
          expect(presenter.state.content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1
          expectStateUpdate presenter, -> editor.setSoftWrapped(true)
          expect(presenter.state.content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength()
          expectStateUpdate presenter, -> editor.setSoftWrapped(false)
          expect(presenter.state.content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

      describe ".scrollLeft", ->
        it "tracks the value of ::scrollLeft", ->
          presenter = new TextEditorPresenter(model: editor, scrollLeft: 10, lineHeight: 10, lineOverdrawMargin: 1)
          expect(presenter.state.content.scrollLeft).toBe 10
          expectStateUpdate presenter, -> presenter.setScrollLeft(50)
          expect(presenter.state.content.scrollLeft).toBe 50

      describe ".indentGuidesVisible", ->
        it "is initialized based on the editor.showIndentGuide config setting", ->
          presenter = new TextEditorPresenter(model: editor)
          expect(presenter.state.content.indentGuidesVisible).toBe false

          atom.config.set('editor.showIndentGuide', true)
          presenter = new TextEditorPresenter(model: editor)
          expect(presenter.state.content.indentGuidesVisible).toBe true

        it "updates when the editor.showIndentGuide config setting changes", ->
          presenter = new TextEditorPresenter(model: editor)
          expect(presenter.state.content.indentGuidesVisible).toBe false

          expectStateUpdate presenter, -> atom.config.set('editor.showIndentGuide', true)
          expect(presenter.state.content.indentGuidesVisible).toBe true

          expectStateUpdate presenter, -> atom.config.set('editor.showIndentGuide', false)
          expect(presenter.state.content.indentGuidesVisible).toBe false

        it "updates when the editor's grammar changes", ->
          atom.config.set('editor.showIndentGuide', true, scopeSelector: ".source.js")

          presenter = new TextEditorPresenter(model: editor)
          expect(presenter.state.content.indentGuidesVisible).toBe false

          stateUpdated = false
          presenter.onDidUpdateState -> stateUpdated = true

          waitsForPromise -> atom.packages.activatePackage('language-javascript')

          runs ->
            expect(stateUpdated).toBe true
            expect(presenter.state.content.indentGuidesVisible).toBe true

            expectStateUpdate presenter, -> editor.setGrammar(atom.grammars.selectGrammar('.txt'))
            expect(presenter.state.content.indentGuidesVisible).toBe false

        it "is always false when the editor is mini", ->
          atom.config.set('editor.showIndentGuide', true)
          editor.setMini(true)
          presenter = new TextEditorPresenter(model: editor)
          expect(presenter.state.content.indentGuidesVisible).toBe false
          editor.setMini(false)
          expect(presenter.state.content.indentGuidesVisible).toBe true
          editor.setMini(true)
          expect(presenter.state.content.indentGuidesVisible).toBe false

      describe ".backgroundColor", ->
        it "is assigned to ::backgroundColor unless the editor is mini", ->
          presenter = new TextEditorPresenter(model: editor, backgroundColor: 'rgba(255, 0, 0, 0)')
          expect(presenter.state.content.backgroundColor).toBe 'rgba(255, 0, 0, 0)'
          editor.setMini(true)
          presenter = new TextEditorPresenter(model: editor, backgroundColor: 'rgba(255, 0, 0, 0)')
          expect(presenter.state.content.backgroundColor).toBeNull()

        it "updates when ::backgroundColor changes", ->
          presenter = new TextEditorPresenter(model: editor, backgroundColor: 'rgba(255, 0, 0, 0)')
          expect(presenter.state.content.backgroundColor).toBe 'rgba(255, 0, 0, 0)'
          expectStateUpdate presenter, -> presenter.setBackgroundColor('rgba(0, 0, 255, 0)')
          expect(presenter.state.content.backgroundColor).toBe 'rgba(0, 0, 255, 0)'

        it "updates when ::mini changes", ->
          presenter = new TextEditorPresenter(model: editor, backgroundColor: 'rgba(255, 0, 0, 0)')
          expect(presenter.state.content.backgroundColor).toBe 'rgba(255, 0, 0, 0)'
          expectStateUpdate presenter, -> editor.setMini(true)
          expect(presenter.state.content.backgroundColor).toBeNull()

      describe ".placeholderText", ->
        it "is present when the editor has no text", ->
          editor.setPlaceholderText("the-placeholder-text")
          presenter = new TextEditorPresenter(model: editor)
          expect(presenter.state.content.placeholderText).toBeNull()

          expectStateUpdate presenter, -> editor.setText("")
          expect(presenter.state.content.placeholderText).toBe "the-placeholder-text"

          expectStateUpdate presenter, -> editor.setPlaceholderText("new-placeholder-text")
          expect(presenter.state.content.placeholderText).toBe "new-placeholder-text"

      describe ".lines", ->
        lineStateForScreenRow = (presenter, screenRow) ->
          presenter.state.content.lines[presenter.model.tokenizedLineForScreenRow(screenRow).id]

        it "contains states for lines that are visible on screen, plus and minus the overdraw margin", ->
          presenter = new TextEditorPresenter(model: editor, clientHeight: 15, scrollTop: 50, lineHeight: 10, lineOverdrawMargin: 1)

          expect(lineStateForScreenRow(presenter, 3)).toBeUndefined()

          line4 = editor.tokenizedLineForScreenRow(4)
          expectValues lineStateForScreenRow(presenter, 4), {
            screenRow: 4
            text: line4.text
            tokens: line4.tokens
            top: 10 * 4
          }

          line5 = editor.tokenizedLineForScreenRow(5)
          expectValues lineStateForScreenRow(presenter, 5), {
            screenRow: 5
            text: line5.text
            tokens: line5.tokens
            top: 10 * 5
          }

          line6 = editor.tokenizedLineForScreenRow(6)
          expectValues lineStateForScreenRow(presenter, 6), {
            screenRow: 6
            text: line6.text
            tokens: line6.tokens
            top: 10 * 6
          }

          line7 = editor.tokenizedLineForScreenRow(7)
          expectValues lineStateForScreenRow(presenter, 7), {
            screenRow: 7
            text: line7.text
            tokens: line7.tokens
            top: 10 * 7
          }

          line8 = editor.tokenizedLineForScreenRow(8)
          expectValues lineStateForScreenRow(presenter, 8), {
            screenRow: 8
            text: line8.text
            tokens: line8.tokens
            top: 10 * 8
          }

          expect(lineStateForScreenRow(presenter, 9)).toBeUndefined()

        it "does not overdraw above the first row", ->
          presenter = new TextEditorPresenter(model: editor, clientHeight: 15, scrollTop: 10, lineHeight: 10, lineOverdrawMargin: 2)
          expect(lineStateForScreenRow(presenter, 0)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 1)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 2)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 3)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 4)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 5)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 6)).toBeUndefined()

        it "does not overdraw below the last row", ->
          presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 105, lineHeight: 10, lineOverdrawMargin: 2)
          expect(lineStateForScreenRow(presenter, 7)).toBeUndefined()
          expect(lineStateForScreenRow(presenter, 8)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 9)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 10)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 11)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 12)).toBeDefined()

        it "includes state for all lines if no external ::clientHeight is assigned", ->
          presenter = new TextEditorPresenter(model: editor, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1)
          expect(lineStateForScreenRow(presenter, 0)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 12)).toBeDefined()

        it "is empty until all of the required measurements are assigned", ->
          presenter = new TextEditorPresenter(model: editor, lineOverdrawMargin: 1, baseCharacterWidth: 10)
          expect(presenter.state.content.lines).toEqual({})

          presenter.setClientHeight(25)
          expect(presenter.state.content.lines).toEqual({})

          presenter.setLineHeight(10)
          expect(presenter.state.content.lines).toEqual({})

          presenter.setScrollTop(0)
          expect(presenter.state.content.lines).not.toEqual({})

        it "updates when ::scrollTop changes", ->
          presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1)

          expect(lineStateForScreenRow(presenter, 0)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 4)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 5)).toBeUndefined()

          expectStateUpdate presenter, -> presenter.setScrollTop(25)

          expect(lineStateForScreenRow(presenter, 0)).toBeUndefined()
          expect(lineStateForScreenRow(presenter, 1)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 6)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 7)).toBeUndefined()

        it "updates when ::clientHeight changes", ->
          presenter = new TextEditorPresenter(model: editor, clientHeight: 15, scrollTop: 15, lineHeight: 10, lineOverdrawMargin: 1)

          line5 = editor.tokenizedLineForScreenRow(5)

          expect(lineStateForScreenRow(presenter, 4)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 5)).toBeUndefined()

          expectStateUpdate presenter, -> presenter.setClientHeight(35)

          expect(lineStateForScreenRow(presenter, 5)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 6)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 7)).toBeUndefined()

        it "updates when ::lineHeight changes", ->
          presenter = new TextEditorPresenter(model: editor, clientHeight: 15, scrollTop: 10, lineHeight: 10, lineOverdrawMargin: 0)

          expect(lineStateForScreenRow(presenter, 0)).toBeUndefined()
          expect(lineStateForScreenRow(presenter, 1)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 2)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 4)).toBeUndefined()

          expectStateUpdate presenter, -> presenter.setLineHeight(5)

          expect(lineStateForScreenRow(presenter, 0)).toBeUndefined()
          expect(lineStateForScreenRow(presenter, 1)).toBeUndefined()
          expect(lineStateForScreenRow(presenter, 2)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 5)).toBeDefined()
          expect(lineStateForScreenRow(presenter, 6)).toBeUndefined()

        it "updates when the editor's content changes", ->
          presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 10, lineHeight: 10, lineOverdrawMargin: 0)

          expectStateUpdate presenter, -> buffer.insert([2, 0], "hello\nworld\n")

          line1 = editor.tokenizedLineForScreenRow(1)
          expectValues lineStateForScreenRow(presenter, 1), {
            text: line1.text
            tokens: line1.tokens
          }

          line2 = editor.tokenizedLineForScreenRow(2)
          expectValues lineStateForScreenRow(presenter, 2), {
            text: line2.text
            tokens: line2.tokens
          }

          line3 = editor.tokenizedLineForScreenRow(3)
          expectValues lineStateForScreenRow(presenter, 3), {
            text: line3.text
            tokens: line3.tokens
          }

        describe "[lineId]", -> # line state objects
          it "includes the .endOfLineInvisibles if the editor.showInvisibles config option is true", ->
            editor.setText("hello\nworld\r\n")
            presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
            expect(lineStateForScreenRow(presenter, 0).endOfLineInvisibles).toBeNull()
            expect(lineStateForScreenRow(presenter, 1).endOfLineInvisibles).toBeNull()

            atom.config.set('editor.showInvisibles', true)
            presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
            expect(lineStateForScreenRow(presenter, 0).endOfLineInvisibles).toEqual [atom.config.get('editor.invisibles.eol')]
            expect(lineStateForScreenRow(presenter, 1).endOfLineInvisibles).toEqual [atom.config.get('editor.invisibles.cr'), atom.config.get('editor.invisibles.eol')]

          describe ".decorationClasses", ->
            it "adds decoration classes to the relevant line state objects, both initially and when decorations change", ->
              marker1 = editor.markBufferRange([[4, 0], [6, 2]], invalidate: 'touch')
              decoration1 = editor.decorateMarker(marker1, type: 'line', class: 'a')
              presenter = new TextEditorPresenter(model: editor, clientHeight: 130, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
              marker2 = editor.markBufferRange([[4, 0], [6, 2]], invalidate: 'touch')
              decoration2 = editor.decorateMarker(marker2, type: 'line', class: 'b')

              expect(lineStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a', 'b']
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a', 'b']
              expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

              expectStateUpdate presenter, -> editor.getBuffer().insert([5, 0], 'x')
              expect(marker1.isValid()).toBe false
              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

              expectStateUpdate presenter, -> editor.undo()
              expect(lineStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a', 'b']
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a', 'b']
              expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

              expectStateUpdate presenter, -> marker1.setBufferRange([[2, 0], [4, 2]])
              expect(lineStateForScreenRow(presenter, 1).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 2).decorationClasses).toEqual ['a']
              expect(lineStateForScreenRow(presenter, 3).decorationClasses).toEqual ['a']
              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['b']
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['b']
              expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

              expectStateUpdate presenter, -> decoration1.destroy()
              expect(lineStateForScreenRow(presenter, 2).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['b']
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['b']
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['b']
              expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

              expectStateUpdate presenter, -> marker2.destroy()
              expect(lineStateForScreenRow(presenter, 2).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

            it "honors the 'onlyEmpty' option on line decorations", ->
              presenter = new TextEditorPresenter(model: editor, clientHeight: 130, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
              marker = editor.markBufferRange([[4, 0], [6, 1]])
              decoration = editor.decorateMarker(marker, type: 'line', class: 'a', onlyEmpty: true)

              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

              expectStateUpdate presenter, -> marker.clearTail()

              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

            it "honors the 'onlyNonEmpty' option on line decorations", ->
              presenter = new TextEditorPresenter(model: editor, clientHeight: 130, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
              marker = editor.markBufferRange([[4, 0], [6, 2]])
              decoration = editor.decorateMarker(marker, type: 'line', class: 'a', onlyNonEmpty: true)

              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a']
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a']
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

              expectStateUpdate presenter, -> marker.clearTail()

              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

            it "honors the 'onlyHead' option on line decorations", ->
              presenter = new TextEditorPresenter(model: editor, clientHeight: 130, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
              marker = editor.markBufferRange([[4, 0], [6, 2]])
              decoration = editor.decorateMarker(marker, type: 'line', class: 'a', onlyHead: true)

              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

            it "does not decorate the last line of a non-empty line decoration range if it ends at column 0", ->
              presenter = new TextEditorPresenter(model: editor, clientHeight: 130, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
              marker = editor.markBufferRange([[4, 0], [6, 0]])
              decoration = editor.decorateMarker(marker, type: 'line', class: 'a')

              expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a']
              expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a']
              expect(lineStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

            it "does not apply line decorations to mini editors", ->
              editor.setMini(true)
              presenter = new TextEditorPresenter(model: editor, clientHeight: 10, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
              marker = editor.markBufferRange([[0, 0], [0, 0]])
              decoration = editor.decorateMarker(marker, type: 'line', class: 'a')
              expect(lineStateForScreenRow(presenter, 0).decorationClasses).toBeNull()

              expectStateUpdate presenter, -> editor.setMini(false)
              expect(lineStateForScreenRow(presenter, 0).decorationClasses).toEqual ['cursor-line', 'a']

              expectStateUpdate presenter, -> editor.setMini(true)
              expect(lineStateForScreenRow(presenter, 0).decorationClasses).toBeNull()

            it "only applies decorations to screen rows that are spanned by their marker when lines are soft-wrapped", ->
              editor.setText("a line that wraps, ok")
              editor.setSoftWrapped(true)
              editor.setEditorWidthInChars(16)
              marker = editor.markBufferRange([[0, 0], [0, 2]])
              editor.decorateMarker(marker, type: 'line', class: 'a')
              presenter = new TextEditorPresenter(model: editor, clientHeight: 10, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)

              expect(lineStateForScreenRow(presenter, 0).decorationClasses).toContain 'a'
              expect(lineStateForScreenRow(presenter, 1).decorationClasses).toBeNull()

              marker.setBufferRange([[0, 0], [0, Infinity]])
              expect(lineStateForScreenRow(presenter, 0).decorationClasses).toContain 'a'
              expect(lineStateForScreenRow(presenter, 1).decorationClasses).toContain 'a'

      describe ".cursors", ->
        stateForCursor = (presenter, cursorIndex) ->
          presenter.state.content.cursors[presenter.model.getCursors()[cursorIndex].id]

        it "contains pixelRects for empty selections that are visible on screen", ->
          editor.setSelectedBufferRanges([
            [[1, 2], [1, 2]],
            [[2, 4], [2, 4]],
            [[3, 4], [3, 5]]
            [[5, 12], [5, 12]],
            [[8, 4], [8, 4]]
          ])
          presenter = new TextEditorPresenter(model: editor, clientHeight: 30, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expect(stateForCursor(presenter, 0)).toBeUndefined()
          expect(stateForCursor(presenter, 1)).toEqual {top: 2 * 10, left: 4 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 2)).toBeUndefined()
          expect(stateForCursor(presenter, 3)).toEqual {top: 5 * 10, left: 12 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 4)).toBeUndefined()

        it "is empty until all of the required measurements are assigned", ->
          presenter = new TextEditorPresenter(model: editor, lineOverdrawMargin: 1)
          expect(presenter.state.content.cursors).toEqual({})

          presenter.setClientHeight(25)
          expect(presenter.state.content.cursors).toEqual({})

          presenter.setLineHeight(10)
          expect(presenter.state.content.cursors).toEqual({})

          presenter.setScrollTop(0)
          expect(presenter.state.content.cursors).toEqual({})

          presenter.setBaseCharacterWidth(8)
          expect(presenter.state.content.cursors).not.toEqual({})

        it "updates when ::scrollTop changes", ->
          editor.setSelectedBufferRanges([
            [[1, 2], [1, 2]],
            [[2, 4], [2, 4]],
            [[3, 4], [3, 5]]
            [[5, 12], [5, 12]],
            [[8, 4], [8, 4]]
          ])
          presenter = new TextEditorPresenter(model: editor, clientHeight: 30, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expectStateUpdate presenter, -> presenter.setScrollTop(5 * 10)
          expect(stateForCursor(presenter, 0)).toBeUndefined()
          expect(stateForCursor(presenter, 1)).toBeUndefined()
          expect(stateForCursor(presenter, 2)).toBeUndefined()
          expect(stateForCursor(presenter, 3)).toEqual {top: 5 * 10, left: 12 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 4)).toEqual {top: 8 * 10, left: 4 * 10, width: 10, height: 10}

        it "updates when ::clientHeight changes", ->
          editor.setSelectedBufferRanges([
            [[1, 2], [1, 2]],
            [[2, 4], [2, 4]],
            [[3, 4], [3, 5]]
            [[5, 12], [5, 12]],
            [[8, 4], [8, 4]]
          ])
          presenter = new TextEditorPresenter(model: editor, clientHeight: 20, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expectStateUpdate presenter, -> presenter.setClientHeight(30)
          expect(stateForCursor(presenter, 0)).toBeUndefined()
          expect(stateForCursor(presenter, 1)).toEqual {top: 2 * 10, left: 4 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 2)).toBeUndefined()
          expect(stateForCursor(presenter, 3)).toEqual {top: 5 * 10, left: 12 * 10, width: 10, height: 10}
          expect(stateForCursor(presenter, 4)).toBeUndefined()

        it "updates when ::lineHeight changes", ->
          editor.setSelectedBufferRanges([
            [[1, 2], [1, 2]],
            [[2, 4], [2, 4]],
            [[3, 4], [3, 5]]
            [[5, 12], [5, 12]],
            [[8, 4], [8, 4]]
          ])
          presenter = new TextEditorPresenter(model: editor, clientHeight: 20, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expectStateUpdate presenter, -> presenter.setLineHeight(5)
          expect(stateForCursor(presenter, 0)).toBeUndefined()
          expect(stateForCursor(presenter, 1)).toBeUndefined()
          expect(stateForCursor(presenter, 2)).toBeUndefined()
          expect(stateForCursor(presenter, 3)).toEqual {top: 5 * 5, left: 12 * 10, width: 10, height: 5}
          expect(stateForCursor(presenter, 4)).toEqual {top: 8 * 5, left: 4 * 10, width: 10, height: 5}

        it "updates when ::baseCharacterWidth changes", ->
          editor.setCursorBufferPosition([2, 4])
          presenter = new TextEditorPresenter(model: editor, clientHeight: 20, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expectStateUpdate presenter, -> presenter.setBaseCharacterWidth(20)
          expect(stateForCursor(presenter, 0)).toEqual {top: 2 * 10, left: 4 * 20, width: 20, height: 10}

        it "updates when scoped character widths change", ->
          waitsForPromise ->
            atom.packages.activatePackage('language-javascript')

          runs ->
            editor.setCursorBufferPosition([1, 4])
            presenter = new TextEditorPresenter(model: editor, clientHeight: 20, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

            expectStateUpdate presenter, -> presenter.setScopedCharWidth(['source.js', 'storage.modifier.js'], 'v', 20)
            expect(stateForCursor(presenter, 0)).toEqual {top: 1 * 10, left: (3 * 10) + 20, width: 10, height: 10}

            expectStateUpdate presenter, -> presenter.setScopedCharWidth(['source.js', 'storage.modifier.js'], 'r', 20)
            expect(stateForCursor(presenter, 0)).toEqual {top: 1 * 10, left: (3 * 10) + 20, width: 20, height: 10}

        it "updates when cursors are added, moved, hidden, shown, or destroyed", ->
          editor.setSelectedBufferRanges([
            [[1, 2], [1, 2]],
            [[3, 4], [3, 5]]
          ])
          presenter = new TextEditorPresenter(model: editor, clientHeight: 20, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          # moving into view
          expect(stateForCursor(presenter, 0)).toBeUndefined()
          editor.getCursors()[0].setBufferPosition([2, 4])
          expect(stateForCursor(presenter, 0)).toEqual {top: 2 * 10, left: 4 * 10, width: 10, height: 10}

          # showing
          expectStateUpdate presenter, -> editor.getSelections()[1].clear()
          expect(stateForCursor(presenter, 1)).toEqual {top: 3 * 10, left: 5 * 10, width: 10, height: 10}

          # hiding
          expectStateUpdate presenter, -> editor.getSelections()[1].setBufferRange([[3, 4], [3, 5]])
          expect(stateForCursor(presenter, 1)).toBeUndefined()

          # moving out of view
          expectStateUpdate presenter, -> editor.getCursors()[0].setBufferPosition([10, 4])
          expect(stateForCursor(presenter, 0)).toBeUndefined()

          # adding
          expectStateUpdate presenter, -> editor.addCursorAtBufferPosition([4, 4])
          expect(stateForCursor(presenter, 2)).toEqual {top: 4 * 10, left: 4 * 10, width: 10, height: 10}

          # moving added cursor
          expectStateUpdate presenter, -> editor.getCursors()[2].setBufferPosition([4, 6])
          expect(stateForCursor(presenter, 2)).toEqual {top: 4 * 10, left: 6 * 10, width: 10, height: 10}

          # destroying
          destroyedCursor = editor.getCursors()[2]
          expectStateUpdate presenter, -> destroyedCursor.destroy()
          expect(presenter.state.content.cursors[destroyedCursor.id]).toBeUndefined()

        it "makes cursors as wide as the ::baseCharacterWidth if they're at the end of a line", ->
          editor.setCursorBufferPosition([1, Infinity])
          presenter = new TextEditorPresenter(model: editor, clientHeight: 20, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)
          expect(stateForCursor(presenter, 0).width).toBe 10

      describe ".blinkCursorsOff", ->
        it "alternates between true and false twice per ::cursorBlinkPeriod", ->
          cursorBlinkPeriod = 100
          cursorBlinkResumeDelay = 200
          presenter = new TextEditorPresenter({model: editor, cursorBlinkPeriod, cursorBlinkResumeDelay})

          expect(presenter.state.content.blinkCursorsOff).toBe false
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.state.content.blinkCursorsOff).toBe true
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.state.content.blinkCursorsOff).toBe false
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.state.content.blinkCursorsOff).toBe true

        it "stops alternating for ::cursorBlinkResumeDelay when a cursor moves or a cursor is added", ->
          cursorBlinkPeriod = 100
          cursorBlinkResumeDelay = 200
          presenter = new TextEditorPresenter({model: editor, cursorBlinkPeriod, cursorBlinkResumeDelay})

          expect(presenter.state.content.blinkCursorsOff).toBe false
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.state.content.blinkCursorsOff).toBe true

          expectStateUpdate presenter, -> editor.moveRight()
          expect(presenter.state.content.blinkCursorsOff).toBe false

          expectStateUpdate presenter, ->
            advanceClock(cursorBlinkResumeDelay)
            advanceClock(cursorBlinkPeriod / 2)

          expect(presenter.state.content.blinkCursorsOff).toBe true
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.state.content.blinkCursorsOff).toBe false
          expectStateUpdate presenter, -> advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.state.content.blinkCursorsOff).toBe true

          expectStateUpdate presenter, -> editor.addCursorAtBufferPosition([1, 0])
          expect(presenter.state.content.blinkCursorsOff).toBe false

          expectStateUpdate presenter, ->
            advanceClock(cursorBlinkResumeDelay)
            advanceClock(cursorBlinkPeriod / 2)
          expect(presenter.state.content.blinkCursorsOff).toBe true

      describe ".highlights", ->
        stateForHighlight = (presenter, decoration) ->
          presenter.state.content.highlights[decoration.id]

        stateForSelection = (presenter, selectionIndex) ->
          selection = presenter.model.getSelections()[selectionIndex]
          stateForHighlight(presenter, selection.decoration)

        it "contains states for highlights that are visible on screen", ->
          # off-screen above
          marker1 = editor.markBufferRange([[0, 0], [1, 0]])
          highlight1 = editor.decorateMarker(marker1, type: 'highlight', class: 'a')

          # partially off-screen above, 1 of 2 regions on screen
          marker2 = editor.markBufferRange([[1, 6], [2, 6]])
          highlight2 = editor.decorateMarker(marker2, type: 'highlight', class: 'b')

          # partially off-screen above, 2 of 3 regions on screen
          marker3 = editor.markBufferRange([[0, 6], [3, 6]])
          highlight3 = editor.decorateMarker(marker3, type: 'highlight', class: 'c')

          # on-screen
          marker4 = editor.markBufferRange([[2, 6], [4, 6]])
          highlight4 = editor.decorateMarker(marker4, type: 'highlight', class: 'd')

          # partially off-screen below, 2 of 3 regions on screen
          marker5 = editor.markBufferRange([[3, 6], [6, 6]])
          highlight5 = editor.decorateMarker(marker5, type: 'highlight', class: 'e')

          # partially off-screen below, 1 of 3 regions on screen
          marker6 = editor.markBufferRange([[5, 6], [7, 6]])
          highlight6 = editor.decorateMarker(marker6, type: 'highlight', class: 'f')

          # off-screen below
          marker7 = editor.markBufferRange([[6, 6], [7, 6]])
          highlight7 = editor.decorateMarker(marker7, type: 'highlight', class: 'g')

          # on-screen, empty
          marker8 = editor.markBufferRange([[2, 2], [2, 2]])
          highlight8 = editor.decorateMarker(marker8, type: 'highlight', class: 'h')

          presenter = new TextEditorPresenter(model: editor, clientHeight: 30, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expect(stateForHighlight(presenter, highlight1)).toBeUndefined()

          expectValues stateForHighlight(presenter, highlight2), {
            class: 'b'
            regions: [
              {top: 2 * 10, left: 0 * 10, width: 6 * 10, height: 1 * 10}
            ]
          }

          expectValues stateForHighlight(presenter, highlight3), {
            class: 'c'
            regions: [
              {top: 2 * 10, left: 0 * 10, right: 0, height: 1 * 10}
              {top: 3 * 10, left: 0 * 10, width: 6 * 10, height: 1 * 10}
            ]
          }

          expectValues stateForHighlight(presenter, highlight4), {
            class: 'd'
            regions: [
              {top: 2 * 10, left: 6 * 10, right: 0, height: 1 * 10}
              {top: 3 * 10, left: 0, right: 0, height: 1 * 10}
              {top: 4 * 10, left: 0, width: 6 * 10, height: 1 * 10}
            ]
          }

          expectValues stateForHighlight(presenter, highlight5), {
            class: 'e'
            regions: [
              {top: 3 * 10, left: 6 * 10, right: 0, height: 1 * 10}
              {top: 4 * 10, left: 0 * 10, right: 0, height: 2 * 10}
            ]
          }

          expectValues stateForHighlight(presenter, highlight6), {
            class: 'f'
            regions: [
              {top: 5 * 10, left: 6 * 10, right: 0, height: 1 * 10}
            ]
          }

          expect(stateForHighlight(presenter, highlight7)).toBeUndefined()
          expect(stateForHighlight(presenter, highlight8)).toBeUndefined()

        it "is empty until all of the required measurements are assigned", ->
          editor.setSelectedBufferRanges([
            [[0, 2], [2, 4]],
          ])

          presenter = new TextEditorPresenter(model: editor, lineOverdrawMargin: 1)
          expect(presenter.state.content.highlights).toEqual({})

          presenter.setClientHeight(25)
          expect(presenter.state.content.highlights).toEqual({})

          presenter.setLineHeight(10)
          expect(presenter.state.content.highlights).toEqual({})

          presenter.setScrollTop(0)
          expect(presenter.state.content.highlights).toEqual({})

          presenter.setBaseCharacterWidth(8)
          expect(presenter.state.content.highlights).not.toEqual({})

        it "does not include highlights for invalid markers", ->
          marker = editor.markBufferRange([[2, 2], [2, 4]], invalidate: 'touch')
          highlight = editor.decorateMarker(marker, type: 'highlight', class: 'h')

          presenter = new TextEditorPresenter(model: editor, clientHeight: 30, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expect(stateForHighlight(presenter, highlight)).toBeDefined()
          expectStateUpdate presenter, -> editor.getBuffer().insert([2, 2], "stuff")
          expect(stateForHighlight(presenter, highlight)).toBeUndefined()

        it "updates when ::scrollTop changes", ->
          editor.setSelectedBufferRanges([
            [[6, 2], [6, 4]],
          ])

          presenter = new TextEditorPresenter(model: editor, clientHeight: 30, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expect(stateForSelection(presenter, 0)).toBeUndefined()
          expectStateUpdate presenter, -> presenter.setScrollTop(5 * 10)
          expect(stateForSelection(presenter, 0)).toBeDefined()
          expectStateUpdate presenter, -> presenter.setScrollTop(2 * 10)
          expect(stateForSelection(presenter, 0)).toBeUndefined()

        it "updates when ::clientHeight changes", ->
          editor.setSelectedBufferRanges([
            [[6, 2], [6, 4]],
          ])

          presenter = new TextEditorPresenter(model: editor, clientHeight: 20, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expect(stateForSelection(presenter, 0)).toBeUndefined()
          expectStateUpdate presenter, -> presenter.setClientHeight(60)
          expect(stateForSelection(presenter, 0)).toBeDefined()
          expectStateUpdate presenter, -> presenter.setClientHeight(20)
          expect(stateForSelection(presenter, 0)).toBeUndefined()

        it "updates when ::lineHeight changes", ->
          editor.setSelectedBufferRanges([
            [[2, 2], [2, 4]],
            [[3, 4], [3, 6]],
          ])

          presenter = new TextEditorPresenter(model: editor, clientHeight: 20, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expectValues stateForSelection(presenter, 0), {
            regions: [
              {top: 2 * 10, left: 2 * 10, width: 2 * 10, height: 10}
            ]
          }
          expect(stateForSelection(presenter, 1)).toBeUndefined()

          expectStateUpdate presenter, -> presenter.setLineHeight(5)

          expectValues stateForSelection(presenter, 0), {
            regions: [
              {top: 2 * 5, left: 2 * 10, width: 2 * 10, height: 5}
            ]
          }

          expectValues stateForSelection(presenter, 1), {
            regions: [
              {top: 3 * 5, left: 4 * 10, width: 2 * 10, height: 5}
            ]
          }

        it "updates when ::baseCharacterWidth changes", ->
          editor.setSelectedBufferRanges([
            [[2, 2], [2, 4]],
          ])

          presenter = new TextEditorPresenter(model: editor, clientHeight: 20, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expectValues stateForSelection(presenter, 0), {
            regions: [{top: 2 * 10, left: 2 * 10, width: 2 * 10, height: 10}]
          }
          expectStateUpdate presenter, -> presenter.setBaseCharacterWidth(20)
          expectValues stateForSelection(presenter, 0), {
            regions: [{top: 2 * 10, left: 2 * 20, width: 2 * 20, height: 10}]
          }

        it "updates when scoped character widths change", ->
          waitsForPromise ->
            atom.packages.activatePackage('language-javascript')

          runs ->
            editor.setSelectedBufferRanges([
              [[2, 4], [2, 6]],
            ])

            presenter = new TextEditorPresenter(model: editor, clientHeight: 20, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

            expectValues stateForSelection(presenter, 0), {
              regions: [{top: 2 * 10, left: 4 * 10, width: 2 * 10, height: 10}]
            }
            expectStateUpdate presenter, -> presenter.setScopedCharWidth(['source.js', 'keyword.control.js'], 'i', 20)
            expectValues stateForSelection(presenter, 0), {
              regions: [{top: 2 * 10, left: 4 * 10, width: 20 + 10, height: 10}]
            }

        it "updates when highlight decorations are added, moved, hidden, shown, or destroyed", ->
          editor.setSelectedBufferRanges([
            [[1, 2], [1, 4]],
            [[3, 4], [3, 6]]
          ])
          presenter = new TextEditorPresenter(model: editor, clientHeight: 20, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expectValues stateForSelection(presenter, 0), {
            regions: [{top: 1 * 10, left: 2 * 10, width: 2 * 10, height: 10}]
          }
          expect(stateForSelection(presenter, 1)).toBeUndefined()

          # moving into view
          expectStateUpdate presenter, -> editor.getSelections()[1].setBufferRange([[2, 4], [2, 6]])
          expectValues stateForSelection(presenter, 1), {
            regions: [{top: 2 * 10, left: 4 * 10, width: 2 * 10, height: 10}]
          }

          # becoming empty
          expectStateUpdate presenter, -> editor.getSelections()[1].clear()
          expect(stateForSelection(presenter, 1)).toBeUndefined()

          # becoming non-empty
          expectStateUpdate presenter, -> editor.getSelections()[1].setBufferRange([[2, 4], [2, 6]])
          expectValues stateForSelection(presenter, 1), {
            regions: [{top: 2 * 10, left: 4 * 10, width: 2 * 10, height: 10}]
          }

          # moving out of view
          expectStateUpdate presenter, -> editor.getSelections()[1].setBufferRange([[3, 4], [3, 6]])
          expect(stateForSelection(presenter, 1)).toBeUndefined()

          # adding
          expectStateUpdate presenter, -> editor.addSelectionForBufferRange([[1, 4], [1, 6]])
          expectValues stateForSelection(presenter, 2), {
            regions: [{top: 1 * 10, left: 4 * 10, width: 2 * 10, height: 10}]
          }

          # moving added selection
          expectStateUpdate presenter, -> editor.getSelections()[2].setBufferRange([[1, 4], [1, 8]])
          expectValues stateForSelection(presenter, 2), {
            regions: [{top: 1 * 10, left: 4 * 10, width: 4 * 10, height: 10}]
          }

          # destroying
          destroyedSelection = editor.getSelections()[2]
          expectStateUpdate presenter, -> destroyedSelection.destroy()
          expect(stateForHighlight(presenter, destroyedSelection.decoration)).toBeUndefined()

        it "updates when highlight decorations' properties are updated", ->
          marker = editor.markBufferRange([[2, 2], [2, 4]])
          highlight = editor.decorateMarker(marker, type: 'highlight', class: 'a')

          presenter = new TextEditorPresenter(model: editor, clientHeight: 30, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expectValues stateForHighlight(presenter, highlight), {class: 'a'}
          expectStateUpdate presenter, -> highlight.setProperties(class: 'b', type: 'highlight')
          expectValues stateForHighlight(presenter, highlight), {class: 'b'}

        it "increments the .flashCount and sets the .flashClass and .flashDuration when the highlight model flashes", ->
          presenter = new TextEditorPresenter(model: editor, clientHeight: 30, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          marker = editor.markBufferRange([[2, 2], [2, 4]])
          highlight = editor.decorateMarker(marker, type: 'highlight', class: 'a')
          expectStateUpdate presenter, -> highlight.flash('b', 500)

          expectValues stateForHighlight(presenter, highlight), {
            flashClass: 'b'
            flashDuration: 500
            flashCount: 1
          }

          expectStateUpdate presenter, -> highlight.flash('c', 600)

          expectValues stateForHighlight(presenter, highlight), {
            flashClass: 'c'
            flashDuration: 600
            flashCount: 2
          }

      describe ".overlays", ->
        stateForOverlay = (presenter, decoration) ->
          presenter.state.content.overlays[decoration.id]

        it "contains state for overlay decorations both initially and when their markers move", ->
          item = {}
          marker = editor.markBufferPosition([2, 13], invalidate: 'touch')
          decoration = editor.decorateMarker(marker, {type: 'overlay', item})
          presenter = new TextEditorPresenter(model: editor, clientHeight: 30, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          # Initial state
          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 2 * 10, left: 13 * 10}
          }

          # Change range
          expectStateUpdate presenter, -> marker.setBufferRange([[2, 13], [4, 6]])
          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 4 * 10, left: 6 * 10}
          }

          # Valid -> invalid
          expectStateUpdate presenter, -> editor.getBuffer().insert([2, 14], 'x')
          expect(stateForOverlay(presenter, decoration)).toBeUndefined()

          # Invalid -> valid
          expectStateUpdate presenter, -> editor.undo()
          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 4 * 10, left: 6 * 10}
          }

          # Reverse direction
          expectStateUpdate presenter, -> marker.setBufferRange([[2, 13], [4, 6]], reversed: true)
          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 2 * 10, left: 13 * 10}
          }

          # Destroy
          decoration.destroy()
          expect(stateForOverlay(presenter, decoration)).toBeUndefined()

          # Add
          decoration2 = editor.decorateMarker(marker, {type: 'overlay', item})
          expectValues stateForOverlay(presenter, decoration2), {
            item: item
            pixelPosition: {top: 2 * 10, left: 13 * 10}
          }

        it "updates when ::baseCharacterWidth changes", ->
          item = {}
          marker = editor.markBufferPosition([2, 13], invalidate: 'touch')
          decoration = editor.decorateMarker(marker, {type: 'overlay', item})
          presenter = new TextEditorPresenter(model: editor, clientHeight: 30, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 2 * 10, left: 13 * 10}
          }

          expectStateUpdate presenter, -> presenter.setBaseCharacterWidth(5)

          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 2 * 10, left: 13 * 5}
          }

        it "updates when ::lineHeight changes", ->
          item = {}
          marker = editor.markBufferPosition([2, 13], invalidate: 'touch')
          decoration = editor.decorateMarker(marker, {type: 'overlay', item})
          presenter = new TextEditorPresenter(model: editor, clientHeight: 30, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)

          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 2 * 10, left: 13 * 10}
          }

          expectStateUpdate presenter, -> presenter.setLineHeight(5)

          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 2 * 5, left: 13 * 10}
          }

        it "honors the 'position' option on overlay decorations", ->
          item = {}
          marker = editor.markBufferRange([[2, 13], [4, 14]], invalidate: 'touch')
          decoration = editor.decorateMarker(marker, {type: 'overlay', position: 'tail', item})
          presenter = new TextEditorPresenter(model: editor, clientHeight: 30, scrollTop: 20, lineHeight: 10, lineOverdrawMargin: 0, baseCharacterWidth: 10)
          expectValues stateForOverlay(presenter, decoration), {
            item: item
            pixelPosition: {top: 2 * 10, left: 13 * 10}
          }

        it "is empty until all of the required measurements are assigned", ->
          item = {}
          marker = editor.markBufferRange([[2, 13], [4, 14]], invalidate: 'touch')
          decoration = editor.decorateMarker(marker, {type: 'overlay', position: 'tail', item})

          presenter = new TextEditorPresenter(model: editor, lineOverdrawMargin: 0, scrollTop: 0, scrollHeight: 50)
          expect(presenter.state.content.overlays).toEqual({})

          presenter.setBaseCharacterWidth(10)
          expect(presenter.state.content.overlays).toEqual({})

          presenter.setLineHeight(10)
          expect(presenter.state.content.overlays).not.toEqual({})

    describe ".gutter", ->
      describe ".backgroundColor", ->
        it "is assigned to ::gutterBackgroundColor if present, and to ::backgroundColor otherwise", ->
          presenter = new TextEditorPresenter(model: editor, backgroundColor: "rgba(255, 0, 0, 0)", gutterBackgroundColor: "rgba(0, 255, 0, 0)")
          expect(presenter.state.gutter.backgroundColor).toBe "rgba(0, 255, 0, 0)"

          expectStateUpdate presenter, -> presenter.setGutterBackgroundColor("rgba(0, 0, 255, 0)")
          expect(presenter.state.gutter.backgroundColor).toBe "rgba(0, 0, 255, 0)"

          expectStateUpdate presenter, -> presenter.setGutterBackgroundColor("rgba(0, 0, 0, 0)")
          expect(presenter.state.gutter.backgroundColor).toBe "rgba(255, 0, 0, 0)"

      describe ".maxLineNumberDigits", ->
        it "is set to the number of digits used by the greatest line number", ->
          presenter = new TextEditorPresenter(model: editor)
          expect(editor.getLastBufferRow()).toBe 12
          expect(presenter.state.gutter.maxLineNumberDigits).toBe 2

          editor.setText("1\n2\n3")
          expect(presenter.state.gutter.maxLineNumberDigits).toBe 1

      describe ".lineNumbers", ->
        lineNumberStateForScreenRow = (presenter, screenRow) ->
          editor = presenter.model
          bufferRow = editor.bufferRowForScreenRow(screenRow)
          wrapCount = screenRow - editor.screenRowForBufferRow(bufferRow)
          if wrapCount > 0
            key = bufferRow + '-' + wrapCount
          else
            key = bufferRow

          presenter.state.gutter.lineNumbers[key]

        it "contains states for line numbers that are visible on screen, plus and minus the overdraw margin", ->
          editor.foldBufferRow(4)
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(50)
          presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 30, lineHeight: 10, lineOverdrawMargin: 1)

          expect(lineNumberStateForScreenRow(presenter, 1)).toBeUndefined()
          expectValues lineNumberStateForScreenRow(presenter, 2), {screenRow: 2, bufferRow: 2, softWrapped: false, top: 2 * 10}
          expectValues lineNumberStateForScreenRow(presenter, 3), {screenRow: 3, bufferRow: 3, softWrapped: false, top: 3 * 10}
          expectValues lineNumberStateForScreenRow(presenter, 4), {screenRow: 4, bufferRow: 3, softWrapped: true, top: 4 * 10}
          expectValues lineNumberStateForScreenRow(presenter, 5), {screenRow: 5, bufferRow: 4, softWrapped: false, top: 5 * 10}
          expectValues lineNumberStateForScreenRow(presenter, 6), {screenRow: 6, bufferRow: 7, softWrapped: false, top: 6 * 10}
          expectValues lineNumberStateForScreenRow(presenter, 7), {screenRow: 7, bufferRow: 8, softWrapped: false, top: 7 * 10}
          expect(lineNumberStateForScreenRow(presenter, 8)).toBeUndefined()

        it "includes states for all line numbers if no external client height is assigned", ->
          presenter = new TextEditorPresenter(model: editor, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1)
          expect(lineNumberStateForScreenRow(presenter, 0)).toBeDefined()
          expect(lineNumberStateForScreenRow(presenter, 12)).toBeDefined()

        it "updates when ::scrollTop changes", ->
          editor.foldBufferRow(4)
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(50)
          presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 30, lineHeight: 10, lineOverdrawMargin: 1)

          expect(lineNumberStateForScreenRow(presenter, 1)).toBeUndefined()
          expectValues lineNumberStateForScreenRow(presenter, 2), {bufferRow: 2}
          expectValues lineNumberStateForScreenRow(presenter, 7), {bufferRow: 8}
          expect(lineNumberStateForScreenRow(presenter, 8)).toBeUndefined()

          expectStateUpdate presenter, -> presenter.setScrollTop(20)

          expect(lineNumberStateForScreenRow(presenter, 0)).toBeUndefined()
          expectValues lineNumberStateForScreenRow(presenter, 1), {bufferRow: 1}
          expectValues lineNumberStateForScreenRow(presenter, 6), {bufferRow: 7}
          expect(lineNumberStateForScreenRow(presenter, 7)).toBeUndefined()

        it "updates when ::clientHeight changes", ->
          editor.foldBufferRow(4)
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(50)
          presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 30, lineHeight: 10, lineOverdrawMargin: 1)

          expect(lineNumberStateForScreenRow(presenter, 1)).toBeUndefined()
          expectValues lineNumberStateForScreenRow(presenter, 2), {bufferRow: 2}
          expectValues lineNumberStateForScreenRow(presenter, 7), {bufferRow: 8}
          expect(lineNumberStateForScreenRow(presenter, 8)).toBeUndefined()

          expectStateUpdate presenter, -> presenter.setClientHeight(35)

          expect(lineNumberStateForScreenRow(presenter, 0)).toBeUndefined()
          expectValues lineNumberStateForScreenRow(presenter, 2), {bufferRow: 2}
          expectValues lineNumberStateForScreenRow(presenter, 8), {bufferRow: 8}
          expect(lineNumberStateForScreenRow(presenter, 9)).toBeUndefined()

        it "updates when ::lineHeight changes", ->
          editor.foldBufferRow(4)
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(50)
          presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)

          expectValues lineNumberStateForScreenRow(presenter, 0), {bufferRow: 0}
          expectValues lineNumberStateForScreenRow(presenter, 3), {bufferRow: 3}
          expect(lineNumberStateForScreenRow(presenter, 4)).toBeUndefined()

          expectStateUpdate presenter, -> presenter.setLineHeight(5)

          expectValues lineNumberStateForScreenRow(presenter, 0), {bufferRow: 0}
          expectValues lineNumberStateForScreenRow(presenter, 5), {bufferRow: 4}
          expect(lineNumberStateForScreenRow(presenter, 6)).toBeUndefined()

        it "updates when the editor's content changes", ->
          editor.foldBufferRow(4)
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(50)
          presenter = new TextEditorPresenter(model: editor, clientHeight: 35, scrollTop: 30, lineHeight: 10, lineOverdrawMargin: 0)

          expect(lineNumberStateForScreenRow(presenter, 2)).toBeUndefined()
          expectValues lineNumberStateForScreenRow(presenter, 3), {bufferRow: 3}
          expectValues lineNumberStateForScreenRow(presenter, 4), {bufferRow: 3}
          expectValues lineNumberStateForScreenRow(presenter, 5), {bufferRow: 4}
          expectValues lineNumberStateForScreenRow(presenter, 6), {bufferRow: 7}
          expectValues lineNumberStateForScreenRow(presenter, 7), {bufferRow: 8}
          expect(lineNumberStateForScreenRow(presenter, 8)).toBeUndefined()

          expectStateUpdate presenter, ->
            editor.getBuffer().insert([3, Infinity], new Array(25).join("x "))

          expect(lineNumberStateForScreenRow(presenter, 2)).toBeUndefined()
          expectValues lineNumberStateForScreenRow(presenter, 3), {bufferRow: 3}
          expectValues lineNumberStateForScreenRow(presenter, 4), {bufferRow: 3}
          expectValues lineNumberStateForScreenRow(presenter, 5), {bufferRow: 3}
          expectValues lineNumberStateForScreenRow(presenter, 6), {bufferRow: 4}
          expectValues lineNumberStateForScreenRow(presenter, 7), {bufferRow: 7}
          expect(lineNumberStateForScreenRow(presenter, 8)).toBeUndefined()

        describe ".decorationClasses", ->
          it "adds decoration classes to the relevant line number state objects, both initially and when decorations change", ->
            marker1 = editor.markBufferRange([[4, 0], [6, 2]], invalidate: 'touch')
            decoration1 = editor.decorateMarker(marker1, type: 'line-number', class: 'a')
            presenter = new TextEditorPresenter(model: editor, clientHeight: 130, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
            marker2 = editor.markBufferRange([[4, 0], [6, 2]], invalidate: 'touch')
            decoration2 = editor.decorateMarker(marker2, type: 'line-number', class: 'b')

            expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a', 'b']
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a', 'b']
            expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

            expectStateUpdate presenter, -> editor.getBuffer().insert([5, 0], 'x')
            expect(marker1.isValid()).toBe false
            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

            expectStateUpdate presenter, -> editor.undo()
            expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a', 'b']
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a', 'b']
            expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

            expectStateUpdate presenter, -> marker1.setBufferRange([[2, 0], [4, 2]])
            expect(lineNumberStateForScreenRow(presenter, 1).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 2).decorationClasses).toEqual ['a']
            expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toEqual ['a']
            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['b']
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['b']
            expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

            expectStateUpdate presenter, -> decoration1.destroy()
            expect(lineNumberStateForScreenRow(presenter, 2).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['b']
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['b']
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['b']
            expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

            expectStateUpdate presenter, -> marker2.destroy()
            expect(lineNumberStateForScreenRow(presenter, 2).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

          it "honors the 'onlyEmpty' option on line-number decorations", ->
            presenter = new TextEditorPresenter(model: editor, clientHeight: 130, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
            marker = editor.markBufferRange([[4, 0], [6, 1]])
            decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a', onlyEmpty: true)

            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

            expectStateUpdate presenter, -> marker.clearTail()

            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

          it "honors the 'onlyNonEmpty' option on line-number decorations", ->
            presenter = new TextEditorPresenter(model: editor, clientHeight: 130, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
            marker = editor.markBufferRange([[4, 0], [6, 2]])
            decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a', onlyNonEmpty: true)

            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a']
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a']
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

            expectStateUpdate presenter, -> marker.clearTail()

            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

          it "honors the 'onlyHead' option on line-number decorations", ->
            presenter = new TextEditorPresenter(model: editor, clientHeight: 130, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
            marker = editor.markBufferRange([[4, 0], [6, 2]])
            decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a', onlyHead: true)

            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

          it "does not decorate the last line of a non-empty line-number decoration range if it ends at column 0", ->
            presenter = new TextEditorPresenter(model: editor, clientHeight: 130, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
            marker = editor.markBufferRange([[4, 0], [6, 0]])
            decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a')

            expect(lineNumberStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a']
            expect(lineNumberStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a']
            expect(lineNumberStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

          it "does not apply line-number decorations to mini editors", ->
            editor.setMini(true)
            presenter = new TextEditorPresenter(model: editor, clientHeight: 10, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
            marker = editor.markBufferRange([[0, 0], [0, 0]])
            decoration = editor.decorateMarker(marker, type: 'line-number', class: 'a')
            expect(lineNumberStateForScreenRow(presenter, 0).decorationClasses).toBeNull()

            expectStateUpdate presenter, -> editor.setMini(false)
            expect(lineNumberStateForScreenRow(presenter, 0).decorationClasses).toEqual ['cursor-line', 'cursor-line-no-selection', 'a']

            expectStateUpdate presenter, -> editor.setMini(true)
            expect(lineNumberStateForScreenRow(presenter, 0).decorationClasses).toBeNull()

          it "only applies line-number decorations to screen rows that are spanned by their marker when lines are soft-wrapped", ->
            editor.setText("a line that wraps, ok")
            editor.setSoftWrapped(true)
            editor.setEditorWidthInChars(16)
            marker = editor.markBufferRange([[0, 0], [0, 2]])
            editor.decorateMarker(marker, type: 'line-number', class: 'a')
            presenter = new TextEditorPresenter(model: editor, clientHeight: 10, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)

            expect(lineNumberStateForScreenRow(presenter, 0).decorationClasses).toContain 'a'
            expect(lineNumberStateForScreenRow(presenter, 1).decorationClasses).toBeNull()

            marker.setBufferRange([[0, 0], [0, Infinity]])
            expect(lineNumberStateForScreenRow(presenter, 0).decorationClasses).toContain 'a'
            expect(lineNumberStateForScreenRow(presenter, 1).decorationClasses).toContain 'a'

        describe ".foldable", ->
          it "marks line numbers at the start of a foldable region as foldable", ->
            presenter = new TextEditorPresenter(model: editor, clientHeight: 130, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
            expect(lineNumberStateForScreenRow(presenter, 0).foldable).toBe true
            expect(lineNumberStateForScreenRow(presenter, 1).foldable).toBe true
            expect(lineNumberStateForScreenRow(presenter, 2).foldable).toBe false
            expect(lineNumberStateForScreenRow(presenter, 3).foldable).toBe false
            expect(lineNumberStateForScreenRow(presenter, 4).foldable).toBe true
            expect(lineNumberStateForScreenRow(presenter, 5).foldable).toBe false

          it "updates the foldable class on the correct line numbers when the foldable positions change", ->
            presenter = new TextEditorPresenter(model: editor, clientHeight: 130, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
            editor.getBuffer().insert([0, 0], '\n')
            expect(lineNumberStateForScreenRow(presenter, 0).foldable).toBe false
            expect(lineNumberStateForScreenRow(presenter, 1).foldable).toBe true
            expect(lineNumberStateForScreenRow(presenter, 2).foldable).toBe true
            expect(lineNumberStateForScreenRow(presenter, 3).foldable).toBe false
            expect(lineNumberStateForScreenRow(presenter, 4).foldable).toBe false
            expect(lineNumberStateForScreenRow(presenter, 5).foldable).toBe true
            expect(lineNumberStateForScreenRow(presenter, 6).foldable).toBe false

          it "updates the foldable class on a line number that becomes foldable", ->
            presenter = new TextEditorPresenter(model: editor, clientHeight: 130, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
            expect(lineNumberStateForScreenRow(presenter, 11).foldable).toBe false

            editor.getBuffer().insert([11, 44], '\n    fold me')
            expect(lineNumberStateForScreenRow(presenter, 11).foldable).toBe true

            editor.undo()
            expect(lineNumberStateForScreenRow(presenter, 11).foldable).toBe false
