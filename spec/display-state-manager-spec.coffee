Immutable = require 'immutable'
_ = require 'underscore-plus'
DisplayStateManager = require '../src/display-state-manager'
TextBuffer = require 'text-buffer'
Editor = require '../src/editor'

fdescribe "DisplayStateManager", ->
  [buffer, editor, stateManager] = []

  beforeEach ->
    @addMatchers
      toHaveValues: ToHaveValuesMatcher

    spyOn(DisplayStateManager::, 'getTileSize').andReturn 5

    buffer = new TextBuffer(filePath: atom.project.resolve('sample.js'))
    buffer.loadSync()
    buffer.insert([12, 3], '\n' + buffer.getText()) # repeat text so we have more lines

    editor = new Editor({buffer})
    editor.setLineHeightInPixels(10)
    editor.setDefaultCharWidth(10)
    editor.setHeight(100)
    editor.setWidth(500)

    stateManager = new DisplayStateManager(editor)

  afterEach ->
    editor.destroy()

  describe "initial state", ->
    it "breaks the visible lines into tiles", ->
      expect(stateManager.getState().get('tiles')).toHaveValues
        0:
          startRow: 0
          left: 0
          top: 0
          width: editor.getScrollWidth()
          height: 50
          lineHeightInPixels: 10
          lines: editor.linesForScreenRows(0, 4)
        5:
          startRow: 5
          left: 0
          top: 50
          width: editor.getScrollWidth()
          height: 50
          lineHeightInPixels: 10
          lines: editor.linesForScreenRows(5, 9)
        10:
          startRow: 10
          left: 0
          top: 100
          width: editor.getScrollWidth()
          height: 50
          lineHeightInPixels: 10
          lines: editor.linesForScreenRows(10, 14)

  describe "when the height is changed", ->
    it "updates the rendered tiles based on the new height", ->
      editor.setHeight(150)
      expect(stateManager.getState().get('tiles')).toHaveValues
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
      expect(stateManager.getState().get('tiles')).toHaveValues
        0:
          startRow: 0
          top: 0
        5:
          startRow: 5
          top: 50

  describe "when the width is changed", ->
    it "updates the tiles with the new width", ->
      editor.setWidth(700)
      expect(stateManager.getState().get('tiles')).toHaveValues
        0:
          width: 700
        5:
          width: 700
        10:
          width: 700

  describe "when the lineHeightInPixels is changed", ->
    it "updates the rendered tiles and assigns a new lineHeightInPixels value to all tiles", ->
      editor.setScrollTop(10)
      editor.setLineHeightInPixels(7)

      expect(stateManager.getState().get('tiles')).toHaveValues
        0:
          startRow: 0
          top: 0 - 10
          lineHeightInPixels: 7
        5:
          startRow: 5
          top: 7 * 5 - 10
          lineHeightInPixels: 7
        10:
          startRow: 10
          top: 7 * 10 - 10
          lineHeightInPixels: 7
        15:
          startRow: 15
          top: 7 * 15 - 10
          lineHeightInPixels: 7

  describe "when the editor is scrolled vertically", ->
    it "updates the visible tiles and their top positions", ->
      editor.setScrollTop(20)
      expect(stateManager.getState().get('tiles')).toHaveValues
        0:
          left: 0
          top: -20
        5:
          left: 0
          top: 30
        10:
          left: 0
          top: 80

      editor.setScrollTop(70)
      expect(stateManager.getState().get('tiles')).toHaveValues
        5:
          left: 0
          top: -20
        10:
          left: 0
          top: 30
        15:
          left: 0
          top: 80

  describe "when the editor is scrolled horizontally", ->
    it "updates the left position of the visible tiles", ->
      editor.setScrollLeft(30)
      expect(stateManager.getState().get('tiles')).toHaveValues
        0:
          left: -30
        5:
          left: -30
        10:
          left: -30

  describe "when the lines are changed", ->
    it "updates the lines in the tiles", ->
      buffer.setTextInRange([[3, 5], [7, 0]], "a\nb\nc\nd")
      expect(stateManager.getState().get('tiles')).toHaveValues
        0:
          lines: editor.linesForScreenRows(0, 4)
        5:
          lines: editor.linesForScreenRows(5, 9)
        10:
          lines: editor.linesForScreenRows(10, 14)

  describe "line decorations", ->
    marker = null

    beforeEach ->
      marker = editor.markBufferRange([[3, 4], [5, 6]], invalidate: 'touch')

    it "updates the display state when decorations are added, updated, invalidated, or removed", ->
      decoration = editor.decorateMarker(marker, type: 'line', class: 'test')

      decorationParamsById = {}
      decorationParamsById[decoration.id] = decoration.getParams()
      expect(stateManager.getState().get('tiles')).toHaveValues
        0:
          lineDecorations:
            3: decorationParamsById
            4: decorationParamsById
        5:
          lineDecorations:
            5: decorationParamsById

      marker.setBufferRange([[8, 4], [10, 6]])
      expect(stateManager.getState().get('tiles')).toHaveValues
        0:
          lineDecorations:
            3: null
            4: null
        5:
          lineDecorations:
            5: null
            8: decorationParamsById
            9: decorationParamsById
        10:
          lineDecorations:
            10: decorationParamsById

      buffer.insert([8, 5], 'invalidate marker')
      expect(stateManager.getState().get('tiles')).toHaveValues
        5:
          lineDecorations:
            8: null
            9: null
        10:
          lineDecorations:
            10: null

      buffer.undo()
      expect(stateManager.getState().get('tiles')).toHaveValues
        5:
          lineDecorations:
            8: decorationParamsById
            9: decorationParamsById
        10:
          lineDecorations:
            10: decorationParamsById

      marker.destroy()
      expect(stateManager.getState().get('tiles')).toHaveValues
        5:
          lineDecorations:
            8: null
            9: null
        10:
          lineDecorations:
            10: null

    it "renders line decorations in the initial state", ->
      decoration = editor.decorateMarker(marker, type: 'line', class: 'test')

      newStateManager = new DisplayStateManager(editor)

      decorationParamsById = {}
      decorationParamsById[decoration.id] = decoration.getParams()
      expect(stateManager.getState().get('tiles')).toHaveValues
        0:
          lineDecorations:
            3: decorationParamsById
            4: decorationParamsById
        5:
          lineDecorations:
            5: decorationParamsById

    describe "when the decoration's 'onlyHead' property is true", ->
      it "only applies the decoration to lines containing the marker's head", ->
        decoration = editor.decorateMarker(marker, type: 'line', class: 'only-head', onlyHead: true)
        decorationParamsById = {}
        decorationParamsById[decoration.id] = decoration.getParams()

        expect(stateManager.getState().get('tiles')).toHaveValues
          0:
            lineDecorations:
              3: null
              4: null
          5:
            lineDecorations:
              5: decorationParamsById

    describe "when the decoration's 'onlyEmpty' property is true", ->
      it "only applies the decoration if the marker is empty", ->
        decoration = editor.decorateMarker(marker, type: 'line', class: 'only-empty', onlyEmpty: true)
        decorationParamsById = {}
        decorationParamsById[decoration.id] = decoration.getParams()

        expect(stateManager.getState().get('tiles')).toHaveValues
          0:
            lineDecorations:
              3: null
              4: null
          5:
            lineDecorations:
              5: null

        marker.clearTail()
        expect(stateManager.getState().get('tiles')).toHaveValues
          0:
            lineDecorations:
              3: null
              4: null
          5:
            lineDecorations:
              5: decorationParamsById

    describe "when the decoration's 'onlyNonEmpty' property is true", ->
      it "only applies the decoration if the marker is non-empty", ->
        decoration = editor.decorateMarker(marker, type: 'line', class: 'only-non-empty', onlyNonEmpty: true)
        decorationParamsById = {}
        decorationParamsById[decoration.id] = decoration.getParams()

        expect(stateManager.getState().get('tiles')).toHaveValues
          0:
            lineDecorations:
              3: decorationParamsById
              4: decorationParamsById
          5:
            lineDecorations:
              5: decorationParamsById

        marker.clearTail()
        expect(stateManager.getState().get('tiles')).toHaveValues
          0:
            lineDecorations:
              3: null
              4: null
          5:
            lineDecorations:
              5: null

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


  notText = if @isNot then " not" else ""
  this.message = => "Immutable object did not have expected values: #{jasmine.pp(wrongValues)}"
  checkValues(@actual.toJS(), expected)
  console.warn "Invalid values:", wrongValues unless hasAllValues
  hasAllValues
