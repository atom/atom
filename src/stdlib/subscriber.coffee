_ = require 'underscore'

class WeakMap
  constructor: ->
    @map = {}

  set: (key, value) -> @map[key] = value
  get: (key) -> @map[key]
  delete: (key) -> delete @map[key]
  has: (key) -> @map[key]?

module.exports =
  subscribe: (eventEmitter, eventName, callback) ->
    eventEmitter.on eventName, callback
    @subscriptions ?= []
    @subscriptionsByObject ?= new WeakMap
    @subscriptionsByObject.set(eventEmitter, []) unless @subscriptionsByObject.has(eventEmitter)

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
