RootView = require 'root-view'
fsUtils = require 'fs-utils'

describe "Whitespace", ->
  [editor, path] = []

  beforeEach ->
    path = "/tmp/atom-whitespace.txt"
    fsUtils.write(path, "")
    window.rootView = new RootView
    rootView.open(path)

    atom.activatePackage('whitespace')

    rootView.focus()
    editor = rootView.getActiveView()

  afterEach ->
    fsUtils.remove(path) if fsUtils.exists(path)

  it "strips trailing whitespace before an editor saves a buffer", ->
    spyOn(fsUtils, 'write')

    config.set("whitespace.ensureSingleTrailingNewline", false)
    config.update()

    # works for buffers that are already open when extension is initialized
    editor.insertText("foo   \nbar\t   \n\nbaz")
    editor.getBuffer().save()
    expect(editor.getText()).toBe "foo\nbar\n\nbaz"

    # works for buffers that are opened after extension is initialized
    rootView.open(require.resolve('fixtures/sample.txt'))
    editor.moveCursorToEndOfLine()
    editor.insertText("           ")

    editor.getBuffer().save()
    expect(editor.getText()).toBe 'Some text.\n'

  describe "whitespace.ensureSingleTrailingNewline config", ->
    [originalConfigValue] = []
    beforeEach ->
      originalConfigValue = config.get("whitespace.ensureSingleTrailingNewline")
      expect(originalConfigValue).toBe true

    afterEach ->
      config.set("whitespace.ensureSingleTrailingNewline", originalConfigValue)
      config.update()

    it "adds a trailing newline when there is no trailing newline", ->
      editor.insertText "foo"
      editor.getBuffer().save()
      expect(editor.getText()).toBe "foo\n"

    it "removes extra trailing newlines and only keeps one", ->
      editor.insertText "foo\n\n\n\n"
      editor.getBuffer().save()
      expect(editor.getText()).toBe "foo\n"

    it "leaves a buffer with a single trailing newline untouched", ->
      editor.insertText "foo\nbar\n"
      editor.getBuffer().save()
      expect(editor.getText()).toBe "foo\nbar\n"

    it "leaves an empty buffer untouched", ->
      editor.insertText ""
      editor.getBuffer().save()
      expect(editor.getText()).toBe ""

    it "leaves a buffer that is a single newline untouched", ->
      editor.insertText "\n"
      editor.getBuffer().save()
      expect(editor.getText()).toBe "\n"

    it "does not add trailing newline if ensureSingleTrailingNewline is false", ->
      config.set("whitespace.ensureSingleTrailingNewline", false)
      config.update()

      editor.insertText "no trailing newline"
      editor.getBuffer().save()
      expect(editor.getText()).toBe "no trailing newline"

    it "does not move the cursor when the new line is added", ->
      editor.insertText "foo"
      expect(editor.getCursorBufferPosition()).toEqual([0,3])
      editor.getBuffer().save()
      expect(editor.getText()).toBe "foo\n"
      expect(editor.getCursorBufferPosition()).toEqual([0,3])

  describe "whitespace.ensureSingleTrailingNewline config", ->
    [originalConfigValue] = []
    grammar = null

    beforeEach ->
      originalConfigValue = config.get("whitespace.ignoredGrammars")
      expect(originalConfigValue).toEqual ["GitHub Markdown"]
      spyOn(syntax, "addGrammar").andCallThrough()
      atom.activatePackage("gfm")
      expect(syntax.addGrammar).toHaveBeenCalled()
      grammar = syntax.addGrammar.argsForCall[0][0]

    afterEach ->
      config.set("whitespace.ignoredGrammars", originalConfigValue)
      config.update()

    it "parses the grammar", ->
      expect(grammar).toBeDefined()
      expect(grammar.scopeName).toBe "source.gfm"

    it "leaves Markdown files alone", ->
      editor.insertText "foo  \nline break!"
      editor.getBuffer().save()
      expect(editor.getText()).toBe "foo  \nline break!"
