CommandMap = require 'command-map'

describe "CommandMap", ->
  commandMap = null
  delegate = null

  beforeEach ->
    delegate = { delete: jasmine.createSpy('delete') }
    commandMap = new CommandMap delegate

  describe "handleKeyEvent(event)", ->
    describe "when there is a single-character mapping to a command method", ->
      beforeEach ->
        commandMap.mapKey 'd', 'delete'

      it "calls the named method on the delegate with the given event when the event matches the pattern", ->
        commandMap.handleKeyEvent createKeyEvent('z')
        expect(delegate.delete).not.toHaveBeenCalled()
        commandMap.clearBufferedEvents()

        event = createKeyEvent 'd'
        commandMap.handleKeyEvent event
        expect(delegate.delete).toHaveBeenCalled()

    describe "when there is a multi character mapping to a command method", ->
      beforeEach ->
        commandMap.mapKey 'dad', 'delete'

      it "calls the named method on the delegate with the given event when the event matches the pattern", ->
        event1 = createKeyEvent 'd'
        event2 = createKeyEvent 'a'
        event3 = createKeyEvent 'd'

        commandMap.handleKeyEvent event1
        expect(delegate.delete).not.toHaveBeenCalled()

        commandMap.handleKeyEvent event2
        expect(delegate.delete).not.toHaveBeenCalled()

        commandMap.handleKeyEvent event3
        expect(delegate.delete).toHaveBeenCalled()

    describe ".keyEventsMatchPattern(events, pattern)", ->
      it "returns true only if the given events match the pattern", ->
        event1 = createKeyEvent 'd'
        event2 = createKeyEvent 'a'
        event3 = createKeyEvent 'd'
        events = [event1, event2, event3]

        expect(commandMap.keyEventsMatchPattern(events, "dad")).toBeTruthy()
        expect(commandMap.keyEventsMatchPattern(events, "day")).toBeFalsy()
        expect(commandMap.keyEventsMatchPattern(events, "da")).toBeFalsy()

        expect(commandMap.keyEventsMatchPattern([event1], "d")).toBeTruthy()

    describe "when there is more than one pattern matching a key event", ->
