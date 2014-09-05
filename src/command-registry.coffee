{specificity} = require 'clear-cut'

SequenceCount = 0
SpecificityCache = {}

module.exports =
class CommandRegistry
  constructor: (@rootNode) ->
    @listenersByCommandName = {}

  add: (commandName, selector, callback) ->
    unless @listenersByCommandName[commandName]?
      @rootNode.addEventListener(commandName, @dispatchCommand, true)
      @listenersByCommandName[commandName] = []

    @listenersByCommandName[commandName].push(new CommandListener(selector, callback))

  dispatchCommand: (event) =>
    syntheticEvent = Object.create event,
      eventPhase: value: Event.BUBBLING_PHASE
      currentTarget: get: -> currentTarget

    currentTarget = event.target
    loop
      matchingListeners =
        @listenersByCommandName[event.type]
          .filter (listener) -> currentTarget.webkitMatchesSelector(listener.selector)
          .sort (a, b) -> a.compare(b)

      for listener in matchingListeners
        listener.callback.call(currentTarget, syntheticEvent)

      break if currentTarget is @rootNode
      currentTarget = currentTarget.parentNode

class CommandListener
  constructor: (@selector, @callback) ->
    @specificity = (SpecificityCache[@selector] ?= specificity(@selector))
    @sequenceNumber = SequenceCount++

  compare: (other) ->
    other.specificity - @specificity  or
      other.sequenceNumber - @sequenceNumber
