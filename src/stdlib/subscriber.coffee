_ = require 'underscore'

module.exports =
  subscribe: (eventEmitter, subscribeArgs...) ->
    eventEmitter.on(subscribeArgs...)

    @subscriptions ?= []
    @subscriptionsByObject ?= new WeakMap
    @subscriptionsByObject.set(eventEmitter, []) unless @subscriptionsByObject.has(eventEmitter)

    eventName = _.first(subscribeArgs)
    callback = _.last(subscribeArgs)
    subscription = cancel: -> eventEmitter.off eventName, callback
    @subscriptions.push(subscription)
    @subscriptionsByObject.get(eventEmitter).push(subscription)

  subscribeToCommand: (view, eventName, callback) ->
    view.command eventName, callback
    @subscriptions ?= []
    @subscriptions.push(cancel: -> view.off eventName, callback)

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
