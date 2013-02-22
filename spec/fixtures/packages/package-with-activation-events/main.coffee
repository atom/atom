module.exports =
  activationEventCallCount: 0

  activate: ->
    rootView.getActiveView()?.command 'activation-event', =>
      @activationEventCallCount++

  serialize: ->
    previousData: 'overwritten'
