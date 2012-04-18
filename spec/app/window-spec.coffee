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

  describe "requireStylesheet(path)", ->
    it "synchronously loads the stylesheet at the given path and installs a style tag for it in the head", ->
      $('head style').remove()
      expect($('head style').length).toBe 0
      requireStylesheet('atom.css')
      expect($('head style').length).toBe 1

      styleElt = $('head style')

      fullPath = require.resolve('atom.css')
      expect(styleElt.attr('path')).toBe fullPath
      expect(styleElt.text()).toBe fs.read(fullPath)

      requireStylesheet('atom.css')
      expect($('head style').length).toBe 1

  describe "before the window is unloaded", ->
    it "saves the serialized state of the root view to the atom object so it can be rehydrated after reload", ->
      expect(atom.rootViewStates[$windowNumber]).toBeUndefined()
      expectedState = window.rootView.serialize()
      $(window).trigger 'beforeunload'
      expect(atom.rootViewStates[$windowNumber]).toEqual expectedState

    it "unsubscribes from all buffers", ->
      editor1 = rootView.activeEditor()
      editor2 = editor1.splitRight()
      expect(window.rootView.editors().length).toBe 2

      $(window).trigger 'beforeunload'

      expect(editor1.buffer.subscriptionCount()).toBe 1 # buffer has a self-subscription for the undo manager
