RootView = require 'root-view'
Editor = require 'editor'
ChildProcess = require 'child_process'

describe "link package", ->
  [editor] = []

  beforeEach ->
    atom.activatePackage('javascript-tmbundle', sync: true)
    atom.activatePackage('hyperlink-helper-tmbundle', sync: true)
    window.rootView = new RootView
    rootView.open('sample.js')
    atom.activatePackage('link')
    rootView.attachToDom()
    editor = rootView.getActiveView()
    editor.insertText("// http://github.com\n")

  describe "when the cursor is on a link", ->
    it "opens the link using the 'open' command", ->
      spyOn(ChildProcess, 'spawn')
      editor.trigger('link:open')
      expect(ChildProcess.spawn).not.toHaveBeenCalled()

      editor.setCursorBufferPosition([0,5])
      editor.trigger('link:open')

      expect(ChildProcess.spawn).toHaveBeenCalled()
      expect(ChildProcess.spawn.argsForCall[0][1][0]).toBe "http://github.com"
