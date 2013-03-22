RootView = require 'root-view'
fs = require 'fs-utils'

fdescribe 'UI Kit', ->
  [UIKit, view] = []

  beforeEach ->
    window.rootView = new RootView
    # rootView.open('sample.js')
    UIKit = window.loadPackage("ui-kit").mainModule
    view = new UIKit.View()

  describe "View", ->
    describe "positioning", ->
      describe "full", ->
      describe "dialog", ->
        it "creates a floating dialog window", ->
          view = new UIKit.View(position:"dialog")
          view.addToRootView()
          expect(parseInt(view.css("top"))).not.toBe(0)
    describe "close icon", ->
      it "closes the view if it is clicked", ->
        view = new UIKit.View(position:"dialog")
        view.addToRootView()
        view.find(".close-icon").click()
        expect(view.visible).toBe(false)
        expect(rootView.find(".ui-view").length).toBe(0)
    describe "when a view is added to the window", ->
    describe "when a view is added to a new pane", ->
    describe "when a view is opened as a dialog", ->
      describe "modal", ->
        it "executes the callback when the view is closed", ->
          exited = false
          view.runModalDialog (result) ->
            exited = result
          view.close()
          waitsFor ->
            exited == true
          runs ->
            expect(view.visible).toBe(false)
      describe "alert", ->
      describe "prompt", ->

  describe "Controls", ->
    describe "when a control is added to the window", ->
      it "creates a html element", ->
        button = new UIKit.Controls.button
        view.addSubview(button)
        expect(view.find("button").length).toBe(1)
      it "creates a reference to the containing view", ->
        button = new UIKit.Controls.button
        view.addSubview(button)
        expect(button.parentView).toBe(view)

  describe "Layout", ->
    describe "when a new layout is created", ->
      it "assembles a grid of controls", ->
        layout = new UIKit.Layout ->
          @row =>
            @column =>
              @text "Enter something here:"
            @column =>
              @textField()
          @row =>
            @column align:"right", =>
              @button(title:"Save")
        view.addSubview(layout.content)
        expect(view.find("button").length).toBe(1)
        expect(view.find("input").length).toBe(1)

  describe "Events", ->
    describe "when a dialog is closed", ->