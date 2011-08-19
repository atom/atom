console.log = OSX.NSLog

editor = ace.edit "editor"
editor.setTheme "ace/theme/twilight"
JavaScriptMode = require("ace/mode/javascript").Mode
editor.getSession().setMode new JavaScriptMode()

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
    env.editor.getSession().setValue OSX.NSString.stringWithContentsOfFile file

bindKey 'eval', 'Command-R', (env, args, request) ->
  eval env.editor.getSession().getValue()

bindKey 'togglecomment', 'Command-/', (env) ->
  env.editor.toggleCommentLines()

bindKey 'fullscreen', 'Command-Return', (env) ->
  OSX.NSLog 'coming soon'