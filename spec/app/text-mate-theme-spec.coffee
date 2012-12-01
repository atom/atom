fs = require 'fs'
plist = require 'plist'
TextMateTheme = require 'app/text-mate-theme'

describe "TextMateTheme", ->
  theme = null
  beforeEach ->
    theme = TextMateTheme.getTheme('Twilight')

  describe "@getNames()", ->
    it "returns an array of available theme names", ->
      names = TextMateTheme.getNames()
      expect(names).toContain("Twilight")
      expect(names).toContain("Blackboard")

  describe "@activate(name)", ->
    it "activates a theme by name", ->
      spyOn theme, 'activate'
      TextMateTheme.activate('Twilight')
      expect(theme.activate).toHaveBeenCalled()

  describe ".activate()", ->
    it "applies the theme's stylesheet to the current window", ->
      spyOn window, 'applyStylesheet'
      theme.activate()
      expect(window.applyStylesheet).toHaveBeenCalledWith(theme.name, theme.getStylesheet())

  describe ".getRulesets()", ->
    rulesets = null

    beforeEach ->
      rulesets = theme.getRulesets()

    it "returns rulesets representing the theme's global style settings", ->
      expect(rulesets[0]).toEqual
        selector: '.editor'
        properties:
          'background-color': '#141414'
          'color': '#F8F8F8'

      expect(rulesets[1]).toEqual
        selector: '.editor.focused .cursor'
        properties:
          'border-color': '#A7A7A7'

      expect(rulesets[2]).toEqual
        selector: '.editor.focused .selection .region'
        properties:
          'background-color': "rgba(221, 240, 255, 0.2)"

    it "returns an array of objects representing the theme's scope selectors", ->
      expect(rulesets[11]).toEqual
        comment: "Invalid – Deprecated"
        selector: ".invalid.deprecated"
        properties:
          'color': "#D2A8A1"
          # 'font-style': 'italic'
          'text-decoration': 'underline'

      expect(rulesets[12]).toEqual
        comment: "Invalid – Illegal"
        selector: ".invalid.illegal"
        properties:
          'color': "#F8F8F8"
          'background-color': 'rgba(86, 45, 86, 0.75)'
