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
    for listener in @listenersByCommandName[event.type]
      if event.target.webkitMatchesSelector(listener.selector)
        listener.callback.call(currentTarget, syntheticEvent)
