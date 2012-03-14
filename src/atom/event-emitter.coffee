_ = require 'underscore'

module.exports =
  on: (eventName, handler) ->
    [eventName, namespace] = eventName.split('.')

    @eventHandlersByEventName ?= {}
    @eventHandlersByEventName[eventName] ?= []
    @eventHandlersByEventName[eventName].push(handler)

    if namespace
      @eventHandlersByNamespace ?= {}
      @eventHandlersByNamespace[namespace] ?= {}
      @eventHandlersByNamespace[namespace][eventName] ?= []
      @eventHandlersByNamespace[namespace][eventName].push(handler)

  trigger: (eventName, event) ->
    [eventName, namespace] = eventName.split('.')

    if namespace
      @eventHandlersByNamespace?[namespace]?[eventName]?.forEach (handler) -> handler(event)
    else
      @eventHandlersByEventName?[eventName]?.forEach (handler) -> handler(event)

  off: (eventName, handler) ->
    [eventName, namespace] = eventName.split('.')
    eventName = undefined if eventName is ''

    if namespace
      if eventName
        handlers = @eventHandlersByNamespace[namespace]?[eventName] ? []
        for handler in new Array(handlers...)
          _.remove(handlers, handler)
          @off eventName, handler
      else
        for eventName, handlers of @eventHandlersByNamespace[namespace] ? {}
          for handler in new Array(handlers...)
            _.remove(handlers, handler)
            @off eventName, handler
    else
      if handler
        _.remove(@eventHandlersByEventName[eventName], handler)
      else
        delete @eventHandlersByEventName[eventName]
