HighlightTrailingWhitespace = require 'highlight-trailing-whitespace'
RootView = require 'root-view'
fs = require 'fs'

fdescribe "HighlightTrailingWhitespace", ->
  [rootView, editor, path] = []

  beforeEach ->
    path = "/tmp/atom-whitespace.txt"
    fs.write(path, "")
    rootView = new RootView(path)

    HighlightTrailingWhitespace.activate(rootView)
    rootView.focus()
    editor = rootView.getActiveEditor()

  afterEach ->
    fs.remove(path) if fs.exists(path)
    rootView.remove()

  it "highlights trailing whitespace", ->
    # there's no trailing whitespace so there should be no errors
    expect($(editor).children('span.whitespace')).toBe null

    # make some trailing whitespace
    editor.insertText("foo   \nbar\t   \n\nbaz")

    # we now have trailing tabs and spaces, there should be errors
    expect($(editor).children('span.whitespace')).toNotBe null

    # works for buffers that are opened after extension is initialized
    rootView.open(require.resolve('fixtures/sample.txt'))
    editor.moveCursorToEndOfLine()
    editor.insertText("           ")

    # there should be errors
    expect($(editor).children('span.whitespace')).toNotBe null

    # can turn off the mode
    HighlightTrailingWhitespace.deactivate(rootView)
    expect($(editor).children('span.whitespace')).toBe null