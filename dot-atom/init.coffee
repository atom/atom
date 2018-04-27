# Your init script
#
# Atom will evaluate this file each time a new window is opened. It is run
# after packages are loaded/activated and after the previous editor state
# has been restored.
#
# An example hack to log to the console when each text editor is saved.
#
# atom.workspace.observeTextEditors (editor) ->
#   editor.onDidSave ->
#     console.log "Saved! #{editor.getPath()}"

atom.config.set 'atom-ide-ui.use.atom-ide-debugger', 'never'
atom.config.set 'atom-ide-ui.use.atom-ide-terminal', 'never'

path = require 'path'
cqueryExecutable = 'cquery' + (if navigator.platform == 'Win32' then '.exe' else '')
atom.config.set 'ide-cquery.cqueryPath', path.join(process.execPath, '..', '..', 'cquery', cqueryExecutable)
