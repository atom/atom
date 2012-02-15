$ = require 'jquery'
_ = require 'underscore'
BindingSet = require 'binding-set'

describe "BindingSet", ->
  bindingSet = null
  beforeEach ->
    bindingSet = new BindingSet('*', 'x': 'foo')

  describe ".eventMatchesPattern(event, pattern)", ->
    it "handles patterns with and without modifiers", ->
      expect(bindingSet.eventMatchesPattern(keydownEvent('q'), 'q')).toBeTruthy()
      expect(bindingSet.eventMatchesPattern(keydownEvent('left'), 'left')).toBeTruthy()
      expect(bindingSet.eventMatchesPattern(keydownEvent('0', altKey: true), '<alt-0>')).toBeTruthy()
      expect(bindingSet.eventMatchesPattern(keydownEvent('A', shiftKey: true), 'A')).toBeTruthy()
      expect(bindingSet.eventMatchesPattern(keydownEvent('0', altKey: true, ctrlKey: true, metaKey: true, shiftKey: true), '<alt-ctrl-meta-0>')).toBeTruthy()

      # negative examples
      expect(bindingSet.eventMatchesPattern(keydownEvent('a'), '<shift-a>')).toBeFalsy()
      expect(bindingSet.eventMatchesPattern(keydownEvent('d'), 'k')).toBeFalsy()
