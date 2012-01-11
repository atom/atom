nakedLoad 'jasmine-jquery'
$ = require 'jquery'
_ = require 'underscore'
Native = require 'native'
BindingSet = require 'binding-set'

afterEach ->
  (new Native).resetMainMenu()

window.atom = new (require 'app')

window.keypressEvent = (pattern, properties={}) ->
  bindingSet = new BindingSet("*", {})
  $.Event "keypress", _.extend(bindingSet.parseKeyPattern(pattern), properties)

window.keydownEvent = (pattern, properties={}) ->
  bindingSet = new BindingSet("*", {})
  $.Event "keydown", _.extend(bindingSet.parseKeyPattern(pattern), properties)

window.waitsForPromise = (fn) ->
  window.waitsFor (moveOn) ->
    fn().done(moveOn)

$.fn.resultOfTrigger = (type) ->
  event = $.Event(type)
  this.trigger(event)
  event.result
