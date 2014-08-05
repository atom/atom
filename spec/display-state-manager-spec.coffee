Immutable = require 'immutable'
_ = require 'underscore-plus'
DisplayStateManager = require '../src/display-state-manager'
TextBuffer = require 'text-buffer'
Editor = require '../src/editor'

fdescribe "DisplayStateManager", ->
  [editor, stateManager] = []

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
      expect(stateManager.getState().get('tiles').toJS()).toEqual
        0:
          startRow: 0
          left: 0
          top: 0
          width: editor.getScrollWidth()
          height: 50
          lines: editor.linesForScreenRows(0, 4)
          lineHeightInPixels: 10
        5:
          startRow: 5
          left: 0
          top: 50
          width: editor.getScrollWidth()
          height: 50
          lines: editor.linesForScreenRows(5, 9)
          lineHeightInPixels: 10
        10:
          startRow: 10
          left: 0
          top: 100
          width: editor.getScrollWidth()
          height: 50
          lines: editor.linesForScreenRows(10, 14)
          lineHeightInPixels: 10

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
          top: 0
        5:
          left: -30
          top: 50
        10:
          left: -30
          top: 100

ToHaveValuesMatcher = (expected) ->
  hasAllValues = true
  wrongValues = {}

  checkValues = (actual, expected, keyPath=[]) ->
   for key, expectedValue of expected
     key = numericKey if numericKey = parseInt(key)
     currentKeyPath = keyPath.concat([key])

     if actual.hasOwnProperty(key)
       actualValue = actual[key]
       if expectedValue.constructor is Object
         checkValues(actualValue, expectedValue, currentKeyPath)
       else
         unless _.isEqual(actualValue, expectedValue)
           hasAllValues = false
           _.setValueForKeyPath(wrongValues, currentKeyPath.join('.'), {actualValue, expectedValue})
     else
       hasAllValues = false
       _.setValueForKeyPath(wrongValues, currentKeyPath.join('.'), {expectedValue})

  notText = if @isNot then " not" else ""
  this.message = => "Immutable object did not have expected values: #{jasmine.pp(wrongValues)}"
  checkValues(@actual.toJS(), expected)
  console.log wrongValues unless hasAllValues
  hasAllValues
