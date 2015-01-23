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
      expect(actual[key]).toBe value

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

      describe ".scrollHeight", ->
        it "is initialized based on the lineHeight and the number of lines", ->
          presenter = new TextEditorPresenter(model: editor, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1)
          expect(presenter.state.content.scrollHeight).toBe editor.getScreenLineCount() * 10

        it "updates when the ::lineHeight changes", ->
          presenter = new TextEditorPresenter(model: editor, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1)
          expectStateUpdate presenter, -> presenter.setLineHeight(20)
          expect(presenter.state.content.scrollHeight).toBe editor.getScreenLineCount() * 20

        it "updates when the line count changes", ->
          presenter = new TextEditorPresenter(model: editor, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1)
          expectStateUpdate presenter, -> editor.getBuffer().append("\n\n\n")
          expect(presenter.state.content.scrollHeight).toBe editor.getScreenLineCount() * 10

      describe ".scrollTop", ->
        it "tracks the value of ::scrollTop", ->
          presenter = new TextEditorPresenter(model: editor, scrollTop: 10, lineHeight: 10, lineOverdrawMargin: 1)
          expect(presenter.state.content.scrollTop).toBe 10
          expectStateUpdate presenter, -> presenter.setScrollTop(50)
          expect(presenter.state.content.scrollTop).toBe 50

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
