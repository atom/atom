TextBuffer = require 'text-buffer'
TextEditor = require '../src/text-editor'
TextEditorPresenter = require '../src/text-editor-presenter'

describe "TextEditorPresenter", ->
  [buffer, editor] = []

  beforeEach ->
    buffer = new TextBuffer(filePath: require.resolve('./fixtures/sample.js'))
    editor = new TextEditor({buffer})
    waitsForPromise -> buffer.load()

  afterEach ->
    editor.destroy()
    buffer.destroy()

  expectValues = (actual, expected) ->
    for key, value of expected
      expect(actual[key]).toBe value

  describe "::state.content", ->
    describe "on initialization", ->
      it "assigns .scrollWidth based on the clientWidth and the width of the longest line", ->
        maxLineLength = editor.getMaxScreenLineLength()

        presenter = new TextEditorPresenter(model: editor, clientWidth: 50, baseCharacterWidth: 10)
        expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 1

        presenter = new TextEditorPresenter(model: editor, clientWidth: 10 * maxLineLength + 20, baseCharacterWidth: 10)
        expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 20

      it "assigns .indentGuidesVisible based on the editor.showIndentGuide config setting", ->
        presenter = new TextEditorPresenter(model: editor)
        expect(presenter.state.content.indentGuidesVisible).toBe false

        atom.config.set('editor.showIndentGuide', true)
        presenter = new TextEditorPresenter(model: editor)
        expect(presenter.state.content.indentGuidesVisible).toBe true

    describe "when the ::clientWidth changes", ->
      it "updates .scrollWidth", ->
        maxLineLength = editor.getMaxScreenLineLength()
        presenter = new TextEditorPresenter(model: editor, clientWidth: 50, baseCharacterWidth: 10)

        expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 1
        presenter.setClientWidth(10 * maxLineLength + 20)
        expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 20

    describe "when the ::baseCharacterWidth changes", ->
      it "updates the width of the lines if it changes the ::scrollWidth", ->
        maxLineLength = editor.getMaxScreenLineLength()
        presenter = new TextEditorPresenter(model: editor, clientWidth: 50, baseCharacterWidth: 10)

        expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 1
        presenter.setBaseCharacterWidth(15)
        expect(presenter.state.content.scrollWidth).toBe 15 * maxLineLength + 1

    describe "when the scoped character widths change", ->
      beforeEach ->
        waitsForPromise -> atom.packages.activatePackage('language-javascript')

      it "updates the width of the lines if the ::scrollWidth changes", ->
        maxLineLength = editor.getMaxScreenLineLength()
        presenter = new TextEditorPresenter(model: editor, clientWidth: 50, baseCharacterWidth: 10)

        expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 1
        presenter.setScopedCharWidth(['source.js', 'support.function.js'], 'p', 20)
        expect(presenter.state.content.scrollWidth).toBe (10 * (maxLineLength - 2)) + (20 * 2) + 1 # 2 of the characters are 20px wide now instead of 10px wide

    describe "when ::softWrapped changes on the editor", ->
      it "only accounts for the cursor in .scrollWidth if ::softWrapped is false", ->
        presenter = new TextEditorPresenter(model: editor, clientWidth: 50, baseCharacterWidth: 10)
        expect(presenter.state.content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1
        editor.setSoftWrapped(true)
        expect(presenter.state.content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength()
        editor.setSoftWrapped(false)
        expect(presenter.state.content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

    describe "when the editor.showIndentGuide config setting changes", ->
      it "updates .indentGuidesVisible", ->
        presenter = new TextEditorPresenter(model: editor)
        expect(presenter.state.content.indentGuidesVisible).toBe false

        atom.config.set('editor.showIndentGuide', true)
        expect(presenter.state.content.indentGuidesVisible).toBe true

        atom.config.set('editor.showIndentGuide', false)
        expect(presenter.state.content.indentGuidesVisible).toBe false

    describe "when the editor's grammar changes", ->
      it "updates .indentGuidesVisible based on the grammar's root scope", ->
        atom.config.set('editor.showIndentGuide', true, scopeSelector: ".source.js")

        presenter = new TextEditorPresenter(model: editor)
        expect(presenter.state.content.indentGuidesVisible).toBe false

        waitsForPromise -> atom.packages.activatePackage('language-javascript')

        runs ->
          editor.setGrammar(atom.grammars.selectGrammar('.js'))
          expect(presenter.state.content.indentGuidesVisible).toBe true

          editor.setGrammar(atom.grammars.selectGrammar('.txt'))
          expect(presenter.state.content.indentGuidesVisible).toBe false

  describe "::state.content.lines", ->
    lineStateForScreenRow = (presenter, screenRow) ->
      presenter.state.content.lines[presenter.model.tokenizedLineForScreenRow(screenRow).id]

    describe "on initialization", ->
      it "contains the lines that are visible on screen, plus and minus the overdraw margin", ->
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

      it "does not overdraw beyond the first row", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 15, scrollTop: 10, lineHeight: 10, lineOverdrawMargin: 2)
        expect(lineStateForScreenRow(presenter, 0)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 1)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 2)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 3)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 4)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 5)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 6)).toBeUndefined()

      it "does not overdraw beyond the last row", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 105, lineHeight: 10, lineOverdrawMargin: 2)
        expect(lineStateForScreenRow(presenter, 7)).toBeUndefined()
        expect(lineStateForScreenRow(presenter, 8)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 9)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 10)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 11)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 12)).toBeDefined()

      it "reports all lines as visible if no external ::clientHeight is assigned", ->
        presenter = new TextEditorPresenter(model: editor, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1)
        expect(lineStateForScreenRow(presenter, 0)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 12)).toBeDefined()

      it "includes the .endOfLineInvisibles in the line state if the editor.showInvisibles config option is true", ->
        editor.setText("hello\nworld\r\n")
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
        expect(lineStateForScreenRow(presenter, 0).endOfLineInvisibles).toBeNull()
        expect(lineStateForScreenRow(presenter, 1).endOfLineInvisibles).toBeNull()

        atom.config.set('editor.showInvisibles', true)
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
        expect(lineStateForScreenRow(presenter, 0).endOfLineInvisibles).toEqual [atom.config.get('editor.invisibles.eol')]
        expect(lineStateForScreenRow(presenter, 1).endOfLineInvisibles).toEqual [atom.config.get('editor.invisibles.cr'), atom.config.get('editor.invisibles.eol')]

    describe "when ::scrollTop changes", ->
      it "updates the lines that are visible on screen", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1)

        expect(lineStateForScreenRow(presenter, 0)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 4)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 5)).toBeUndefined()

        presenter.setScrollTop(25)

        expect(lineStateForScreenRow(presenter, 0)).toBeUndefined()
        expect(lineStateForScreenRow(presenter, 1)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 6)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 7)).toBeUndefined()

    describe "when ::clientHeight changes", ->
      it "updates the lines that are visible on screen", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 15, scrollTop: 15, lineHeight: 10, lineOverdrawMargin: 1)

        line5 = editor.tokenizedLineForScreenRow(5)

        expect(lineStateForScreenRow(presenter, 4)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 5)).toBeUndefined()

        presenter.setClientHeight(35)

        expect(lineStateForScreenRow(presenter, 5)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 6)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 7)).toBeUndefined()

    describe "when ::lineHeight changes", ->
      it "updates the lines that are visible on screen", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 15, scrollTop: 10, lineHeight: 10, lineOverdrawMargin: 0)

        expect(lineStateForScreenRow(presenter, 0)).toBeUndefined()
        expect(lineStateForScreenRow(presenter, 1)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 2)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 4)).toBeUndefined()

        presenter.setLineHeight(5)

        expect(lineStateForScreenRow(presenter, 0)).toBeUndefined()
        expect(lineStateForScreenRow(presenter, 1)).toBeUndefined()
        expect(lineStateForScreenRow(presenter, 2)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 5)).toBeDefined()
        expect(lineStateForScreenRow(presenter, 6)).toBeUndefined()

    describe "when the editor's content changes", ->
      it "updates the lines state accordingly", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 10, lineHeight: 10, lineOverdrawMargin: 0)

        buffer.insert([2, 0], "hello\nworld\n")

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

    describe ".decorationClasses in line state", ->
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

        editor.getBuffer().insert([5, 0], 'x')
        expect(marker1.isValid()).toBe false
        expect(lineStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
        expect(lineStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
        expect(lineStateForScreenRow(presenter, 6).decorationClasses).toBeNull()

        editor.undo()
        expect(lineStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
        expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
        expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a', 'b']
        expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a', 'b']
        expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

        marker1.setBufferRange([[2, 0], [4, 2]])
        expect(lineStateForScreenRow(presenter, 1).decorationClasses).toBeNull()
        expect(lineStateForScreenRow(presenter, 2).decorationClasses).toEqual ['a']
        expect(lineStateForScreenRow(presenter, 3).decorationClasses).toEqual ['a']
        expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a', 'b']
        expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['b']
        expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['b']
        expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

        decoration1.destroy()
        expect(lineStateForScreenRow(presenter, 2).decorationClasses).toBeNull()
        expect(lineStateForScreenRow(presenter, 3).decorationClasses).toBeNull()
        expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['b']
        expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['b']
        expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['b']
        expect(lineStateForScreenRow(presenter, 7).decorationClasses).toBeNull()

        marker2.destroy()
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

        marker.clearTail()

        expect(lineStateForScreenRow(presenter, 4).decorationClasses).toBeNull()
        expect(lineStateForScreenRow(presenter, 5).decorationClasses).toBeNull()
        expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

      it "honors the 'onlyNonEmpty' option on line decorations", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 130, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 0)
        marker = editor.markBufferRange([[4, 0], [6, 1]])
        decoration = editor.decorateMarker(marker, type: 'line', class: 'a', onlyNonEmpty: true)

        expect(lineStateForScreenRow(presenter, 4).decorationClasses).toEqual ['a']
        expect(lineStateForScreenRow(presenter, 5).decorationClasses).toEqual ['a']
        expect(lineStateForScreenRow(presenter, 6).decorationClasses).toEqual ['a']

        marker.clearTail()

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

        editor.setMini(false)
        expect(lineStateForScreenRow(presenter, 0).decorationClasses).toEqual ['cursor-line', 'a']

        editor.setMini(true)
        expect(lineStateForScreenRow(presenter, 0).decorationClasses).toBeNull()
