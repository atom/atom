$ = require 'jquery'
fs = require 'fs'

describe "Window", ->
  beforeEach ->
    window.startup()

  afterEach ->
    window.shutdown()
    delete atom.rootViewStates[$windowNumber]
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
      rootView.getActiveEditor().insertText("hi")
      spyOn($native, "alert")
      spyOn($native, "reload")
      window.reload()
      expect($native.reload).not.toHaveBeenCalled()
      expect($native.alert).toHaveBeenCalled()

  describe "requireStylesheet(path)", ->
    it "synchronously loads the stylesheet at the given path and installs a style tag for it in the head", ->
      $('head style[path*="atom.css"]').remove()
      lengthBefore = $('head style').length
      requireStylesheet('atom.css')
      expect($('head style').length).toBe lengthBefore + 1

      styleElt = $('head style[path*="atom.css"]')

      fullPath = require.resolve('atom.css')
      expect(styleElt.attr('path')).toBe fullPath
      expect(styleElt.text()).toBe fs.read(fullPath)

      # doesn't append twice
      requireStylesheet('atom.css')
      expect($('head style').length).toBe lengthBefore + 1

  describe "before the window is unloaded", ->
    it "saves the serialized state of the root view to the atom object so it can be rehydrated after reload", ->
      expect(atom.rootViewStates[$windowNumber]).toBeUndefined()
      expectedState = window.rootView.serialize()
      $(window).trigger 'beforeunload'
      expect(atom.rootViewStates[$windowNumber]).toEqual JSON.stringify(expectedState)

    it "unsubscribes from all buffers", ->
      editor1 = rootView.getActiveEditor()
      editor2 = editor1.splitRight()
      expect(window.rootView.editors().length).toBe 2

      $(window).trigger 'beforeunload'

      expect(editor1.buffer.subscriptionCount()).toBe 1 # buffer has a self-subscription for the undo manager
