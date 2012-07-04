StripTrailingWhitespace = require 'strip-trailing-whitespace'
RootView = require 'root-view'
fs = require 'fs'

describe "StripTrailingWhitespace", ->
  [rootView, editor, path] = []

  beforeEach ->
    path = "/tmp/atom-whitespace.txt"
    fs.write(path, "")
    rootView = new RootView(path)

    StripTrailingWhitespace.activate(rootView)
    rootView.focus()
    editor = rootView.getActiveEditor()

  afterEach ->
    fs.remove(path) if fs.exists(path)
    rootView.remove()

  it "strips trailing whitespace before an editor saves a buffer", ->
    spyOn(fs, 'write')

    # works for buffers that are already open when extension is initialized
    editor.insertText("foo   \nbar\t   \n\nbaz")
    editor.save()
    expect(editor.getText()).toBe "foo\nbar\n\nbaz"

    # works for buffers that are opened after extension is initialized
    rootView.open(require.resolve('fixtures/sample.txt'))
    editor.moveCursorToEndOfLine()
    editor.insertText("           ")

    editor.getBuffer().save()
    expect(editor.getText()).toBe 'Some text.\n'
