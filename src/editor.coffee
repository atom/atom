# nice!

$ = require 'jquery'
_ = require 'underscore'

File = require 'fs'
App  = require 'app'
activeWindow = App.activeWindow

ace = require 'ace/ace'
canon = require 'pilot/canon'

exports.ace = editor = ace.edit "editor"
editor.setTheme require "ace/theme/twilight"
editor.getSession().setUseSoftTabs true
editor.getSession().setTabSize 2

filename = null
editor.getSession().on 'change', ->
  activeWindow.setDirty true
save = ->
  File.write filename, editor.getSession().getValue()
  activeWindow.setDirty false
  editor._emit 'save', { filename }
exports.open = open = (path) ->
  filename = path

  if File.isDirectory filename
    File.changeWorkingDirectory filename
    activeWindow.setTitle _.last filename.split '/'
    editor.getSession().setValue ""
    activeWindow.setDirty false
  else
    if /png|jpe?g|gif/i.test filename
      App.openURL filename
    else
      activeWindow.setTitle _.last filename.split '/'
      editor.getSession().setValue File.read filename
      activeWindow.setDirty false
  editor._emit 'open', { filename }
saveAs = ->
  if file = App.savePanel()
    filename = file
    activeWindow.setTitle _.last filename.split '/'
    save()
exports.bindKey = bindKey = (name, shortcut, callback) ->
  canon.addCommand
    name: name
    exec: callback
    bindKey:
      win: null
      mac: shortcut
      sender: 'editor'
exports.resize = (timeout=1) ->
  setTimeout ->
    editor.focus()
    editor.resize()
  , timeout

exports.resize(200)

bindKey 'open', 'Command-O', (env, args, request) ->
  if file = App.openPanel()
    open file

bindKey 'openURL', 'Command-Shift-O', (env, args, request) ->
  if url = prompt "Enter URL:"
    App.openURL url

bindKey 'saveAs', 'Command-Shift-S', (env, args, request) ->
  saveAs()

bindKey 'save', 'Command-S', (env, args, request) ->
  if filename then save() else saveAs()

bindKey 'new', 'Command-N', (env, args, request) ->
  App.newWindow()

bindKey 'copy', 'Command-C', (env, args, request) ->
  text = editor.getSession().doc.getTextRange editor.getSelectionRange()
  App.writeToPasteboard text

bindKey 'cut', 'Command-X', (env, args, request) ->
  text = editor.getSession().doc.getTextRange editor.getSelectionRange()
  App.writeToPasteboard text
  editor.session.remove editor.getSelectionRange()

bindKey 'eval', 'Command-R', (env, args, request) ->
  eval env.editor.getSession().getValue()

# textmate

bindKey 'togglecomment', 'Command-/', (env) ->
  env.editor.toggleCommentLines()

bindKey 'tmoutdent', 'Command-[', (env) ->
  env.editor.blockOutdent()

bindKey 'tmindent', 'Command-]', (env) ->
  env.editor.indent()

# emacs > you

bindKey 'moveforward', 'Alt-F', (env) ->
  env.editor.navigateWordRight()

bindKey 'moveback', 'Alt-B', (env) ->
  env.editor.navigateWordLeft()

bindKey 'deleteword', 'Alt-D', (env) ->
  env.editor.removeWordRight()

bindKey 'selectwordright', 'Alt-B', (env) ->
  env.editor.navigateWordLeft()

bindKey 'home', 'Alt-Shift-,', (env) ->
  env.editor.navigateFileStart()

bindKey 'end', 'Alt-Shift-.', (env) ->
  env.editor.navigateFileEnd()

bindKey 'console', 'Command-Ctrl-k', (env) ->
  activeWindow.inspector().showConsole(1)

bindKey 'reload', 'Command-Ctrl-r', (env) ->
  App.newWindow()
  activeWindow.close()

# this should go in coffee.coffee or something
bindKey 'consolelog', 'Ctrl-L', (env) ->
  env.editor.insert 'console.log ""'
  env.editor.navigateLeft()
