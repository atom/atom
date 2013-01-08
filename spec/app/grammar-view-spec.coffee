RootView = require 'root-view'
GrammarView = require 'grammar-view'
_ = require 'underscore'

describe "GrammarView", ->
  [editor, rootView, textGrammar, jsGrammar] =  []

  beforeEach ->
    path = require.resolve('fixtures/sample.js')
    syntax.removeGrammarForPath(path)
    rootView = new RootView(path)
    editor = rootView.getActiveEditor()
    rootView.attachToDom()
    textGrammar = _.find syntax.grammars, (grammar) -> grammar.name is 'Plain Text'
    expect(textGrammar).toBeTruthy()
    jsGrammar = _.find syntax.grammars, (grammar) -> grammar.name is 'JavaScript'
    expect(jsGrammar).toBeTruthy()
    expect(editor.getGrammar()).toBe jsGrammar

  afterEach ->
    rootView.deactivate()

  describe "when editor:select-grammar is toggled", ->
    it "displays a list of all the available grammars", ->
      editor.trigger 'editor:select-grammar'
      grammarView = rootView.find('.grammar-view').view()
      expect(grammarView).toExist()
      grammars = syntax.grammars
      expect(grammarView.list.children('li').length).toBe grammars.length + 1
      expect(grammarView.list.children('li:first').text()).toBe 'Auto Detect'

  describe "when a grammar is selected", ->
    it "sets the new grammar on the editor", ->
      editor.trigger 'editor:select-grammar'
      grammarView = rootView.find('.grammar-view').view()
      grammarView.confirmed(textGrammar)
      expect(editor.getGrammar()).toBe textGrammar

  describe "when auto-detect is selected", ->
    it "restores the auto-detected grammar on the editor", ->
      editor.trigger 'editor:select-grammar'
      grammarView = rootView.find('.grammar-view').view()
      grammarView.confirmed(textGrammar)
      expect(editor.getGrammar()).toBe textGrammar

      editor.trigger 'editor:select-grammar'
      grammarView = rootView.find('.grammar-view').view()
      grammarView.confirmed(grammarView.array[0])
      expect(editor.getGrammar()).toBe jsGrammar
