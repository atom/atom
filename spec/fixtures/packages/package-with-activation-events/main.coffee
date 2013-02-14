module.exports =
  activationEventCallCount: 0

  activate: ->
    rootView.getActiveEditor()?.command 'activation-event', =>
      @activationEventCallCount++

  serialize: ->
    previousData: 'overwritten'