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
