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

    @afterSubscribe?()

  trigger: (eventName, args...) ->
    [eventName, namespace] = eventName.split('.')

    if namespace
      @eventHandlersByNamespace?[namespace]?[eventName]?.forEach (handler) -> handler(args...)
    else
      @eventHandlersByEventName?[eventName]?.forEach (handler) -> handler(args...)

  off: (eventName='', handler) ->
    [eventName, namespace] = eventName.split('.')
    eventName = undefined if eventName == ''

    subscriptionCountBefore = @subscriptionCount()

    if !eventName? and !namespace?
      @eventHandlersByEventName = {}
      @eventHandlersByNamespace = {}
    else if namespace
      if eventName
        handlers = @eventHandlersByNamespace?[namespace]?[eventName] ? []
        for handler in new Array(handlers...)
          _.remove(handlers, handler)
          @off eventName, handler
        return
      else
        for eventName, handlers of @eventHandlersByNamespace?[namespace] ? {}
          for handler in new Array(handlers...)
            _.remove(handlers, handler)
            @off eventName, handler
        return
    else
      if handler
        _.remove(@eventHandlersByEventName[eventName], handler)
      else
        delete @eventHandlersByEventName?[eventName]

    @afterUnsubscribe?() if @subscriptionCount() < subscriptionCountBefore

  subscriptionCount: ->
    count = 0
    for name, handlers of @eventHandlersByEventName
      count += handlers.length
    count

