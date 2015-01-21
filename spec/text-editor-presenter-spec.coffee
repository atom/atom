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

        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 50, scrollTop: 0, baseCharacterWidth: 10, lineHeight: 10, lineOverdrawMargin: 0)
        expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 1

        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 10 * maxLineLength + 20, scrollTop: 0, baseCharacterWidth: 10, lineHeight: 10, lineOverdrawMargin: 0)
        expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 20

      it "assigns .indentGuidesVisible based on the editor.showIndentGuide config setting", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 50, scrollTop: 0, baseCharacterWidth: 10, lineHeight: 10, lineOverdrawMargin: 0)
        expect(presenter.state.content.indentGuidesVisible).toBe false

        atom.config.set('editor.showIndentGuide', true)
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 50, scrollTop: 0, baseCharacterWidth: 10, lineHeight: 10, lineOverdrawMargin: 0)
        expect(presenter.state.content.indentGuidesVisible).toBe true

    describe "when the ::clientWidth changes", ->
      it "updates .scrollWidth", ->
        maxLineLength = editor.getMaxScreenLineLength()
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 50, scrollTop: 0, scrollWidth: 70, lineHeight: 10, baseCharacterWidth: 10, lineOverdrawMargin: 0)

        expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 1
        presenter.setClientWidth(10 * maxLineLength + 20)
        expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 20

    describe "when the ::baseCharacterWidth changes", ->
      it "updates the width of the lines if it changes the ::scrollWidth", ->
        maxLineLength = editor.getMaxScreenLineLength()
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 50, scrollTop: 0, scrollWidth: 70, lineHeight: 10, baseCharacterWidth: 10, lineOverdrawMargin: 0)

        expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 1
        presenter.setBaseCharacterWidth(15)
        expect(presenter.state.content.scrollWidth).toBe 15 * maxLineLength + 1

    describe "when the scoped character widths change", ->
      beforeEach ->
        waitsForPromise -> atom.packages.activatePackage('language-javascript')

      it "updates the width of the lines if the ::scrollWidth changes", ->
        maxLineLength = editor.getMaxScreenLineLength()
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 50, scrollTop: 0, scrollWidth: 70, lineHeight: 10, baseCharacterWidth: 10, lineOverdrawMargin: 0)

        expect(presenter.state.content.scrollWidth).toBe 10 * maxLineLength + 1
        presenter.setScopedCharWidth(['source.js', 'support.function.js'], 'p', 20)
        expect(presenter.state.content.scrollWidth).toBe (10 * (maxLineLength - 2)) + (20 * 2) + 1 # 2 of the characters are 20px wide now instead of 10px wide

    describe "when ::softWrapped changes on the editor", ->
      it "only accounts for the cursor in .scrollWidth if ::softWrapped is false", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 50, scrollTop: 0, scrollWidth: 70, lineHeight: 10, baseCharacterWidth: 10, lineOverdrawMargin: 0)
        expect(presenter.state.content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1
        editor.setSoftWrapped(true)
        expect(presenter.state.content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength()
        editor.setSoftWrapped(false)
        expect(presenter.state.content.scrollWidth).toBe 10 * editor.getMaxScreenLineLength() + 1

    describe "when the editor.showIndentGuide config setting changes", ->
      it "updates .indentGuidesVisible", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 50, scrollTop: 0, baseCharacterWidth: 10, lineHeight: 10, lineOverdrawMargin: 0)
        expect(presenter.state.content.indentGuidesVisible).toBe false

        atom.config.set('editor.showIndentGuide', true)
        expect(presenter.state.content.indentGuidesVisible).toBe true

        atom.config.set('editor.showIndentGuide', false)
        expect(presenter.state.content.indentGuidesVisible).toBe false

  describe "::state.content.lines", ->
    describe "on initialization", ->
      it "contains the lines that are visible on screen, plus the overdraw margin", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1)

        line0 = editor.tokenizedLineForScreenRow(0)
        expectValues presenter.state.content.lines[line0.id], {
          screenRow: 0
          text: line0.text
          tokens: line0.tokens
          top: 10 * 0
        }

        line1 = editor.tokenizedLineForScreenRow(1)
        expectValues presenter.state.content.lines[line1.id], {
          screenRow: 1
          text: line1.text
          tokens: line1.tokens
          top: 10 * 1
        }

        line2 = editor.tokenizedLineForScreenRow(2)
        expectValues presenter.state.content.lines[line2.id], {
          screenRow: 2
          text: line2.text
          tokens: line2.tokens
          top: 10 * 2
        }

        # this row is rendered due to the overdraw margin
        line3 = editor.tokenizedLineForScreenRow(3)
        expectValues presenter.state.content.lines[line3.id], {
          screenRow: 3
          text: line3.text
          tokens: line3.tokens
          top: 10 * 3
        }

      it "contains the lines that are visible on screen, minus the overdraw margin", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 115, lineHeight: 10, lineOverdrawMargin: 1)

        # this row is rendered due to the overdraw margin
        line10 = editor.tokenizedLineForScreenRow(10)
        expectValues presenter.state.content.lines[line10.id], {
          screenRow: 10
          text: line10.text
          tokens: line10.tokens
          top: 10 * 10
        }

        line11 = editor.tokenizedLineForScreenRow(11)
        expectValues presenter.state.content.lines[line11.id], {
          screenRow: 11
          text: line11.text
          tokens: line11.tokens
          top: 10 * 11
        }

        line12 = editor.tokenizedLineForScreenRow(12)
        expectValues presenter.state.content.lines[line12.id], {
          screenRow: 12
          text: line12.text
          tokens: line12.tokens
          top: 10 * 12
        }

        # rows beyond the end of the content are not rendered

      it "contains the lines that are visible on screen, plus and minus the overdraw margin", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 50, lineHeight: 10, lineOverdrawMargin: 1)
        expect(presenter.state.content.lines[editor.tokenizedLineForScreenRow(3).id]).toBeUndefined()
        expect(presenter.state.content.lines[editor.tokenizedLineForScreenRow(4).id]).toBeDefined()
        expect(presenter.state.content.lines[editor.tokenizedLineForScreenRow(9).id]).toBeDefined()
        expect(presenter.state.content.lines[editor.tokenizedLineForScreenRow(10).id]).toBeUndefined()

      it "reports all lines as visible if no external ::clientHeight is assigned", ->
        presenter = new TextEditorPresenter(model: editor, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1)
        expect(presenter.state.content.lines[editor.tokenizedLineForScreenRow(0).id]).toBeDefined()
        expect(presenter.state.content.lines[editor.tokenizedLineForScreenRow(12).id]).toBeDefined()

      it "includes the endOfLineInvisibles in the line state", ->
        editor.setText("hello\nworld\r\n")
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 50, scrollTop: 0, baseCharacterWidth: 10, lineHeight: 10, lineOverdrawMargin: 0)
        expect(presenter.state.content.lines[editor.tokenizedLineForScreenRow(0).id].endOfLineInvisibles).toBeNull()
        expect(presenter.state.content.lines[editor.tokenizedLineForScreenRow(1).id].endOfLineInvisibles).toBeNull()

        atom.config.set('editor.showInvisibles', true)
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 50, scrollTop: 0, baseCharacterWidth: 10, lineHeight: 10, lineOverdrawMargin: 0)
        expect(presenter.state.content.lines[editor.tokenizedLineForScreenRow(0).id].endOfLineInvisibles).toEqual [atom.config.get('editor.invisibles.eol')]
        expect(presenter.state.content.lines[editor.tokenizedLineForScreenRow(1).id].endOfLineInvisibles).toEqual [atom.config.get('editor.invisibles.cr'), atom.config.get('editor.invisibles.eol')]

    describe "when ::scrollTop changes", ->
      it "updates the lines that are visible on screen", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1)
        presenter.setScrollTop(25)

        line0 = editor.tokenizedLineForScreenRow(0)
        expect(presenter.state.content.lines[line0.id]).toBeUndefined()

        line1 = editor.tokenizedLineForScreenRow(1)
        expectValues presenter.state.content.lines[line1.id], {
          screenRow: 1
          text: line1.text
          tokens: line1.tokens
          top: 10 * 1
        }

        line2 = editor.tokenizedLineForScreenRow(2)
        expectValues presenter.state.content.lines[line2.id], {
          screenRow: 2
          text: line2.text
          tokens: line2.tokens
          top: 10 * 2
        }

        line3 = editor.tokenizedLineForScreenRow(3)
        expectValues presenter.state.content.lines[line3.id], {
          screenRow: 3
          text: line3.text
          tokens: line3.tokens
          top: 10 * 3
        }

        line4 = editor.tokenizedLineForScreenRow(4)
        expectValues presenter.state.content.lines[line4.id], {
          screenRow: 4
          text: line4.text
          tokens: line4.tokens
          top: 10 * 4
        }

    describe "when ::clientHeight changes", ->
      it "updates the lines that are visible on screen", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 15, scrollTop: 15, lineHeight: 10, lineOverdrawMargin: 1)

        line5 = editor.tokenizedLineForScreenRow(5)
        expect(presenter.state.content.lines[line5.id]).toBeUndefined()

        presenter.setClientHeight(35)

        line1 = editor.tokenizedLineForScreenRow(1)
        expectValues presenter.state.content.lines[line1.id], {
          screenRow: 1
          text: line1.text
          tokens: line1.tokens
          top: 10 * 1
        }

        line2 = editor.tokenizedLineForScreenRow(2)
        expectValues presenter.state.content.lines[line2.id], {
          screenRow: 2
          text: line2.text
          tokens: line2.tokens
          top: 10 * 2
        }

        line3 = editor.tokenizedLineForScreenRow(3)
        expectValues presenter.state.content.lines[line3.id], {
          screenRow: 3
          text: line3.text
          tokens: line3.tokens
          top: 10 * 3
        }

        line4 = editor.tokenizedLineForScreenRow(4)
        expectValues presenter.state.content.lines[line4.id], {
          screenRow: 4
          text: line4.text
          tokens: line4.tokens
          top: 10 * 4
        }

        expectValues presenter.state.content.lines[line4.id], {
          screenRow: 4
          text: line4.text
          tokens: line4.tokens
          top: 10 * 4
        }

    describe "when ::lineHeight changes", ->
      it "updates the lines that are visible on screen", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 15, scrollTop: 10, lineHeight: 10, lineOverdrawMargin: 0)

        line1 = editor.tokenizedLineForScreenRow(1)
        line2 = editor.tokenizedLineForScreenRow(2)
        line3 = editor.tokenizedLineForScreenRow(3)
        line4 = editor.tokenizedLineForScreenRow(4)
        line5 = editor.tokenizedLineForScreenRow(5)
        line6 = editor.tokenizedLineForScreenRow(6)

        expect(presenter.state.content.lines[line1.id]).toBeDefined()
        expect(presenter.state.content.lines[line2.id]).toBeDefined()
        expect(presenter.state.content.lines[line3.id]).toBeDefined()
        expect(presenter.state.content.lines[line4.id]).toBeUndefined()
        expect(presenter.state.content.lines[line5.id]).toBeUndefined()

        presenter.setLineHeight(5)

        expect(presenter.state.content.lines[line1.id]).toBeUndefined()

        expectValues presenter.state.content.lines[line2.id], {
          screenRow: 2
          text: line2.text
          tokens: line2.tokens
          top: 5 * 2
        }

        expectValues presenter.state.content.lines[line3.id], {
          screenRow: 3
          text: line3.text
          tokens: line3.tokens
          top: 5 * 3
        }

        expectValues presenter.state.content.lines[line4.id], {
          screenRow: 4
          text: line4.text
          tokens: line4.tokens
          top: 5 * 4
        }

        expectValues presenter.state.content.lines[line5.id], {
          screenRow: 5
          text: line5.text
          tokens: line5.tokens
          top: 5 * 5
        }

        expect(presenter.state.content.lines[line6.id]).toBeUndefined()

    describe "when the editor's content changes", ->
      it "updates the lines state accordingly", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 10, lineHeight: 10, lineOverdrawMargin: 0)

        buffer.insert([2, 0], "hello\nworld\n")

        line1 = editor.tokenizedLineForScreenRow(1)
        expectValues presenter.state.content.lines[line1.id], {
          screenRow: 1
          text: line1.text
          tokens: line1.tokens
          top: 10 * 1
        }

        line2 = editor.tokenizedLineForScreenRow(2)
        expectValues presenter.state.content.lines[line2.id], {
          screenRow: 2
          text: line2.text
          tokens: line2.tokens
          top: 10 * 2
        }

        line3 = editor.tokenizedLineForScreenRow(3)
        expectValues presenter.state.content.lines[line3.id], {
          screenRow: 3
          text: line3.text
          tokens: line3.tokens
          top: 10 * 3
        }
