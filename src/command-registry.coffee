{Disposable} = require 'event-kit'
{specificity} = require 'clear-cut'

SequenceCount = 0
SpecificityCache = {}

module.exports =
class CommandRegistry
  constructor: (@rootNode) ->
    @listenersByCommandName = {}

  add: (selector, commandName, callback) ->
    unless @listenersByCommandName[commandName]?
      @rootNode.addEventListener(commandName, @dispatchCommand, true)
      @listenersByCommandName[commandName] = []

    listener = new CommandListener(selector, callback)
    listenersForCommand = @listenersByCommandName[commandName]
    listenersForCommand.push(listener)

    new Disposable =>
      listenersForCommand.splice(listenersForCommand.indexOf(listener), 1)
      if listenersForCommand.length is 0
        delete @listenersByCommandName[commandName]
        @rootNode.removeEventListener(commandName, @dispatchCommand, true)

  dispatchCommand: (event) =>
    propagationStopped = false
    immediatePropagationStopped = false
    currentTarget = event.target

    syntheticEvent = Object.create event,
      eventPhase: value: Event.BUBBLING_PHASE
      currentTarget: get: -> currentTarget
      stopPropagation: value: ->
        propagationStopped = true
      stopImmediatePropagation: value: ->
        propagationStopped = true
        immediatePropagationStopped = true

    loop
      matchingListeners =
        @listenersByCommandName[event.type]
          .filter (listener) -> currentTarget.webkitMatchesSelector(listener.selector)
          .sort (a, b) -> a.compare(b)

      for listener in matchingListeners
        break if immediatePropagationStopped
        listener.callback.call(currentTarget, syntheticEvent)

      break if propagationStopped
      break if currentTarget is @rootNode
      currentTarget = currentTarget.parentNode

class CommandListener
  constructor: (@selector, @callback) ->
    @specificity = (SpecificityCache[@selector] ?= specificity(@selector))
    @sequenceNumber = SequenceCount++

  compare: (other) ->
    other.specificity - @specificity  or
      other.sequenceNumber - @sequenceNumber
