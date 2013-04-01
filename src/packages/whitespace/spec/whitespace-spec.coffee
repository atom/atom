RootView = require 'root-view'
fs = require 'fs-utils'

describe "Whitespace", ->
  [editor, path] = []

  beforeEach ->
    path = "/tmp/atom-whitespace.txt"
    fs.write(path, "")
    window.rootView = new RootView
    rootView.open(path)

    atom.activatePackage('whitespace')

    rootView.focus()
    editor = rootView.getActiveView()

  afterEach ->
    fs.remove(path) if fs.exists(path)

  it "strips trailing whitespace before an editor saves a buffer", ->
    spyOn(fs, 'write')

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

  describe "whitespace.singleTrailingNewline config", ->
    [originalConfigValue] = []
    beforeEach ->
      originalConfigValue = config.get("whitespace.singleTrailingNewline")
      config.set("whitespace.singleTrailingNewline", true)
      config.update()

    afterEach ->
      config.set("whitespace.singleTrailingNewline", originalConfigValue)
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
