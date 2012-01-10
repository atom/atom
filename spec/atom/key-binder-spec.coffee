KeyBinder = require 'key-binder'

describe "KeyBinder", ->
  keyBinder = null
  beforeEach -> keyBinder = new KeyBinder

  describe 'keyEventMatchesPattern', ->
    expectMatch = (pattern) ->
      expect(keyBinder.keyEventMatchesPattern(window.keydownEvent(pattern), pattern)).toBeTruthy()

    expectNoMatch = (eventPattern, patternToTest) ->
      event = window.keydownEvent(eventPattern)
      expect(keyBinder.keyEventMatchesPattern(event, patternToTest)).toBeFalsy()

    it 'returns true if the modifiers and letter in the pattern match the key event', ->
      expectMatch 'meta+a'
      expectMatch 'meta+1'
      expectMatch 'alt+1'
      expectMatch 'ctrl+1'
      expectMatch 'shift+1'
      expectMatch 'shift+a'
      expectMatch 'meta+alt+1'
      expectMatch 'meta+alt+ctrl+1'
      expectMatch 'meta+alt+ctrl+shift+1'

      expectNoMatch 'meta+alt+ctrl+shift+1', 'meta+1'
      expectNoMatch 'meta+1', 'meta+alt+1'
      expectNoMatch 'meta+a', 'meta+b'
      expectNoMatch 'meta+a', 'meta+b'
      expectNoMatch 'meta+1', 'alt+1'

    it 'handles named special keys (e.g. arrows, home)', ->
      expectMatch 'up'

