module.exports =
  observeConfig: (keyPath, callback) ->
    @configSubscriptions ?= {}
    @configSubscriptions[keyPath] = config.observe(keyPath, callback)

  unobserveConfig: ->
    for keyPath, subscription of @configSubscriptions ? {}
      subscription.cancel()
