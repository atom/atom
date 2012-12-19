SingleTrailingNewline = require 'single-trailing-newline'
RootView = require 'root-view'
fs = require 'fs'

describe "SingleTrailingNewline", ->
  [rootView, editor, path] = []

  beforeEach ->
    path = "/tmp/atom-whitespace.txt"
    fs.write(path, "")
    rootView = new RootView(path)

    SingleTrailingNewline.activate(rootView)
    rootView.focus()
    editor = rootView.getActiveEditor()

  afterEach ->
    fs.remove(path) if fs.exists(path)
    rootView.remove()

  it "adds a trailing newline when there is no trailing newline", ->
    editor.insertText "foo"
    editor.save()
    expect(editor.getText()).toBe "foo\n"

  it "removes extra trailing newlines and only keeps one", ->
    editor.insertText "foo\n\n\n\n"
    editor.save()
    expect(editor.getText()).toBe "foo\n"

  it "leaves a buffer with a single trailing newline untouched", ->
    editor.insertText "foo\nbar\n"
    editor.save()
    expect(editor.getText()).toBe "foo\nbar\n"

  it "leaves an empty buffer untouched", ->
    editor.insertText ""
    editor.save()
    expect(editor.getText()).toBe ""
