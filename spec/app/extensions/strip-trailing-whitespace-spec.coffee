StripTrailingWhitespace = require 'extensions/strip-trailing-whitespace'
RootView = require 'root-view'
fs = require 'fs'

describe "StripTrailingWhitespace", ->
  [rootView, editor] = []

  beforeEach ->
    rootView = new RootView
    StripTrailingWhitespace.initialize(rootView)
    rootView.focus()
    editor = rootView.activeEditor()

  it "strips trailing whitespace before an editor saves a buffer", ->
    spyOn(fs, 'write')

    # works for buffers that are already open when extension is initialized
    editor.insertText("foo   ")
    editor.buffer.saveAs("/tmp/test")
    expect(editor.buffer.getText()).toBe "foo"

    # works for buffers that are opened after extension is initialized
    rootView.open(require.resolve('fixtures/sample.txt'))
    editor.moveCursorToEndOfLine()
    editor.insertText("           ")

    editor.buffer.save()
    expect(editor.buffer.getText()).toBe 'Some text.'
