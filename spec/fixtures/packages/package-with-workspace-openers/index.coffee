module.exports =
  activateCallCount: 0
  openerCount: 0

  activate: ->
    @activateCallCount++
    atom.workspace.addOpener (filePath) =>
      if filePath is 'atom://fictitious'
        @openerCount++
