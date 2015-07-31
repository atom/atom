StyleSamplerComponent = require '../src/style-sampler-component'

describe "StyleSamplerComponent", ->
  [editor, styleSamplerComponent, functionsFonts, parametersFonts, defaultFonts, appendedStyleSheets] = []

  styleWithSelectorAndFont = (selector, fontFamily, fontSize) ->
    style = document.createElement("style")
    style.innerHTML = """
    #{selector} {
      font-family: #{fontFamily};
      font-size: #{fontSize};
      line-height: normal;
    }
    """
    style

  appendStyleSheets = ->
    appendedStyleSheets ?= []

    for styleSheet in arguments
      appendedStyleSheets.push(styleSheet)
      document.head.appendChild(styleSheet)

  removeAppendedStyleSheets = ->
    for styleSheet in appendedStyleSheets
      styleSheet.remove()

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.project.open('sample.js').then (o) -> editor = o

    runs ->
      styleSamplerComponent = new StyleSamplerComponent(editor)

      document.body.appendChild(styleSamplerComponent.getDomNode())

      functionsFonts = []
      parametersFonts = []
      defaultFonts = []

      styleSamplerComponent.onDidInvalidateStyles ->
        functionsFonts.length = 0
        parametersFonts.length = 0
        defaultFonts.length = 0

      styleSamplerComponent.onDidSampleScopesStyle ({scopes, font}) ->
        scopeIdentifier = scopes.join()

        if scopeIdentifier.indexOf("entity.name.function") isnt -1
          functionsFonts.push(font)
        else if scopeIdentifier.indexOf("parameters") isnt -1
          parametersFonts.push(font)
        else
          defaultFonts.push(font)

      appendStyleSheets(
        styleWithSelectorAndFont("body", "Times", "12px"),
        styleWithSelectorAndFont(".entity.name.function", "Arial", "20px"),
        styleWithSelectorAndFont(".parameters", "Helvetica", "32px")
      )

  afterEach ->
    styleSamplerComponent.getDomNode().remove()
    removeAppendedStyleSheets()

  describe "::sampleScreenRows()", ->
    it "samples font styles for the desired screen rows", ->
      styleSamplerComponent.sampleScreenRows([0])

      expect(functionsFonts.length).toBeGreaterThan(0)
      expect(parametersFonts.length).toBeGreaterThan(0)
      expect(defaultFonts.length).toBeGreaterThan(0)

      for functionsFont in functionsFonts
        expect(functionsFont).toEqual("normal normal normal normal 20px/normal Arial")

      for parametersFont in parametersFonts
        expect(parametersFont).toEqual("normal normal normal normal 32px/normal Helvetica")

      for defaultFont in defaultFonts
        expect(defaultFont).toEqual("normal normal normal normal 12px/normal Times")

    it "samples the same scopes exactly once", ->
      fontsByScopesIdentifier = {}
      styleSamplerComponent.onDidSampleScopesStyle ({scopes, font}) ->
        scopesIdentifier = scopes.join()
        fontsByScopesIdentifier[scopesIdentifier] ?= []
        fontsByScopesIdentifier[scopesIdentifier].push(font)

      styleSamplerComponent.sampleScreenRows([0..5])

      expect(Object.keys(fontsByScopesIdentifier).length).toBeGreaterThan(0)
      for scopesIdentifier, fonts of fontsByScopesIdentifier
        expect(fonts.length).toBe(1)

  describe "::invalidateStyles()", ->
    it "clears cached styles", ->
      styleSamplerComponent.sampleScreenRows([0])

      expect(functionsFonts.length).toBeGreaterThan(0)
      expect(parametersFonts.length).toBeGreaterThan(0)
      expect(defaultFonts.length).toBeGreaterThan(0)

      appendStyleSheets(styleWithSelectorAndFont("body", "Arial", "12px"))
      styleSamplerComponent.sampleScreenRows([0])
      for defaultFont in defaultFonts
        expect(defaultFont).toEqual("normal normal normal normal 12px/normal Times")

      styleSamplerComponent.invalidateStyles()
      styleSamplerComponent.sampleScreenRows([0])

      expect(defaultFonts.length).toBeGreaterThan(0)
      for defaultFont in defaultFonts
        expect(defaultFont).toEqual("normal normal normal normal 12px/normal Arial")
