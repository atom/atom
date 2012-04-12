$ = require 'jquery'
fs = require 'fs'

describe "Window", ->
  describe "keybindings", ->
    beforeEach ->
      window.startup()

    afterEach ->
      window.shutdown()

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
      afterEach ->
        delete atom.rootViewStates[$windowNumber]

      it "saves the serialized state of the root view to the atom object so it can be rehydrated after reload", ->
        expect(atom.rootViewStates[$windowNumber]).toBeUndefined()
        $(window).trigger 'beforeunload'
        expect(atom.rootViewStates[$windowNumber]).toEqual window.rootView.serialize()


