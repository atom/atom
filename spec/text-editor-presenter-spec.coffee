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

  describe "lines", ->
    describe "on initialization", ->
      it "contains the lines that are visible on screen, plus the overdraw margin", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1)

        line0 = editor.tokenizedLineForScreenRow(0)
        expectValues presenter.state.lines[line0.id], {
          screenRow: 0
          tokens: line0.tokens
          top: 10 * 0
        }

        line1 = editor.tokenizedLineForScreenRow(1)
        expectValues presenter.state.lines[line1.id], {
          screenRow: 1
          tokens: line1.tokens
          top: 10 * 1
        }

        line2 = editor.tokenizedLineForScreenRow(2)
        expectValues presenter.state.lines[line2.id], {
          screenRow: 2
          tokens: line2.tokens
          top: 10 * 2
        }

        # this row is rendered due to the overdraw margin
        line3 = editor.tokenizedLineForScreenRow(3)
        expectValues presenter.state.lines[line3.id], {
          screenRow: 3
          tokens: line3.tokens
          top: 10 * 3
        }

      it "contains the lines that are visible on screen, minus the overdraw margin", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 115, lineHeight: 10, lineOverdrawMargin: 1)

        # this row is rendered due to the overdraw margin
        line10 = editor.tokenizedLineForScreenRow(10)
        expectValues presenter.state.lines[line10.id], {
          screenRow: 10
          tokens: line10.tokens
          top: 10 * 10
        }

        line11 = editor.tokenizedLineForScreenRow(11)
        expectValues presenter.state.lines[line11.id], {
          screenRow: 11
          tokens: line11.tokens
          top: 10 * 11
        }

        line12 = editor.tokenizedLineForScreenRow(12)
        expectValues presenter.state.lines[line12.id], {
          screenRow: 12
          tokens: line12.tokens
          top: 10 * 12
        }

        # rows beyond the end of the content are not rendered

      it "uses the computed scrollWidth as the length of each line", ->
        line0 = editor.tokenizedLineForScreenRow(0)
        line1 = editor.tokenizedLineForScreenRow(1)
        line2 = editor.tokenizedLineForScreenRow(2)

        maxLineLength = editor.getMaxScreenLineLength()

        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 50, scrollTop: 0, baseCharacterWidth: 10, lineHeight: 10, lineOverdrawMargin: 0)
        expect(presenter.state.lines[line0.id].width).toBe 10 * maxLineLength
        expect(presenter.state.lines[line1.id].width).toBe 10 * maxLineLength
        expect(presenter.state.lines[line2.id].width).toBe 10 * maxLineLength

        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 10 * maxLineLength + 20, scrollTop: 0, baseCharacterWidth: 10, lineHeight: 10, lineOverdrawMargin: 0)
        expect(presenter.state.lines[line0.id].width).toBe 10 * maxLineLength + 20
        expect(presenter.state.lines[line1.id].width).toBe 10 * maxLineLength + 20
        expect(presenter.state.lines[line2.id].width).toBe 10 * maxLineLength + 20

    describe "when ::scrollTop changes", ->
      it "updates the lines that are visible on screen", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 0, lineHeight: 10, lineOverdrawMargin: 1)
        presenter.setScrollTop(25)

        line0 = editor.tokenizedLineForScreenRow(0)
        expect(presenter.state.lines[line0.id]).toBeUndefined()

        line1 = editor.tokenizedLineForScreenRow(1)
        expectValues presenter.state.lines[line1.id], {
          screenRow: 1
          tokens: line1.tokens
          top: 10 * 1
        }

        line2 = editor.tokenizedLineForScreenRow(2)
        expectValues presenter.state.lines[line2.id], {
          screenRow: 2
          tokens: line2.tokens
          top: 10 * 2
        }

        line3 = editor.tokenizedLineForScreenRow(3)
        expectValues presenter.state.lines[line3.id], {
          screenRow: 3
          tokens: line3.tokens
          top: 10 * 3
        }

        line4 = editor.tokenizedLineForScreenRow(4)
        expectValues presenter.state.lines[line4.id], {
          screenRow: 4
          tokens: line4.tokens
          top: 10 * 4
        }

    describe "when ::clientHeight changes", ->
      it "updates the lines that are visible on screen", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 25, lineHeight: 10, lineOverdrawMargin: 1)

        line5 = editor.tokenizedLineForScreenRow(5)
        expect(presenter.state.lines[line5.id]).toBeUndefined()

        presenter.setClientHeight(35)

        line1 = editor.tokenizedLineForScreenRow(1)
        expectValues presenter.state.lines[line1.id], {
          screenRow: 1
          tokens: line1.tokens
          top: 10 * 1
        }

        line2 = editor.tokenizedLineForScreenRow(2)
        expectValues presenter.state.lines[line2.id], {
          screenRow: 2
          tokens: line2.tokens
          top: 10 * 2
        }

        line3 = editor.tokenizedLineForScreenRow(3)
        expectValues presenter.state.lines[line3.id], {
          screenRow: 3
          tokens: line3.tokens
          top: 10 * 3
        }

        line4 = editor.tokenizedLineForScreenRow(4)
        expectValues presenter.state.lines[line4.id], {
          screenRow: 4
          tokens: line4.tokens
          top: 10 * 4
        }

        expectValues presenter.state.lines[line4.id], {
          screenRow: 4
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

        expect(presenter.state.lines[line1.id]).toBeDefined()
        expect(presenter.state.lines[line2.id]).toBeDefined()
        expect(presenter.state.lines[line3.id]).toBeUndefined()
        expect(presenter.state.lines[line4.id]).toBeUndefined()
        expect(presenter.state.lines[line5.id]).toBeUndefined()

        presenter.setLineHeight(5)

        expect(presenter.state.lines[line1.id]).toBeUndefined()

        expectValues presenter.state.lines[line2.id], {
          screenRow: 2
          tokens: line2.tokens
          top: 5 * 2
        }

        expectValues presenter.state.lines[line3.id], {
          screenRow: 3
          tokens: line3.tokens
          top: 5 * 3
        }

        expectValues presenter.state.lines[line4.id], {
          screenRow: 4
          tokens: line4.tokens
          top: 5 * 4
        }

        expect(presenter.state.lines[line5.id]).toBeUndefined()

    describe "when the editor's content changes", ->
      it "updates the lines state accordingly", ->
        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, scrollTop: 10, lineHeight: 10, lineOverdrawMargin: 0)

        buffer.insert([2, 0], "hello\nworld\n")

        line1 = editor.tokenizedLineForScreenRow(1)
        expectValues presenter.state.lines[line1.id], {
          screenRow: 1
          tokens: line1.tokens
          top: 10 * 1
        }

        line2 = editor.tokenizedLineForScreenRow(2)
        expectValues presenter.state.lines[line2.id], {
          screenRow: 2
          tokens: line2.tokens
          top: 10 * 2
        }

        line3 = editor.tokenizedLineForScreenRow(3)
        expectValues presenter.state.lines[line3.id], {
          screenRow: 3
          tokens: line3.tokens
          top: 10 * 3
        }

    describe "when the ::clientWidth changes", ->
      it "updates the width of the lines if it changes the ::scrollWidth", ->
        line0 = editor.tokenizedLineForScreenRow(0)
        line1 = editor.tokenizedLineForScreenRow(1)
        line2 = editor.tokenizedLineForScreenRow(2)

        maxLineLength = editor.getMaxScreenLineLength()

        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 50, scrollTop: 0, scrollWidth: 70, lineHeight: 10, baseCharacterWidth: 10, lineOverdrawMargin: 0)
        expect(presenter.state.lines[line0.id].width).toBe 10 * maxLineLength
        expect(presenter.state.lines[line1.id].width).toBe 10 * maxLineLength
        expect(presenter.state.lines[line2.id].width).toBe 10 * maxLineLength

        presenter.setClientWidth(10 * maxLineLength + 20)

        expect(presenter.state.lines[line0.id].width).toBe 10 * maxLineLength + 20
        expect(presenter.state.lines[line1.id].width).toBe 10 * maxLineLength + 20
        expect(presenter.state.lines[line2.id].width).toBe 10 * maxLineLength + 20

    describe "when the ::baseCharacterWidth changes", ->
      it "updates the width of the lines if it changes the ::scrollWidth", ->
        line0 = editor.tokenizedLineForScreenRow(0)
        line1 = editor.tokenizedLineForScreenRow(1)
        line2 = editor.tokenizedLineForScreenRow(2)

        maxLineLength = editor.getMaxScreenLineLength()

        presenter = new TextEditorPresenter(model: editor, clientHeight: 25, clientWidth: 50, scrollTop: 0, scrollWidth: 70, lineHeight: 10, baseCharacterWidth: 10, lineOverdrawMargin: 0)
        expect(presenter.state.lines[line0.id].width).toBe 10 * maxLineLength
        expect(presenter.state.lines[line1.id].width).toBe 10 * maxLineLength
        expect(presenter.state.lines[line2.id].width).toBe 10 * maxLineLength

        presenter.setBaseCharacterWidth(15)

        expect(presenter.state.lines[line0.id].width).toBe 15 * maxLineLength
        expect(presenter.state.lines[line1.id].width).toBe 15 * maxLineLength
        expect(presenter.state.lines[line2.id].width).toBe 15 * maxLineLength
