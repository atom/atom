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
        expect(palette.eventList.find("td:contains(#{event})")).toExist()

      expect(palette.miniEditor.isFocused).toBeTruthy()
      expect(palette.find('.event:first')).toHaveClass 'selected'

  describe "when event-palette:cancel is triggered on the event palette", ->
    it "focuses the root view and detaches the event palette", ->
      expect(palette.hasParent()).toBeTruthy()
      palette.trigger('event-palette:cancel')
      expect(palette.hasParent()).toBeFalsy()
      expect(rootView.getActiveEditor().isFocused).toBeTruthy()

  describe "when 'move-up' and 'move-down' events are triggered on the mini editor", ->
    it "selects the next and previous event, if there is one, and scrolls the list to it", ->
      palette.miniEditor.trigger 'move-up'
      expect(palette.find('.event:eq(0)')).toHaveClass 'selected'

      palette.miniEditor.trigger 'move-down'
      expect(palette.find('.event:eq(0)')).not.toHaveClass 'selected'
      expect(palette.find('.event:eq(1)')).toHaveClass 'selected'

      palette.miniEditor.trigger 'move-down'
      expect(palette.find('.event:eq(1)')).not.toHaveClass 'selected'
      expect(palette.find('.event:eq(2)')).toHaveClass 'selected'

      palette.miniEditor.trigger 'move-up'
      expect(palette.find('.event:eq(2)')).not.toHaveClass 'selected'
      expect(palette.find('.event:eq(1)')).toHaveClass 'selected'

      _.times palette.find('.event').length, ->
        palette.miniEditor.trigger 'move-down'

      expect(palette.eventList.scrollTop() + palette.eventList.height()).toBe palette.eventList.prop('scrollHeight')

  describe "when event-palette:select is triggered on the palette", ->
    it "emits the selected event on the last focused element, then detaches the palette", ->
      _.times 3, -> palette.miniEditor.trigger 'move-down'

      eventHandler = jasmine.createSpy 'eventHandler'
      rootView.getActiveEditor().preempt palette.getSelectedEventName(), eventHandler
      palette.trigger 'event-palette:select'
      expect(eventHandler).toHaveBeenCalled()

      expect(rootView.getActiveEditor().isFocused).toBeTruthy()
      expect(palette.hasParent()).toBeFalsy()
