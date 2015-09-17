LinesYardstick = require '../src/lines-yardstick'
MockLineNodesProvider = require './mock-line-nodes-provider'

describe "LinesYardstick", ->
  [editor, mockLineNodesProvider, builtLineNodes, linesYardstick] = []

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.project.open('sample.js').then (o) -> editor = o

    runs ->
      mockLineNodesProvider = new MockLineNodesProvider(editor)
      linesYardstick = new LinesYardstick(editor, mockLineNodesProvider)

  afterEach ->
    mockLineNodesProvider.dispose()

  it "converts screen positions to pixel positions", ->
    mockLineNodesProvider.setDefaultFont("14px monospace")

    conversionTable = [
      [[0, 0], {left: 0, top: editor.getLineHeightInPixels() * 0}]
      [[0, 3], {left: 24, top: editor.getLineHeightInPixels() * 0}]
      [[0, 4], {left: 32, top: editor.getLineHeightInPixels() * 0}]
      [[0, 5], {left: 40, top: editor.getLineHeightInPixels() * 0}]
      [[1, 0], {left: 0, top: editor.getLineHeightInPixels() * 1}]
      [[1, 1], {left: 0, top: editor.getLineHeightInPixels() * 1}]
      [[1, 6], {left: 48, top: editor.getLineHeightInPixels() * 1}]
      [[1, Infinity], {left: 240, top: editor.getLineHeightInPixels() * 1}]
    ]

    for [point, position] in conversionTable
      expect(
        linesYardstick.pixelPositionForScreenPosition(point)
      ).toEqual(position)

    mockLineNodesProvider.setFontForScopes(
      ["source.js", "storage.modifier.js"], "16px monospace"
    )
    linesYardstick.clearCache()

    conversionTable = [
      [[0, 0], {left: 0, top: editor.getLineHeightInPixels() * 0}]
      [[0, 3], {left: 30, top: editor.getLineHeightInPixels() * 0}]
      [[0, 4], {left: 38, top: editor.getLineHeightInPixels() * 0}]
      [[0, 5], {left: 46, top: editor.getLineHeightInPixels() * 0}]
      [[1, 0], {left: 0, top: editor.getLineHeightInPixels() * 1}]
      [[1, 1], {left: 0, top: editor.getLineHeightInPixels() * 1}]
      [[1, 6], {left: 54, top: editor.getLineHeightInPixels() * 1}]
      [[1, Infinity], {left: 246, top: editor.getLineHeightInPixels() * 1}]
    ]

    for [point, position] in conversionTable
      expect(
        linesYardstick.pixelPositionForScreenPosition(point)
      ).toEqual(position)

  it "does not compute the same position twice unless the cache gets cleared", ->
    mockLineNodesProvider.setDefaultFont("14px monospace")

    oldPosition1 = linesYardstick.pixelPositionForScreenPosition([0, 5])
    oldPosition2 = linesYardstick.pixelPositionForScreenPosition([1, 4])

    mockLineNodesProvider.setDefaultFont("16px monospace")

    expect(linesYardstick.pixelPositionForScreenPosition([0, 5])).toEqual(oldPosition1)
    expect(linesYardstick.pixelPositionForScreenPosition([1, 4])).toEqual(oldPosition2)

    linesYardstick.clearCache()

    expect(linesYardstick.pixelPositionForScreenPosition([0, 5])).not.toEqual(oldPosition1)
    expect(linesYardstick.pixelPositionForScreenPosition([1, 4])).not.toEqual(oldPosition2)
