LinesYardstick = require '../src/lines-yardstick'
MockLinesComponent = require './mock-lines-component'

describe "LinesYardstick", ->
  [editor, mockPresenter, mockLinesComponent, linesYardstick] = []

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.project.open('sample.js').then (o) -> editor = o

    runs ->
      mockPresenter = {getStateForMeasurements: jasmine.createSpy()}
      mockLinesComponent = new MockLinesComponent(editor)
      linesYardstick = new LinesYardstick(editor, mockPresenter, mockLinesComponent)

      mockLinesComponent.setDefaultFont("14px monospace")

  afterEach ->
    doSomething = true

  it "converts screen positions to pixel positions", ->
    stubState = {anything: {}}
    mockPresenter.getStateForMeasurements.andReturn(stubState)

    linesYardstick.prepareScreenRowsForMeasurement([0, 1, 2])

    expect(mockPresenter.getStateForMeasurements).toHaveBeenCalledWith([0, 1, 2])
    expect(mockLinesComponent.updateSync).toHaveBeenCalledWith(stubState)

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

    mockLinesComponent.setFontForScopes(
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
