module.exports =
  subscribe: (eventEmitter, eventName, callback) ->
    eventEmitter.on eventName, callback
    @subscriptions ?= []
    @subscriptions.push(cancel: -> eventEmitter.off eventName, callback)

  subscribeToCommand: (view, eventName, callback) ->
    view.command eventName, callback
    @subscriptions ?= []
    @subscriptions.push(cancel: -> view.off view, callback)

  unsubscribe: ->
    subscription.cancel() for subscription in @subscriptions ? []
