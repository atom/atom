$ = require 'jquery'
RootView = require 'root-view'
EditorStats = require 'editor-stats/src/editor-stats-view'

describe "EditorStats", ->
  [rootView, editorStats, time] = []

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

    editorStatsPackage = atom.loadPackage('editor-stats')
    editorStatsPackage.getInstance()
    editorStats = editorStatsPackage.stats
    editorStats.clear()

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
