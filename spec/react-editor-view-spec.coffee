ReactEditorView = require '../src/react-editor-view'

describe "ReactEditorView", ->
  [editorView, editor, lineHeight] = []

  beforeEach ->
    editor = atom.project.openSync('sample.js')
    editorView = new ReactEditorView(editor)

    fontSize = 20
    lineHeight = 1.3 * fontSize
    editorView.css({lineHeight: 1.3, fontSize})

  it "renders only the currently-visible lines", ->
    editorView.height(4.5 * lineHeight)
    editorView.attachToDom()
    lines = editorView.element.querySelectorAll('.line')
    expect(lines.length).toBe 5
    expect(lines[0].textContent).toBe editor.lineForScreenRow(0).text
    expect(lines[4].textContent).toBe editor.lineForScreenRow(4).text

    editorView.setScrollTop(2.5 * lineHeight)
    lines = editorView.element.querySelectorAll('.line')
    expect(lines.length).toBe 5
    expect(lines[0].textContent).toBe editor.lineForScreenRow(2).text
    expect(lines[4].textContent).toBe editor.lineForScreenRow(6).text
