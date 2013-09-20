_ = require './underscore-extensions'

# Public: Provides a list of functions that can be used in Atom for event management.
#
# Each event can have more than one handler; that is, an event can trigger multiple functions.
module.exports =
  # Associates an event name with a function to perform.
  #
  # This is called endlessly, until the event is turned {.off}.
  #
  # eventNames - A {String} containing one or more space-separated events.
  # handler - A {Function} that's executed when the event is triggered.
  on: (eventNames, handler) ->
    for eventName in eventNames.split(/\s+/) when eventName isnt ''
      [eventName, namespace] = eventName.split('.')

      @eventHandlersByEventName ?= {}
      @eventHandlersByEventName[eventName] ?= []
      @eventHandlersByEventName[eventName].push(handler)

      if namespace
        @eventHandlersByNamespace ?= {}
        @eventHandlersByNamespace[namespace] ?= {}
        @eventHandlersByNamespace[namespace][eventName] ?= []
        @eventHandlersByNamespace[namespace][eventName].push(handler)

    @afterSubscribe?()

  # Associates an event name with a function to perform only once.
  #
  # eventName - A {String} name identifying an event
  # handler - A {Function} that's executed when the event is triggered
  one: (eventName, handler) ->
    oneShotHandler = (args...) =>
      @off(eventName, oneShotHandler)
      handler(args...)

    @on eventName, oneShotHandler

  # Triggers a registered event.
  #
  # eventName - A {String} name identifying an event
  # args - Any additional arguments to pass over to the event `handler`
  trigger: (eventName, args...) ->
    if @queuedEvents
      @queuedEvents.push [eventName, args...]
    else
      [eventName, namespace] = eventName.split('.')

      if namespace
        if handlers = @eventHandlersByNamespace?[namespace]?[eventName]
          new Array(handlers...).forEach (handler) -> handler(args...)
      else
        if handlers = @eventHandlersByEventName?[eventName]
          handlers.forEach (handler) -> handler(args...)

  # Stops executing handlers for a registered event.
  #
  # eventNames - A {String} containing one or more space-separated events.
  # handler - The {Function} to remove from the event. If not provided, all handlers are removed.
  off: (eventNames, handler) ->
    if eventNames
      for eventName in eventNames.split(/\s+/) when eventName isnt ''
        [eventName, namespace] = eventName.split('.')
        eventName = undefined if eventName == ''

        if namespace
          if eventName
            handlers = @eventHandlersByNamespace?[namespace]?[eventName] ? []
            for handler in new Array(handlers...)
              _.remove(handlers, handler)
              @off eventName, handler
          else
            for eventName, handlers of @eventHandlersByNamespace?[namespace] ? {}
              for handler in new Array(handlers...)
                _.remove(handlers, handler)
                @off eventName, handler
        else
          subscriptionCountBefore = @subscriptionCount()
          if handler
            eventHandlers = @eventHandlersByEventName[eventName]
            _.remove(eventHandlers, handler) if eventHandlers
          else
            delete @eventHandlersByEventName?[eventName]
          @afterUnsubscribe?() if @subscriptionCount() < subscriptionCountBefore
    else
      subscriptionCountBefore = @subscriptionCount()
      @eventHandlersByEventName = {}
      @eventHandlersByNamespace = {}
      @afterUnsubscribe?() if @subscriptionCount() < subscriptionCountBefore

  # When called, stops triggering any events.
  pauseEvents: ->
    @pauseCount ?= 0
    if @pauseCount++ == 0
      @queuedEvents ?= []

  # When called, resumes triggering events.
  resumeEvents: ->
    if --@pauseCount == 0
      queuedEvents = @queuedEvents
      @queuedEvents = null
      @trigger(event...) for event in queuedEvents

  # Identifies how many events are registered.
  #
  # Returns a {Number}.
  subscriptionCount: ->
    count = 0
    for name, handlers of @eventHandlersByEventName
      count += handlers.length
    count
