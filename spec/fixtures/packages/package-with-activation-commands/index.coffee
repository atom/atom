module.exports =
  activateCallCount: 0
  activationCommandCallCount: 0
  legacyActivationCommandCallCount: 0

  activate: ->
    @activateCallCount++

    atom.commands.add 'atom-workspace', 'activation-command', =>
      @activationCommandCallCount++

    atom.workspaceView.getActiveView()?.command 'activation-command', =>
      @legacyActivationCommandCallCount++
