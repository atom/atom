LinesYardstick = require '../src/lines-yardstick'
{Point} = require 'text-buffer'

describe "LinesYardstick", ->
  [linesYardstick, editor, styleNodesToRemove] = []

  styleSheetWithSelectorAndFont = (selector, font) ->
    styleNode = document.createElement("style")
    styleNode.innerHTML = """
    #{selector} {
      font: #{font};
    }
    """
    document.body.appendChild(styleNode)
    styleNodesToRemove ?= []
    styleNodesToRemove.push(styleNode)
    styleNode

  cleanupStyleSheets = ->
    styleNode.remove() while styleNode = styleNodesToRemove?.pop()

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.project.open('sample.js').then (o) -> editor = o

    runs ->
      linesYardstick = new LinesYardstick(editor)
      document.body.appendChild(linesYardstick.getDomNode())

    waitsFor ->
      linesYardstick.canMeasure()

  afterEach ->
    linesYardstick.getDomNode().remove()
    cleanupStyleSheets()

  describe "::buildDomNodesForScreenRows(screenRows)", ->
    it "asks for a line HTML only once", ->
      requestedLinesByScreenRow = {}
      linesYardstick.setLineHtmlProvider (screenRow, line) ->
        requestedLinesByScreenRow[screenRow] ?= 0
        requestedLinesByScreenRow[screenRow]++

        "<div></div>"

      linesYardstick.buildDomNodesForScreenRows([0, 1, 2])
      linesYardstick.buildDomNodesForScreenRows([1, 2, 3])
      linesYardstick.buildDomNodesForScreenRows([3, 4, 5])

      expect(Object.keys(requestedLinesByScreenRow).length).not.toBe(0)
      for screenRow, requestsCount of requestedLinesByScreenRow
        expect(requestsCount).toBe(1)

  describe "::leftPixelPositionForScreenPosition(point)", ->
    it "measure positions based on stylesheets and default font", ->
      editor.setText("hello\nworld\n")
      linesYardstick.setDefaultFont("monospace", "14px")
      linesYardstick.setLineHtmlProvider (screenRow, line) ->
        if screenRow is 0
          "<div>he<span class='bigger'>l</span>lo</div>"
        else if screenRow is 1
          "<div>world</div>"
        else
          throw new Error("This screen row shouldn't have been requested.")

      linesYardstick.buildDomNodesForScreenRows([0, 1])

      conversionTable = [
        [new Point(0, 0), {left: 0, top: editor.getLineHeightInPixels() * 0}]
        [new Point(0, 1), {left: 8, top: editor.getLineHeightInPixels() * 0}]
        [new Point(0, 3), {left: 24, top: editor.getLineHeightInPixels() * 0}]
        [new Point(1, 0), {left: 0, top: editor.getLineHeightInPixels() * 1}]
        [new Point(1, 1), {left: 8, top: editor.getLineHeightInPixels() * 1}]
        [new Point(1, 4), {left: 32, top: editor.getLineHeightInPixels() * 1}]
      ]

      for [point, position] in conversionTable
        expect(
          linesYardstick.pixelPositionForScreenPosition(point)
        ).toEqual(position)

      linesYardstick.resetStyleSheets([
        styleSheetWithSelectorAndFont(".bigger", "16px monospace")
      ])

      conversionTable = [
        [new Point(0, 0), {left: 0, top: 0 * editor.getLineHeightInPixels()}]
        [new Point(0, 1), {left: 8, top: 0 * editor.getLineHeightInPixels()}]
        [new Point(0, 3), {left: 26, top: 0 * editor.getLineHeightInPixels()}]
        [new Point(1, 0), {left: 0, top: 1 * editor.getLineHeightInPixels()}]
        [new Point(1, 1), {left: 8, top: 1 * editor.getLineHeightInPixels()}]
        [new Point(1, 4), {left: 32, top: 1 * editor.getLineHeightInPixels()}]
      ]

      for [point, position] in conversionTable
        expect(
          linesYardstick.pixelPositionForScreenPosition(point)
        ).toEqual(position)
