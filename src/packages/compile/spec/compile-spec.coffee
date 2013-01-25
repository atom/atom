Compile = require 'compile'
RootView = require 'root-view'

describe "Compile", ->
  [rootView, editor, path] = []

  beforeEach ->
    path = "/tmp/atom-whitespace.txt"
    fs.write(path, "")
    rootView = new RootView(path)

    StripTrailingWhitespace.activate(rootView)
    rootView.focus()
    editor = rootView.getActiveEditor()