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

      expect(styleSamplerComponent.fontForScopes(["source.js"])).toBe("normal normal normal normal 12px/normal Times")
      expect(styleSamplerComponent.fontForScopes(["source.js", "meta.function.js", "entity.name.function.js"])).toBe("normal normal normal normal 20px/normal Arial")
      expect(styleSamplerComponent.fontForScopes(["source.js", "meta.function.js", "punctuation.definition.parameters.begin.js"])).toBe("normal normal normal normal 32px/normal Helvetica")

  describe "::invalidateStyles()", ->
    it "clears cached styles", ->
      samplesCount = 0
      styleSamplerComponent.onDidSampleScopes -> samplesCount++

      styleSamplerComponent.sampleScreenRows([0])
      appendStyleSheets(styleWithSelectorAndFont("body", "Arial", "12px"))
      styleSamplerComponent.sampleScreenRows([0])

      expect(samplesCount).toBe(1)
      expect(styleSamplerComponent.fontForScopes(["source.js"])).toBe("normal normal normal normal 12px/normal Times")

      styleSamplerComponent.invalidateStyles()
      styleSamplerComponent.sampleScreenRows([0])

      expect(samplesCount).toBe(2)
      expect(styleSamplerComponent.fontForScopes(["source.js"])).toBe("normal normal normal normal 12px/normal Arial")
