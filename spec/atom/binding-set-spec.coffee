$ = require 'jquery'
_ = require 'underscore'
BindingSet = require 'binding-set'

describe "BindingSet", ->
  bindingSet = null
  beforeEach ->
    bindingSet = new BindingSet('*', 'x': 'foo')

  describe ".eventMatchesPattern(event, pattern)", ->
    event = (key, attrs={}) ->
      defaultAttrs =
        ctrlKey: false
        altKey: false
        shiftKey: false
        metaKey: false

      attrs.which = key.toUpperCase().charCodeAt(0)
      $.Event 'keydown', _.extend({}, defaultAttrs, attrs)

    it "handles patterns with modifiers", ->
      expect(bindingSet.eventMatchesPattern(event('q'), 'q')).toBeTruthy()
      expect(bindingSet.eventMatchesPattern(event('0', altKey: true), '<alt-0>')).toBeTruthy()
      expect(bindingSet.eventMatchesPattern(event('0', metaKey: true), '<meta-0>')).toBeTruthy()
      expect(bindingSet.eventMatchesPattern(event('0', ctrlKey: true), '<ctrl-0>')).toBeTruthy()
      expect(bindingSet.eventMatchesPattern(event('a', shiftKey: true), '<shift-a>')).toBeTruthy()
      expect(bindingSet.eventMatchesPattern(event('a', shiftKey: true), 'A')).toBeTruthy()
      expect(bindingSet.eventMatchesPattern(event('0', altKey: true, ctrlKey: true, metaKey: true, shiftKey: true), '<meta-ctrl-alt-shift-0>')).toBeTruthy()

      # # negative examples
      expect(bindingSet.eventMatchesPattern(event('a'), '<shift-a>')).toBeFalsy()
      expect(bindingSet.eventMatchesPattern(event('a', shiftKey: true), 'a')).toBeFalsy()
      expect(bindingSet.eventMatchesPattern(event('d'), 'k')).toBeFalsy()

