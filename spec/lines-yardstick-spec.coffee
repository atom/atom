LinesYardstick = require '../src/lines-yardstick'

fdescribe "LinesYardstick", ->
  [editor, linesYardstick, lineHeightInPixels] = []

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.project.open('sample.js').then (o) -> editor = o

    runs ->
      linesYardstick = new LinesYardstick(editor)
      lineHeightInPixels = 12
      editor.setLineHeightInPixels(lineHeightInPixels)

  it "measures lines using the default font", ->
    linesYardstick.setDefaultFont("Helvetica", "36px")

    conversionTable = [
      [[2, 8], {left: 80, top: 2 * lineHeightInPixels}]
      [[3, 0], {left: 0, top: 3 * lineHeightInPixels}]
      [[4, 4], {left: 40, top: 4 * lineHeightInPixels}]
      [[8, 10], {left: 134, top: 8 * lineHeightInPixels}]
    ]

    for [screenPosition, pixelPosition] in conversionTable
      expect(
        linesYardstick.pixelPositionForScreenPosition(screenPosition)
      ).toEqual(pixelPosition)

  it "measures lines using stored fonts for scopes (falling back to the default font when missing)", ->
    linesYardstick.setDefaultFont("Helvetica", "36px")
    linesYardstick.setFontForScopes(
      ["source.js", "keyword.control.js"], "12px Arial"
    )
    linesYardstick.setFontForScopes(
      ["source.js", "meta.brace.round.js"], "24px Tahoma"
    )

    conversionTable = [
      [[2, 8], {left: 65, top: 2 * lineHeightInPixels}]
      [[3, 0], {left: 0, top: 3 * lineHeightInPixels}]
      [[4, 4], {left: 40, top: 4 * lineHeightInPixels}]
      [[8, 10], {left: 72, top: 8 * lineHeightInPixels}]
    ]

    for [screenPosition, pixelPosition] in conversionTable
      expect(
        linesYardstick.pixelPositionForScreenPosition(screenPosition)
      ).toEqual(pixelPosition)

  it "clears stored fonts for scopes when fonts are invalidated", ->
    linesYardstick.setDefaultFont("Helvetica", "36px")
    linesYardstick.setFontForScopes(
      ["source.js", "keyword.control.js"], "12px Arial"
    )
    linesYardstick.setFontForScopes(
      ["source.js", "meta.brace.round.js"], "24px Tahoma"
    )

    linesYardstick.clearFontsForScopes()

    conversionTable = [
      [[2, 8], {left: 80, top: 2 * lineHeightInPixels}]
      [[3, 0], {left: 0, top: 3 * lineHeightInPixels}]
      [[4, 4], {left: 40, top: 4 * lineHeightInPixels}]
      [[8, 10], {left: 134, top: 8 * lineHeightInPixels}]
    ]

    for [screenPosition, pixelPosition] in conversionTable
      expect(
        linesYardstick.pixelPositionForScreenPosition(screenPosition)
      ).toEqual(pixelPosition)
