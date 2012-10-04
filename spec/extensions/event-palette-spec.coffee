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
    rootView.trigger 'event-palette:show'

  afterEach ->
    rootView.remove()

  describe "when event-palette:show is triggered on the root view", ->
    it "shows a list of all valid events for the previously focused element, then focuses the mini-editor and selects the first event", ->
      for [event, description] in rootView.getActiveEditor().events()
        expect(palette.list.find(".event:contains(#{event})")).toExist()

      expect(palette.miniEditor.isFocused).toBeTruthy()
      expect(palette.find('.event:first')).toHaveClass 'selected'

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
      [eventName, description] = palette.array[4]
      activeEditor.preempt eventName, eventHandler

      palette.confirmed(palette.array[4])

      expect(activeEditor.isFocused).toBeTruthy()
      expect(eventHandler).toHaveBeenCalled()
      expect(palette.hasParent()).toBeFalsy()
