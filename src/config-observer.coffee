module.exports =
  observeConfig: (keyPath, args...) ->
    @configSubscriptions ?= {}
    @configSubscriptions[keyPath] = config.observe(keyPath, args...)

  unobserveConfig: ->
    for keyPath, subscription of @configSubscriptions ? {}
      subscription.cancel()
