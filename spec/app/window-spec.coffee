$ = require 'jquery'
fs = require 'fs'

describe "Window", ->
  beforeEach ->
    window.attachRootView(require.resolve('fixtures'))

  afterEach ->
    window.shutdown()
    atom.setRootViewStateForPath(rootView.project.getPath(), null)
    $(window).off 'beforeunload'

  describe ".close()", ->
    it "is triggered by the 'close' event", ->
      spyOn window, 'close'
      $(window).trigger 'close'
      expect(window.close).toHaveBeenCalled()

  describe ".reload()", ->
    it "returns false when no buffers are modified", ->
      spyOn($native, "reload")
      window.reload()
      expect($native.reload).toHaveBeenCalled()

    it "shows alert when a modifed buffer exists", ->
      rootView.open('sample.js')
      rootView.getActiveEditor().insertText("hi")
      spyOn(atom, "confirm")
      spyOn($native, "reload")
      window.reload()
      expect($native.reload).not.toHaveBeenCalled()
      expect(atom.confirm).toHaveBeenCalled()

  describe "requireStylesheet(path)", ->
    it "synchronously loads the stylesheet at the given path and installs a style tag for it in the head", ->
      $('head style[id*="atom.css"]').remove()
      lengthBefore = $('head style').length
      requireStylesheet('atom.css')
      expect($('head style').length).toBe lengthBefore + 1

      styleElt = $('head style[id*="atom.css"]')

      fullPath = require.resolve('atom.css')
      expect(styleElt.attr('id')).toBe fullPath
      expect(styleElt.text()).toBe fs.read(fullPath)

      # doesn't append twice
      requireStylesheet('atom.css')
      expect($('head style').length).toBe lengthBefore + 1

  describe "before the window is unloaded", ->
    it "saves the serialized state of the root view to the atom object so it can be rehydrated after reload", ->
      expect(atom.getRootViewStateForPath(window.rootView.project.getPath())).toBeUndefined()
      expectedState = JSON.parse(JSON.stringify(window.rootView.serialize())) # JSON.stringify removes keys with undefined values
      $(window).trigger 'beforeunload'
      expect(atom.getRootViewStateForPath(window.rootView.project.getPath())).toEqual expectedState

    it "unsubscribes from all buffers", ->
      rootView.open('sample.js')
      editor1 = rootView.getActiveEditor()
      editor2 = editor1.splitRight()
      expect(window.rootView.getEditors().length).toBe 2

      $(window).trigger 'beforeunload'

      expect(editor1.getBuffer().subscriptionCount()).toBe 0
