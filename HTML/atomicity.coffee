console.log = OSX.NSLog

editor = ace.edit "editor"
editor.setTheme "ace/theme/twilight"
JavaScriptMode = require("ace/mode/javascript").Mode
editor.getSession().setMode new JavaScriptMode
editor.getSession().setUseSoftTabs true
editor.getSession().setTabSize 2

filename = null
save = ->
  File.write filename, editor.getSession().getValue()

saveAs = ->
  if file = Chrome.savePanel()
    filename = file
    App.window.title = _.last filename.split('/')
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
  if file = Chrome.openPanel()
    filename = file
    App.window.title = _.last filename.split('/')
    code = File.read file
    env.editor.getSession().setValue code

bindKey 'saveAs', 'Command-Shift-S', (env, args, request) ->
  saveAs()

bindKey 'save', 'Command-S', (env, args, request) ->
  if filename then save() else saveAs()

bindKey 'copy', 'Command-C', (env, args, request) ->
  text = editor.getSession().doc.getTextRange editor.getSelectionRange()
  Chrome.writeToPasteboard text

bindKey 'eval', 'Command-R', (env, args, request) ->
  eval env.editor.getSession().getValue()

bindKey 'togglecomment', 'Command-/', (env) ->
  env.editor.toggleCommentLines()

bindKey 'fullscreen', 'Command-Return', (env) ->
  OSX.NSLog 'coming soon'
