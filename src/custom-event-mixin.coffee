module.exports =
CustomEventMixin =
  componentWillMount: ->
    @customEventListeners = {}

  componentWillUnmount: ->
    for name, listeners in @customEventListeners
      for listener in listeners
        @getDOMNode().removeEventListener(name, listener)
    return

  addCustomEventListeners: (customEventListeners) ->
    for name, listener of customEventListeners
      @customEventListeners[name] ?= []
      @customEventListeners[name].push(listener)
      @getDOMNode().addEventListener(name, listener)
    return
