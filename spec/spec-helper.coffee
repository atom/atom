nakedLoad 'jasmine-jquery'
$ = require 'jquery'
_ = require 'underscore'
Native = require 'native'
BindingSet = require 'binding-set'
require 'window'
window.showConsole()

beforeEach ->
  window.resetTimeouts()

afterEach ->
  (new Native).resetMainMenu()
  atom.globalKeymap.reset()
  $('#jasmine-content').empty()

window.atom = new (require 'app')

# Use underscore's definition of equality for toEqual assertions
jasmine.Env.prototype.equals_ = _.isEqual

eventPropertiesFromPattern = (pattern) ->
  bindingSet = new BindingSet("*", {})
  parsedPattern = bindingSet.parseKeyPattern(pattern)
  delete parsedPattern.key # key doesn't exist on browser-generated key events
  parsedPattern

window.keydownEvent = (pattern, properties={}) ->
  $.Event "keydown", _.extend(eventPropertiesFromPattern(pattern), properties)

window.clickEvent = (properties={}) ->
  $.Event "click", properties

window.waitsForPromise = (fn) ->
  window.waitsFor (moveOn) ->
    fn().done(moveOn)

window.resetTimeouts = ->
  window.now = 0
  window.timeoutCount = 0
  window.timeouts = []

window.setTimeout = (callback, ms) ->
  id = ++window.timeoutCount
  window.timeouts.push([id, window.now + ms, callback])
  id

window.clearTimeout = (idToClear) ->
  window.timeouts = window.timeouts.filter ([id]) -> id != idToClear

window.advanceClock = (delta) ->
  window.now += delta
  window.timeouts = window.timeouts.filter ([id, strikeTime, callback]) ->
    if strikeTime <= window.now
      callback()
      false
    else
      true

$.fn.resultOfTrigger = (type) ->
  event = $.Event(type)
  this.trigger(event)
  event.result

$.fn.enableKeymap = ->
  @on 'keydown', (e) => atom.globalKeymap.handleKeyEvent(e)

$.fn.attachToDom = ->
  $('#jasmine-content').append(this)

$.fn.textInput = (data) ->
  event = document.createEvent 'TextEvent'
  event.initTextEvent('textInput', true, true, window, data)
  this.each -> this.dispatchEvent(event)
