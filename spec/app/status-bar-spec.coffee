$ = require 'jquery'
RootView = require 'root-view'
StatusBar = require 'status-bar'

describe "StatusBar", ->
  rootView = null

  beforeEach ->
    rootView = new RootView
    rootView.simulateDomAttachment()
    StatusBar.initialize(rootView)

  describe "@initialize", ->
    it "appends a status bar to all existing and new editors", ->
      expect(rootView.panes.find('.pane').length).toBe 1
      expect(rootView.panes.find('.pane > .status-bar').length).toBe 1
      rootView.activeEditor().splitRight()
      expect(rootView.find('.pane').length).toBe 2
      expect(rootView.panes.find('.pane > .status-bar').length).toBe 2
