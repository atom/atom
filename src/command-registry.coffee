module.exports =
class CommandRegistry
  constructor: (@rootNode) ->
    @listenersByCommandName = {}

  add: (commandName, selector, callback) ->
    unless @listenersByCommandName[commandName]?
      @rootNode.addEventListener(commandName, @dispatchCommand, true)
      @listenersByCommandName[commandName] = []

    @listenersByCommandName[commandName].push({selector, callback})

  dispatchCommand: (event) =>
    syntheticEvent = Object.create event,
      eventPhase: value: Event.BUBBLING_PHASE
      currentTarget: get: -> currentTarget

    currentTarget = event.target
    loop
      for listener in @listenersByCommandName[event.type]
        if currentTarget.webkitMatchesSelector(listener.selector)
          listener.callback.call(currentTarget, syntheticEvent)

      break if currentTarget is @rootNode
      currentTarget = currentTarget.parentNode
