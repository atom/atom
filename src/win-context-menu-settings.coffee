{CompositeDisposable} = require 'event-kit'
WinRegistry = require './browser/win-registry'

# Update Atom integration in Windows Explorer context menu, according to current settings.
module.exports =
class WinContextMenuSettings
  constructor: ->
    @disposables = new CompositeDisposable()
    @disposables.add atom.config.onDidChange 'core.showAtomInShellContextMenu', @handleSettingsChange

  dispose: ->
    @disposables.dispose()

  handleSettingsChange: ({newValue}) ->
    if newValue
      WinRegistry.installContextMenu ->
        # do nothing else
    else
      WinRegistry.uninstallContextMenu ->
        # do nothing else
