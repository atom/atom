LowerCaseCommand = require 'lowercase-command'
RootView = require 'root-view'
fs = require 'fs'

describe "LowerCaseCommand", ->
  [rootView, editor, path] = []

  beforeEach ->
    rootView = new RootView
    rootView.open(require.resolve 'fixtures/sample.js')

    rootView.focus()
    editor = rootView.getActiveEditor()

  afterEach ->
    rootView.remove()

  it "replaces the selected text with all lower case characters", ->
    LowerCaseCommand.activate(rootView)
    editor.setSelectedBufferRange([[11,14], [11,19]])
    expect(editor.getTextInRange(editor.getSelection().getBufferRange())).toBe 'Array'
    editor.trigger 'lowercase'
    expect(editor.getTextInRange(editor.getSelection().getBufferRange())).toBe 'array'
