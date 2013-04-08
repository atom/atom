fsUtils = require 'fs-utils'
plist = require 'plist'
TextMateTheme = require 'text-mate-theme'
Theme = require 'theme'

describe "TextMateTheme", ->
  [theme, themePath] = []

  beforeEach ->
    themePath = fsUtils.resolveOnLoadPath(fsUtils.join('fixtures', 'test.tmTheme'))
    theme = Theme.load(themePath)

  afterEach ->
    theme.deactivate()

  describe ".getRulesets()", ->
    rulesets = null

    beforeEach ->
      rulesets = theme.getRulesets()

    it "returns rulesets representing the theme's global style settings", ->
      expect(rulesets[0]).toEqual
        selector: '.editor, .editor .gutter'
        properties:
          'background-color': '#141414'
          'color': '#F8F8F8'

      expect(rulesets[1]).toEqual
        selector: '.editor.is-focused .cursor'
        properties:
          'border-color': '#A7A7A7'

      expect(rulesets[2]).toEqual
        selector: '.editor.is-focused .selection .region'
        properties:
          'background-color': "rgba(221, 240, 255, 0.2)"

    it "returns an array of objects representing the theme's scope selectors", ->
      expect(rulesets[12]).toEqual
        comment: "Invalid – Deprecated"
        selector: ".invalid.deprecated"
        properties:
          'color': "#D2A8A1"
          'font-style': 'italic'
          'text-decoration': 'underline'

      expect(rulesets[13]).toEqual
        comment: "Invalid – Illegal"
        selector: ".invalid.illegal"
        properties:
          'color': "#F8F8F8"
          'background-color': 'rgba(86, 45, 86, 0.75)'
