RootView = require 'root-view'
EventPalette = require 'event-palette'
$ = require 'jquery'
_ = require 'underscore'

describe "EventPalette", ->
  [rootView, palette] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    rootView.activateExtension(EventPalette)
    palette = EventPalette.instance
    rootView.attachToDom().focus()
    rootView.trigger 'event-palette:toggle'

  afterEach ->
    rootView.remove()

  describe "when event-palette:toggle is triggered on the root view", ->
    it "shows a list of all valid events for the previously focused element, then focuses the mini-editor and selects the first event", ->
      for eventName, description of rootView.getActiveEditor().events()
        eventLi = palette.list.children("[data-event-name='#{eventName}']")
        if description
          expect(eventLi).toExist()
          expect(eventLi.children('.event-name')).toHaveText(eventName)
          expect(eventLi.children('.event-description')).toHaveText(description)
        else
          expect(eventLi).not.toExist()
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
