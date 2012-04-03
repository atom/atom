$ = require 'jquery'
_ = require 'underscore'
Specificity = require 'specificity'

module.exports =
class BindingSet
  selector: null
  commandForEvent: null

  constructor: (@selector, mapOrFunction) ->
    @specificity = Specificity(@selector)
    @commandForEvent = @buildEventHandler(mapOrFunction)

  buildEventHandler: (mapOrFunction) ->
    if _.isFunction(mapOrFunction)
      mapOrFunction
    else
      (event) =>
        for pattern, command of mapOrFunction
          return command if @eventMatchesPattern(event, pattern)
        null

  eventMatchesPattern: (event, pattern) ->
    pattern = pattern.replace(/^<|>$/g, '')
    event.keystroke == pattern
