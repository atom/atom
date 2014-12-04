module.exports =
  activateCallCount: 0
  activationCommandCallCount: 0
  legacyActivationCommandCallCount: 0

  activate: ->
    @activateCallCount++

    atom.commands.add 'atom-workspace', 'activation-command', =>
      @activationCommandCallCount++

    editorView = atom.views.getView(atom.workspace.getActiveTextEditor())?.__spacePenView
    editorView?.command 'activation-command', =>
      @legacyActivationCommandCallCount++
