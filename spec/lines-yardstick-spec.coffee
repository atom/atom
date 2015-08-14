LinesYardstick = require '../src/lines-yardstick'
{Point} = require 'text-buffer'
{isEqual} = require 'underscore-plus'

describe "LinesYardstick", ->
  [editor, linesYardstick, lineHeightInPixels] = []

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.project.open('sample.js').then (o) -> editor = o

    runs ->
      linesYardstick = new LinesYardstick editor, (scopes) ->
        if isEqual(scopes, ["source.js", "keyword.control.js"])
          "12px Arial"
        else if isEqual(scopes, ["source.js", "meta.brace.round.js"])
          "24px Tahoma"
        else
          "36px Helvetica"

      lineHeightInPixels = 12
      editor.setLineHeightInPixels(lineHeightInPixels)

  it "measures lines using provider's font for scopes", ->
    conversionTable = [
      [[2, 8], {left: 65, top: 2 * lineHeightInPixels}]
      [[3, 0], {left: 0, top: 3 * lineHeightInPixels}]
      [[4, 4], {left: 40, top: 4 * lineHeightInPixels}]
      [[8, 10], {left: 72, top: 8 * lineHeightInPixels}]
      [[9, 4], {left: 42, top: 9 * lineHeightInPixels}]
    ]

    for [screenPosition, pixelPosition] in conversionTable
      expect(
        linesYardstick.pixelPositionForScreenPosition(screenPosition)
      ).toEqual(pixelPosition)
      expect(
        linesYardstick.screenPositionForPixelPosition(pixelPosition)
      ).toEqual(Point.fromObject(screenPosition))
