TextBuffer = require 'text-buffer'
_ = require 'underscore-plus'
EditorPresenter = require '../src/editor-presenter'
Editor = require '../src/editor'

describe "DisplayStateManager", ->
  [buffer, editor, presenter] = []

  beforeEach ->
    @addMatchers(toHaveValues: ToHaveValuesMatcher)
    spyOn(EditorPresenter::, 'getLineTileSize').andReturn 5
    spyOn(EditorPresenter::, 'getGutterTileSize').andReturn 5

    buffer = new TextBuffer(filePath: atom.project.resolve('sample.js'))
    buffer.loadSync()
    buffer.insert([12, 3], '\n' + buffer.getText()) # repeat text so we have more lines

    editor = new Editor({buffer})
    editor.setLineHeightInPixels(10)
    editor.setDefaultCharWidth(10)
    editor.setHeight(100)
    editor.setWidth(500)

    presenter = new EditorPresenter(editor)

  afterEach ->
    editor.destroy()

  describe "tiles", ->
    describe "initial state", ->
      it "renders tiles that overlap the visible row range", ->
        expect(presenter).toHaveValues
          lineTiles:
            0:
              startRow: 0
              top: 0
              width: editor.getWidth()
              height: 5 * 10
              lineHeightInPixels: 10
              lines: editor.linesForScreenRows(0, 4)
            5:
              startRow: 5
              top: 50
              width: editor.getWidth()
              height: 5 * 10
              lineHeightInPixels: 10
              lines: editor.linesForScreenRows(5, 9)
            10:
              startRow: 10
              top: 100
              width: editor.getWidth()
              height: 5 * 10
              lineHeightInPixels: 10
              lines: editor.linesForScreenRows(10, 14)
          gutterTiles:
            0:
              startRow: 0
              top: 0
              height: 5 * 10
              lineHeightInPixels: 10
              lineNumbers: editor.lineNumbersForScreenRows(0, 4)
            5:
              startRow: 5
              top: 50
              height: 5 * 10
              lineHeightInPixels: 10
              lineNumbers: editor.lineNumbersForScreenRows(5, 9)
            10:
              startRow: 10
              top: 100
              height: 5 * 10
              lineHeightInPixels: 10
              lineNumbers: editor.lineNumbersForScreenRows(10, 14)

    describe "when the width is changed", ->
      it "updates the line tiles with the new width", ->
        editor.setWidth(700)
        expect(presenter.lineTiles).toHaveValues
          0:
            width: 700
          5:
            width: 700
          10:
            width: 700

    describe "when the height is changed", ->
      it "updates the rendered tiles to reflect the change", ->
        editor.setHeight(160)
        expect(presenter).toHaveValues
          lineTiles:
            0:
              startRow: 0
              top: 0
            5:
              startRow: 5
              top: 50
            10:
              startRow: 10
              top: 100
            15:
              startRow: 15
              top: 150
          gutterTiles:
            0:
              startRow: 0
              top: 0
            5:
              startRow: 5
              top: 50
            10:
              startRow: 10
              top: 100
            15:
              startRow: 15
              top: 150

        editor.setHeight(70)
        expect(presenter).toHaveValues
          lineTiles:
            0:
              startRow: 0
              top: 0
            5:
              startRow: 5
              top: 50
          gutterTiles:
            0:
              startRow: 0
              top: 0
            5:
              startRow: 5
              top: 50

    describe "when lineHeightInPixels changes", ->
      it "updates the rendered tiles to reflect the change", ->
        editor.setScrollTop(10)
        editor.setLineHeightInPixels(7)

        expect(presenter).toHaveValues
          lineTiles:
            0:
              startRow: 0
              top: 0 - 10
              height: 5 * 7
              lineHeightInPixels: 7
            5:
              startRow: 5
              top: 7 * 5 - 10
              height: 5 * 7
              lineHeightInPixels: 7
            10:
              startRow: 10
              top: 7 * 10 - 10
              height: 5 * 7
              lineHeightInPixels: 7
            15:
              startRow: 15
              top: 7 * 15 - 10
              height: 5 * 7
              lineHeightInPixels: 7
          gutterTiles:
            0:
              startRow: 0
              top: 0 - 10
              height: 5 * 7
              lineHeightInPixels: 7
            5:
              startRow: 5
              top: 7 * 5 - 10
              height: 5 * 7
              lineHeightInPixels: 7
            10:
              startRow: 10
              top: 7 * 10 - 10
              height: 5 * 7
              lineHeightInPixels: 7
            15:
              startRow: 15
              top: 7 * 15 - 10
              height: 5 * 7
              lineHeightInPixels: 7

    describe "when scrollTop changes", ->
      it "updates the rendered tiles to reflect the change", ->
        editor.setScrollTop(20)
        expect(presenter).toHaveValues
          lineTiles:
            0:
              top: -20
              lines: editor.linesForScreenRows(0, 4)
            5:
              top: 30
              lines: editor.linesForScreenRows(5, 9)
            10:
              top: 80
              lines: editor.linesForScreenRows(10, 14)
          gutterTiles:
            0:
              top: -20
              lineNumbers: editor.lineNumbersForScreenRows(0, 4)
            5:
              top: 30
              lineNumbers: editor.lineNumbersForScreenRows(5, 9)
            10:
              top: 80
              lineNumbers: editor.lineNumbersForScreenRows(10, 14)

        editor.setScrollTop(70)
        expect(presenter.lineTiles).toHaveValues
          5:
            top: -20
            lines: editor.linesForScreenRows(5, 9)
          10:
            top: 30
            lines: editor.linesForScreenRows(10, 14)
          15:
            top: 80
            lines: editor.linesForScreenRows(15, 19)

    describe "when scrollLeft changes", ->
      it "updates the rendered tiles to reflect the change", ->
        expect(presenter.lineTiles).toHaveValues
          0:
            left: 0
          5
            left: 0
          10:
            left: 0

        editor.setScrollLeft(30)
        expect(presenter.lineTiles).toHaveValues
          0:
            left: -30
          5:
            left: -30
          10:
            left: -30

  describe "lines", ->
    describe "initial state", ->
      it "breaks lines into tiles", ->
        expect(presenter.lineTiles).toHaveValues
          0:
            startRow: 0
            lines: editor.linesForScreenRows(0, 4)
          5:
            startRow: 5
            lines: editor.linesForScreenRows(5, 9)
          10:
            startRow: 10
            lines: editor.linesForScreenRows(10, 14)

    describe "when the screen lines change", ->
      it "updates the lines in the tiles to reflect the change", ->
        buffer.setTextInRange([[3, 5], [7, 0]], "a\nb\nc\nd")
        expect(presenter.lineTiles).toHaveValues
          0:
            startRow: 0
            lines: editor.linesForScreenRows(0, 4)
          5:
            startRow: 5
            lines: editor.linesForScreenRows(5, 9)
          10
            startRow: 10
            lines: editor.linesForScreenRows(10, 14)

  describe "line decorations", ->
    marker = null

    beforeEach ->
      marker = editor.markBufferRange([[3, 4], [5, 6]], invalidate: 'touch')

    describe "initial state", ->
      it "renders existing line decorations on the appropriate lines", ->
        decoration = editor.decorateMarker(marker, type: 'line', class: 'test')

        presenter = new EditorPresenter(editor)

        decorationsById = {}
        decorationsById[decoration.id] = decoration.getParams()
        expect(presenter.lineTiles).toHaveValues
          0:
            lineDecorations:
              3: decorationsById
              4: decorationsById
          5:
            lineDecorations:
              5: decorationsById

    describe "when a line decorations is added, updated, invalidated, or removed", ->
      it "updates the presented line decorations accordingly", ->
        decoration = editor.decorateMarker(marker, type: 'line', class: 'test')

        decorationsById = {}
        decorationsById[decoration.id] = decoration.getParams()
        expect(presenter.lineTiles).toHaveValues
          0:
            lineDecorations:
              3: decorationsById
              4: decorationsById
          5:
            lineDecorations:
              5: decorationsById

        marker.setBufferRange([[8, 4], [10, 6]])
        expect(presenter.lineTiles).toHaveValues
          0:
            lineDecorations:
              3: null
              4: null
          5:
            lineDecorations:
              5: null
              8: decorationsById
              9: decorationsById
          10:
            lineDecorations:
              10: decorationsById

        buffer.insert([8, 5], 'invalidate marker')
        expect(presenter.lineTiles).toHaveValues
          5:
            lineDecorations:
              8: null
              9: null
          10:
            lineDecorations:
              10: null

        buffer.undo()
        expect(presenter.lineTiles).toHaveValues
          5:
            lineDecorations:
              8: decorationsById
              9: decorationsById
          10:
            lineDecorations:
              10: decorationsById

        marker.destroy()
        expect(presenter.lineTiles).toHaveValues
          5:
            lineDecorations:
              8: null
              9: null
          10:
            lineDecorations:
              10: null

  describe "line numbers", ->
    describe "when the screen lines change", ->
      it "updates the line numbers to reflect the change", ->
        editor.createFold(4, 7)
        expect(presenter.gutterTiles).toHaveValues
          0:
            lineNumbers: editor.lineNumbersForScreenRows(0, 4)
          5:
            lineNumbers: editor.lineNumbersForScreenRows(5, 9)
          10:
            lineNumbers: editor.lineNumbersForScreenRows(10, 14)

      it "updates the maxLineNumberDigits if necessary", ->
        buffer.setText('')
        expect(presenter.gutterTiles).toHaveValues
          0:
            maxLineNumberDigits: 1

        buffer.setText([0..10].join('\n'))
        expect(presenter.gutterTiles).toHaveValues
          0:
            maxLineNumberDigits: 2
          5:
            maxLineNumberDigits: 2
          10:
            maxLineNumberDigits: 2

        buffer.delete([[8, 0], [Infinity, 0]])
        expect(presenter.gutterTiles).toHaveValues
          0:
            maxLineNumberDigits: 1
          5:
            maxLineNumberDigits: 1

ToHaveValuesMatcher = (expected) ->
  hasAllValues = true
  wrongValues = {}

  checkValues = (actual, expected, keyPath=[]) ->
   for key, expectedValue of expected
    key = numericKey if numericKey = parseInt(key)
    currentKeyPath = keyPath.concat([key])

    if expectedValue?
      if actual.hasOwnProperty(key)
        actualValue = actual[key]
        if expectedValue.constructor is Object and _.size(expectedValue) > 0
          checkValues(actualValue, expectedValue, currentKeyPath)
        else
          unless _.isEqual(actualValue, expectedValue)
            hasAllValues = false
            _.setValueForKeyPath(wrongValues, currentKeyPath.join('.'), {actualValue, expectedValue})
      else
        hasAllValues = false
        _.setValueForKeyPath(wrongValues, currentKeyPath.join('.'), {expectedValue})
    else
      actualValue = actual[key]
      if actualValue?
        hasAllValues = false
        _.setValueForKeyPath(wrongValues, currentKeyPath.join('.'), {actualValue, expectedValue})


  this.message = => "Object did not have expected values: #{jasmine.pp(wrongValues)}"
  checkValues(@actual, expected)
  console.warn "Object did not have expected values:", wrongValues unless hasAllValues
  hasAllValues
