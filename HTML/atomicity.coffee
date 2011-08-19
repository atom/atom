console.log = OSX.NSLog

editor = ace.edit "editor"
editor.setTheme "ace/theme/twilight"
JavaScriptMode = require("ace/mode/javascript").Mode
editor.getSession().setMode new JavaScriptMode()

filename = null
save = ->
  str = OSX.NSString.stringWithString editor.getSession().getValue()
  str.writeToFile_atomically filename, true

saveAs = ->
  panel = OSX.NSSavePanel.savePanel
  if panel.runModal isnt OSX.NSFileHandlingPanelOKButton
    return null
  if file = panel.filenames.lastObject
    filename = file
    save()

canon = require 'pilot/canon'

bindKey = (name, shortcut, callback) ->
  canon.addCommand
    name: name
    exec: callback
    bindKey:
      win: null
      mac: shortcut
      sender: 'editor'

bindKey 'open', 'Command-O', (env, args, request) ->
  panel = OSX.NSOpenPanel.openPanel

  if panel.runModal isnt OSX.NSFileHandlingPanelOKButton
    return null

  if file = panel.filenames.lastObject
    filename = file
    code = OSX.NSString.stringWithContentsOfFile file
    env.editor.getSession().setValue code

bindKey 'saveAs', 'Command-Shift-S', (env, args, request) ->
  saveAs()

bindKey 'save', 'Command-S', (env, args, request) ->
  if filename then save() else saveAs()

bindKey 'eval', 'Command-R', (env, args, request) ->
  eval env.editor.getSession().getValue()

bindKey 'togglecomment', 'Command-/', (env) ->
  env.editor.toggleCommentLines()

bindKey 'fullscreen', 'Command-Return', (env) ->
  OSX.NSLog 'coming soon'