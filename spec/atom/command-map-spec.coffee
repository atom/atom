CommandMap = require 'command-map'

describe "CommandMap", ->
  commandMap = null
  delegate = null
  d = null
  a = null
  y = null

  beforeEach ->
    d = createKeyEvent 'd'
    a = createKeyEvent 'a'
    y = createKeyEvent 'y'
    delegate = {
      action1: jasmine.createSpy('action1')
      action2: jasmine.createSpy('action2')
    }
    commandMap = new CommandMap delegate

  describe "handleKeyEvent(event)", ->
    describe "when there is a single-character mapping to a command method", ->
      beforeEach ->
        commandMap.mapKey 'd', 'action1'

      it "calls the named method on the delegate with the given event when the event matches the pattern", ->
        commandMap.handleKeyEvent createKeyEvent('z')
        expect(delegate.action1).not.toHaveBeenCalled()

        event = createKeyEvent 'd'
        commandMap.handleKeyEvent event
        expect(delegate.action1).toHaveBeenCalled()

    describe "when there is a multi-character mapping to a command method", ->
      beforeEach ->
        commandMap.mapKey 'dad', 'action1'

      it "calls the named method on the delegate with the given event when the event matches the pattern", ->
        commandMap.handleKeyEvent d
        expect(delegate.action1).not.toHaveBeenCalled()

        commandMap.handleKeyEvent a
        expect(delegate.action1).not.toHaveBeenCalled()

        commandMap.handleKeyEvent d
        expect(delegate.action1).toHaveBeenCalled()

    describe "when there is more than one pattern matching a prefix of key events", ->
      inputTimeout = null

      beforeEach ->
        commandMap.mapKey 'da', 'action1'
        commandMap.mapKey 'dad', 'action2'

        spyOn(window, 'setTimeout').andCallFake (fn) ->
          inputTimeout = fn
          'handle'

        spyOn(window, 'clearTimeout')

        commandMap.handleKeyEvent d
        expect(window.setTimeout).toHaveBeenCalled()
        window.setTimeout.reset()

        commandMap.handleKeyEvent a
        expect(window.clearTimeout).toHaveBeenCalledWith 'handle'
        expect(window.setTimeout).toHaveBeenCalled()
        expect(delegate.action1).not.toHaveBeenCalled()
        expect(delegate.action2).not.toHaveBeenCalled()

      describe "when no additional key is pressed before the input timeout", ->
        it "calls the method for the shorter pattern on the delegate and clears the event buffer", ->
          inputTimeout()
          expect(delegate.action1).toHaveBeenCalled()

          commandMap.handleKeyEvent d
          expect(delegate.action2).not.toHaveBeenCalled()

      describe "when an additional matching key is pressed before the input timeout", ->
        it "calls the method for the longer pattern on the delegate, cancels the timeout, and clears the event buffer", ->
          commandMap.handleKeyEvent d
          expect(window.clearTimeout).toHaveBeenCalledWith 'handle'
          expect(delegate.action2).toHaveBeenCalled()

          # ensure the input buffer has been cleared, so we can match da
          commandMap.handleKeyEvent d
          commandMap.handleKeyEvent a
          inputTimeout()

          expect(delegate.action1).toHaveBeenCalled()

  describe ".keyEventsMatchPattern(events, pattern)", ->
    it "returns true only if the given events match the given pattern", ->
      events = [d, a, d]

      expect(commandMap.keyEventsMatchPattern(events, "dad")).toBeTruthy()
      expect(commandMap.keyEventsMatchPattern(events, "day")).toBeFalsy()
      expect(commandMap.keyEventsMatchPattern(events, "da")).toBeFalsy()

      expect(commandMap.keyEventsMatchPattern([d], "d")).toBeTruthy()

  describe "keyEventsMatchPatternPrefix(events, pattern)", ->
    it "returns true only if the given events match a prefix of the given pattern", ->
      expect(commandMap.keyEventsMatchPatternPrefix([d, a], "dad")).toBeTruthy()
      expect(commandMap.keyEventsMatchPatternPrefix([d, a], "da")).toBeTruthy()
      expect(commandMap.keyEventsMatchPatternPrefix([d, a], "d")).toBeFalsy()
      expect(commandMap.keyEventsMatchPatternPrefix([d, a, y], "da")).toBeFalsy()

