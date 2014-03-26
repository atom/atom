ReactEditorView = require '../src/react-editor-view'

describe "ReactEditorView", ->
  it "renders", ->
    editor = atom.project.openSync('sample.js')
    editorView = new ReactEditorView(editor)
    editorView.attachToDom()
    console.log editorView.element
