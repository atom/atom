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

      editor.insertText "no trailing newline"
      editor.getBuffer().save()
      expect(editor.getText()).toBe "no trailing newline"

    it "does not move the cursor when the new line is added", ->
      editor.insertText "foo"
      expect(editor.getCursorBufferPosition()).toEqual([0,3])
      editor.getBuffer().save()
      expect(editor.getText()).toBe "foo\n"
      expect(editor.getCursorBufferPosition()).toEqual([0,3])

  describe "GFM whitespace trimming", ->
    grammar = null

    beforeEach ->
      spyOn(syntax, "addGrammar").andCallThrough()
      atom.activatePackage("gfm")
      expect(syntax.addGrammar).toHaveBeenCalled()
      grammar = syntax.addGrammar.argsForCall[0][0]

    it "trims GFM text with a single space", ->
      editor.activeEditSession.setGrammar(grammar)
      editor.insertText "foo \nline break!"
      editor.getBuffer().save()
      expect(editor.getText()).toBe "foo\nline break!\n"

    it "leaves GFM text with double spaces alone", ->
      editor.activeEditSession.setGrammar(grammar)
      editor.insertText "foo  \nline break!"
      editor.getBuffer().save()
      expect(editor.getText()).toBe "foo  \nline break!\n"

    it "trims GFM text with a more than two spaces", ->
      editor.activeEditSession.setGrammar(grammar)
      editor.insertText "foo   \nline break!"
      editor.getBuffer().save()
      expect(editor.getText()).toBe "foo\nline break!\n"
