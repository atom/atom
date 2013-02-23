$ = require 'jquery'
_ = require 'underscore'
RootView = require 'root-view'
EditorStats = require 'editor-stats/lib/editor-stats-view'

describe "EditorStats", ->
  [editorStats] = []

  simulateKeyUp = (key) ->
    e = $.Event "keydown", keyCode: key.charCodeAt(0)
    rootView.trigger(e)

  simulateClick = ->
    e = $.Event "mouseup"
    rootView.trigger(e)

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    editorStats = window.loadPackage('editor-stats').packageMain.stats

  describe "when a keyup event is triggered", ->
    beforeEach ->
      expect(_.values(editorStats.eventLog)).not.toContain 1
      expect(_.values(editorStats.eventLog)).not.toContain 2

    it "records the number of times a keyup is triggered", ->
      simulateKeyUp('a')
      expect(_.values(editorStats.eventLog)).toContain 1
      simulateKeyUp('b')
      expect(_.values(editorStats.eventLog)).toContain 2

  describe "when a mouseup event is triggered", ->
    it "records the number of times a mouseup is triggered", ->
      simulateClick()
      expect(_.values(editorStats.eventLog)).toContain 1
      simulateClick()
      expect(_.values(editorStats.eventLog)).toContain 2
