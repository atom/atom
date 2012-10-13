UpperCaseCommand = require 'uppercase-command'
RootView = require 'root-view'
fs = require 'fs'

describe "UpperCaseCommand", ->
  [rootView, editor, path] = []

  beforeEach ->
    rootView = new RootView
    rootView.open(require.resolve 'fixtures/sample.js')

    rootView.focus()
    editor = rootView.getActiveEditor()

  afterEach ->
    rootView.remove()

  it "replaces the selected text with all upper case characters", ->
    UpperCaseCommand.activate(rootView)
    editor.setSelectedBufferRange([[0,0], [0,3]])
    expect(editor.getTextInRange(editor.getSelection().getBufferRange())).toBe 'var'
    editor.trigger 'uppercase'
    expect(editor.getTextInRange(editor.getSelection().getBufferRange())).toBe 'VAR'
