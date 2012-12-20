module.exports =
  subscribe: (eventEmitter, eventName, callback) ->
    eventEmitter.on eventName, callback
    @subscriptions ?= []
    @subscriptions.push(cancel: -> eventEmitter.off eventName, callback)

  unsubscribe: ->
    subscription.cancel() for subscription in @subscriptions ? []
