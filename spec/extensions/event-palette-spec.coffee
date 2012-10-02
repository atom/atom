RootView = require 'root-view'
EventPalette = require 'event-palette'
$ = require 'jquery'

describe "EventPalette", ->
  [rootView, palette] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    rootView.activateExtension(EventPalette)
    palette = EventPalette.instance

  afterEach ->
    rootView.remove()

  describe "when shown", ->
    ffit "shows a list of all valid events for the previously focused element", ->
      rootView.attachToDom().focus()
      rootView.trigger 'event-palette:show'
      for [event, description] in rootView.getActiveEditor().events()
        expect(palette.eventList.find("td:contains(#{event})")).toExist()