$ = require 'jquery'
fs = require 'fs'
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

      themePath = require.resolve(fs.join('fixtures', 'test.tmTheme'))
      theme = Theme.load(themePath)
      expect($(".editor").css("background-color")).toBe("rgb(20, 20, 20)")

  describe "AtomTheme", ->
    it "Loads and applies css from package.json in the correct order", ->
      expect($(".editor").css("padding-top")).not.toBe("101px")
      expect($(".editor").css("padding-right")).not.toBe("102px")
      expect($(".editor").css("padding-bottom")).not.toBe("103px")

      themePath = require.resolve(fs.join('fixtures', 'test-atom-theme'))
      theme = Theme.load(themePath)
      expect($(".editor").css("padding-top")).toBe("101px")
      expect($(".editor").css("padding-right")).toBe("102px")
      expect($(".editor").css("padding-bottom")).toBe("103px")
