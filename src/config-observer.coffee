module.exports =
  observeConfig: (keyPath, args...) ->
    @configSubscriptions ?= {}
    @configSubscriptions[keyPath] = config.observe(keyPath, args...)

  unobserveConfig: ->
    if @configSubscriptions?
      subscription.cancel() for keyPath, subscription of @configSubscriptions
      @configSubscriptions = null
