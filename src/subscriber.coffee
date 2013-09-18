_ = require './underscore-extensions'

module.exports =
  subscribeWith: (eventEmitter, methodName, args) ->
    eventEmitter[methodName](args...)

    @subscriptions ?= []
    @subscriptionsByObject ?= new WeakMap
    @subscriptionsByObject.set(eventEmitter, []) unless @subscriptionsByObject.has(eventEmitter)

    eventName = _.first(args)
    callback = _.last(args)
    subscription = cancel: ->
      # node's EventEmitter doesn't have 'off' method.
      removeListener = eventEmitter.off ? eventEmitter.removeListener
      removeListener.call eventEmitter, eventName, callback
    @subscriptions.push(subscription)
    @subscriptionsByObject.get(eventEmitter).push(subscription)

  subscribe: (eventEmitter, args...) ->
    @subscribeWith(eventEmitter, 'on', args)

  subscribeToCommand: (eventEmitter, args...) ->
    @subscribeWith(eventEmitter, 'command', args)

  unsubscribe: (object) ->
    if object?
      for subscription in @subscriptionsByObject?.get(object) ? []
        subscription.cancel()
        _.remove(@subscriptions, subscription)
      @subscriptionsByObject?.delete(object)
    else
      subscription.cancel() for subscription in @subscriptions ? []
      @subscriptions = null
      @subscriptionsByObject = null
