module.exports =
  activateCallCount: 0
  activationCommandCallCount: 0
  legacyActivationCommandCallCount: 0

  activate: ->
    @activateCallCount++

    atom.commands.add 'atom-workspace', 'activation-command', =>
      @activationCommandCallCount++

    editorView = document.querySelector('atom-workspace').getView(atom.workspace.getActiveEditor())?.__spacePenView
    editorView?.command 'activation-command', =>
      @legacyActivationCommandCallCount++
