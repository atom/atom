StyleSamplerComponent = require '../src/style-sampler-component'

fdescribe "StyleSamplerComponent", ->
  [editor, styleSamplerComponent, stylesContainerNode, functionsFonts, parametersFonts, defaultFonts] = []

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.project.open('sample.js').then (o) -> editor = o

    runs ->
      styleSamplerComponent = new StyleSamplerComponent(editor)
      stylesContainerNode = document.createElement("div")

      document.body.appendChild(styleSamplerComponent.getDomNode())
      document.body.appendChild(stylesContainerNode)

    waitsFor "iframe initialization", ->
      styleSamplerComponent.canMeasure()

    runs ->
      functionsFonts = []
      parametersFonts = []
      defaultFonts = []
      styleSamplerComponent.onScopesStyleSampled ({scopes, font}) ->
        scopeIdentifier = scopes.join()

        if scopeIdentifier.indexOf("entity.name.function") isnt -1
          functionsFonts.push(font)
        else if scopeIdentifier.indexOf("parameters") isnt -1
          parametersFonts.push(font)
        else
          defaultFonts.push(font)

  afterEach ->
    styleSamplerComponent.getDomNode().remove()
    stylesContainerNode.remove()

  it "samples font styles for the desired screen rows", ->
    styleElements = [
      styleElementWithSelectorAndFont(".entity.name.function", "Arial", "20px")
      styleElementWithSelectorAndFont(".parameters", "Helvetica", "32px")
    ]
    styleSamplerComponent.setDefaultFont("Times", "12px")
    for styleElement in styleElements
      styleSamplerComponent.addStyleElement(styleElement)

    styleSamplerComponent.sampleScreenRows([0])

    for functionFont in functionsFonts
      expect(functionFont).toEqual("normal normal normal normal 20px/normal Arial")

    for parameterFont in parametersFonts
      expect(parameterFont).toEqual("normal normal normal normal 32px/normal Helvetica")

    for defaultFont in defaultFonts
      expect(defaultFont).toEqual("normal normal normal normal 12px/normal Times")

  # it "samples a screen row twice only if the row has changed", ->
  # it "does not sample the same scopes twice", ->
  # it "invalidates samples when styles change", ->

  styleElementWithSelectorAndFont = (selector, fontFamily, fontSize) ->
    style = document.createElement("style")
    style.innerHTML = """
    #{selector} {
      font-family: #{fontFamily};
      font-size: #{fontSize};
    }
    """
    stylesContainerNode.appendChild(style)
    style
