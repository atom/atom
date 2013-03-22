RootView = require 'root-view'
fs = require 'fs-utils'

fdescribe 'UI Kit', ->
  [UIKit, view] = []

  beforeEach ->
    window.rootView = new RootView
    # rootView.open('sample.js')
    UIKit = window.loadPackage("ui-kit").mainModule
    window.console.log UIKit
    view = new UIKit.View()


  describe "View", ->
    describe "when a view is added to the window", ->
    describe "when a view is added to a new pane", ->
    describe "when a view is opened as a dialog", ->
      describe "modal", ->
        it "executes the callback when the view is closed", ->
          exited = false
          view.runModalDialog (result) ->
            exited = result
          view.find("button").click()
          waitsFor ->
            exited == true
          runs ->
            expect(exited).toBe(true)
      describe "alert", ->
      describe "prompt", ->

  describe "Controls", ->
    describe "when a control is added to the window", ->
      it "creates a html element", ->
        button = new UIKit.Controls.button
        view.addSubview(button)
        expect(view.find("button").length).toBe(1)

  describe "Layout", ->
    describe "when a new layout is created", ->
      it ""

  describe "Events", ->
    describe "when a dialog is closed", ->