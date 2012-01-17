nakedLoad 'jasmine-jquery'
$ = require 'jquery'
_ = require 'underscore'
Native = require 'native'
BindingSet = require 'binding-set'
require 'window'

afterEach ->
  (new Native).resetMainMenu()
  atom.globalKeymap.reset()
  $('#jasmine-content').empty()

window.atom = new (require 'app')

eventPropertiesFromPattern = (pattern) ->
  bindingSet = new BindingSet("*", {})
  parsedPattern = bindingSet.parseKeyPattern(pattern)
  delete parsedPattern.key # key doesn't exist on browser-generated key events
  parsedPattern

window.keydownEvent = (pattern, properties={}) ->
  $.Event "keydown", _.extend(eventPropertiesFromPattern(pattern), properties)

window.waitsForPromise = (fn) ->
  window.waitsFor (moveOn) ->
    fn().done(moveOn)

$.fn.resultOfTrigger = (type) ->
  event = $.Event(type)
  this.trigger(event)
  event.result

$.fn.enableKeymap = ->
  @on 'keydown', (e) => atom.globalKeymap.handleKeyEvent(e)

$.fn.attachToDom = ->
  console.log this
  $('#jasmine-content').append(this)

