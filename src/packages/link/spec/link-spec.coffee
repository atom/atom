RootView = require 'root-view'
Editor = require 'editor'
shell = require 'shell'

describe "link package", ->
  [editor] = []

  beforeEach ->
    atom.activatePackage('javascript.tmbundle', sync: true)
    atom.activatePackage('hyperlink-helper.tmbundle', sync: true)
    window.rootView = new RootView
    rootView.open('sample.js')
    atom.activatePackage('link')
    rootView.attachToDom()
    editor = rootView.getActiveView()
    editor.insertText("// http://github.com\n")

  describe "when the cursor is on a link", ->
    it "opens the link using the 'open' command", ->
      spyOn(shell, 'openExternal')
      editor.trigger('link:open')
      expect(shell.openExternal).not.toHaveBeenCalled()

      editor.setCursorBufferPosition([0,5])
      editor.trigger('link:open')

      expect(shell.openExternal).toHaveBeenCalled()
      expect(shell.openExternal.argsForCall[0]).toBe "http://github.com"
