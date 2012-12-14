_ = require 'underscore'
{View} = require 'space-pen'

originalRemove = View.prototype.remove

_.extend View.prototype,
  observeConfig: (keyPath, callback) ->
    @subscribe(config.observe(keyPath, callback))

  subscribe: (subscription) ->
    @subscriptions ?= []
    @subscriptions.push(subscription)

  unsubscribe: ->
    subscription.destroy() for subscription in @subscriptions ? []

  remove: (args...) ->
    @unsubscribe()
    originalRemove.apply(this, args)
