$ = require 'jquery'
RootView = require 'root-view'
EditorStats = require 'editor-stats/src/editor-stats-view'

fdescribe "EditorStats", ->
  [rootView, editorStats, editor, date, time] = []

  simulateKeyUp = (key) ->
    e = $.Event "keydown", keyCode: key.charCodeAt(0)
    rootView.trigger(e)

  simulateClick = ->
    e = $.Event "mouseup"
    rootView.trigger(e)

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))

    date = new Date()
    mins = date.getMinutes()
    hours = date.getHours()

    mins = if mins == 60 then '01' else mins + 1
    time  = "#{hours}:#{mins}"

    atom.loadPackage('editor-stats').getInstance()
    editor = rootView.getActiveEditor()
    editorStats = EditorStats.instance

  afterEach ->
    rootView.deactivate()

  describe "when a keyup event is triggered", ->
    it "records the number of times a keyup is triggered", ->
      simulateKeyUp('a')
      expect(editorStats.eventLog[time]).toBe 1
      simulateKeyUp('b')
      expect(editorStats.eventLog[time]).toBe 2

  describe "when a mouseup event is triggered", ->
    it "records the number of times a mouseup is triggered", ->
      simulateClick()
      expect(editorStats.eventLog[time]).toBe 1
      simulateClick()
      expect(editorStats.eventLog[time]).toBe 2

