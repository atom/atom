RootView = require 'root-view'
EventPalette = require 'event-palette'
$ = require 'jquery'
_ = require 'underscore'

describe "EventPalette", ->
  [rootView, palette] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    atom.loadPackage("event-palette")
    palette = EventPalette.instance
    rootView.attachToDom().focus()
    rootView.trigger 'event-palette:toggle'

  afterEach ->
    rootView.remove()

  describe "when event-palette:toggle is triggered on the root view", ->
    it "shows a list of all valid event descriptions, names, and keybindings for the previously focused element", ->
      keyBindings = _.losslessInvert(keymap.bindingsForElement(rootView.getActiveEditor()))
      for eventName, description of rootView.getActiveEditor().events()
        eventLi = palette.list.children("[data-event-name='#{eventName}']")
        if description
          expect(eventLi).toExist()
          expect(eventLi.find('.event-name')).toHaveText(eventName)
          expect(eventLi.find('.event-description')).toHaveText(description)
          for binding in keyBindings[eventName] ? []
            expect(eventLi.find(".key-binding:contains(#{binding})")).toExist()
        else
          expect(eventLi).not.toExist()

    it "displays all events registerd on the window", ->
      editorEvents = rootView.getActiveEditor().events()
      windowEvents = $(window).events()
      expect(_.isEmpty(windowEvents)).toBeFalsy()
      for eventName, description of windowEvents
        eventLi = palette.list.children("[data-event-name='#{eventName}']")
        description = editorEvents[eventName] unless description
        if description
          expect(eventLi).toExist()
          expect(eventLi.find('.event-name')).toHaveText(eventName)
          expect(eventLi.find('.event-description')).toHaveText(description)
        else
          expect(eventLi).not.toExist()

    it "focuses the mini-editor and selects the first event", ->
      expect(palette.miniEditor.isFocused).toBeTruthy()
      expect(palette.find('.event:first')).toHaveClass 'selected'

    it "clears the previous mini editor text", ->
      palette.miniEditor.setText('hello')
      palette.trigger 'event-palette:toggle'
      rootView.trigger 'event-palette:toggle'
      expect(palette.miniEditor.getText()).toBe ''

  describe "when event-palette:toggle is triggered on the open event palette", ->
    it "focus the root view and detaches the event palette", ->
      expect(palette.hasParent()).toBeTruthy()
      palette.trigger 'event-palette:toggle'
      expect(palette.hasParent()).toBeFalsy()
      expect(rootView.getActiveEditor().isFocused).toBeTruthy()

  describe "when the event palette is cancelled", ->
    it "focuses the root view and detaches the event palette", ->
      expect(palette.hasParent()).toBeTruthy()
      palette.cancel()
      expect(palette.hasParent()).toBeFalsy()
      expect(rootView.getActiveEditor().isFocused).toBeTruthy()

  describe "when an event selection is confirmed", ->
    it "detaches the palette, then focuses the previously focused element and emits the selected event on it", ->
      eventHandler = jasmine.createSpy 'eventHandler'
      activeEditor = rootView.getActiveEditor()
      {eventName} = palette.array[5]
      activeEditor.preempt eventName, eventHandler

      palette.confirmed(palette.array[5])

      expect(activeEditor.isFocused).toBeTruthy()
      expect(eventHandler).toHaveBeenCalled()
      expect(palette.hasParent()).toBeFalsy()
