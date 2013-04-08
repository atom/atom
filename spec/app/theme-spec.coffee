$ = require 'jquery'
fsUtils = require 'fs-utils'
Theme = require 'theme'

describe "@load(name)", ->
  theme = null

  beforeEach ->
    $("#jasmine-content").append $("<div class='editor'></div>")

  afterEach ->
    theme.deactivate()

  describe "TextMateTheme", ->
    it "applies the theme's stylesheet to the current window", ->
      expect($(".editor").css("background-color")).not.toBe("rgb(20, 20, 20)")

      themePath = fsUtils.resolveOnLoadPath(fsUtils.join('fixtures', 'test.tmTheme'))
      theme = Theme.load(themePath)
      expect($(".editor").css("background-color")).toBe("rgb(20, 20, 20)")

  describe "AtomTheme", ->
    describe "when the theme is a file", ->
      it "loads and applies css", ->
        expect($(".editor").css("padding-bottom")).not.toBe "1234px"
        themePath = project.resolve('themes/theme-stylesheet.css')
        theme = Theme.load(themePath)
        expect($(".editor").css("padding-top")).toBe "1234px"

      it "parses, loads and applies less", ->
        expect($(".editor").css("padding-bottom")).not.toBe "1234px"
        themePath = project.resolve('themes/theme-stylesheet.less')
        theme = Theme.load(themePath)
        expect($(".editor").css("padding-top")).toBe "4321px"

    describe "when the theme contains a package.json file", ->
      it "loads and applies stylesheets from package.json in the correct order", ->
        expect($(".editor").css("padding-top")).not.toBe("101px")
        expect($(".editor").css("padding-right")).not.toBe("102px")
        expect($(".editor").css("padding-bottom")).not.toBe("103px")

        themePath = project.resolve('themes/theme-with-package-file')
        theme = Theme.load(themePath)
        expect($(".editor").css("padding-top")).toBe("101px")
        expect($(".editor").css("padding-right")).toBe("102px")
        expect($(".editor").css("padding-bottom")).toBe("103px")

    describe "when the theme does not contain a package.json file and is a directory", ->
      it "loads all stylesheet files in the directory", ->
        expect($(".editor").css("padding-top")).not.toBe "10px"
        expect($(".editor").css("padding-right")).not.toBe "20px"
        expect($(".editor").css("padding-bottom")).not.toBe "30px"

        themePath = project.resolve('themes/theme-without-package-file')
        theme = Theme.load(themePath)
        expect($(".editor").css("padding-top")).toBe "10px"
        expect($(".editor").css("padding-right")).toBe "20px"
        expect($(".editor").css("padding-bottom")).toBe "30px"
