# nice!

{Chrome, File, Process, Dir} = require 'lib/osx'

ace = require 'ace/ace'
canon = require 'pilot/canon'

_ = require 'vendor/underscore'
$ = require 'vendor/jquery'
{CoffeeScript} = require 'vendor/coffee-script'

editor = ace.edit "editor"
editor.setTheme require "ace/theme/twilight"
JavaScriptMode = require("ace/mode/javascript").Mode
CoffeeMode = require("ace/mode/coffee").Mode
HTMLMode = require("ace/mode/html").Mode
editor.getSession().setMode new JavaScriptMode
editor.getSession().setUseSoftTabs true
editor.getSession().setTabSize 2
editor.focus()

if css = File.read "~/.atomicity/twilight.css"
  head = $('head')[0]
  style = document.createElement 'style'
  rules = document.createTextNode css
  style.type = 'text/css'
  style.appendChild rules
  head.appendChild style

_.map Dir.list("~/.atomicity/"), (path) ->
  if /\.js$/.test path
    $.getScript path
  else if /\.coffee/.test path
    eval CoffeeScript.compile File.read path

filename = null
editor.getSession().on 'change', ->
  Chrome.setDirty true
save = ->
  File.write filename, editor.getSession().getValue()
  setMode()
  Chrome.setDirty false
open = ->
  if /png|jpe?g|gif/i.test filename
    Chrome.openURL filename
  else
    Chrome.title _.last filename.split('/')
    editor.getSession().setValue File.read filename
    setMode()
    Chrome.setDirty false
setMode = ->
  if /\.js$/.test filename
    editor.getSession().setMode new JavaScriptMode
  else if /\.coffee$/.test filename
    editor.getSession().setMode new CoffeeMode
  else if /\.html/.test filename
    editor.getSession().setMode new HTMLMode
saveAs = ->
  if file = Chrome.savePanel()
    filename = file
    Chrome.title _.last filename.split('/')
    save()
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
    open()

bindKey 'openURL', 'Command-Shift-O', (env, args, request) ->
  if url = prompt "Enter URL:"
    Chrome.openURL url

bindKey 'saveAs', 'Command-Shift-S', (env, args, request) ->
  saveAs()

bindKey 'save', 'Command-S', (env, args, request) ->
  if filename then save() else saveAs()

bindKey 'new', 'Command-N', (env, args, request) ->
  Chrome.createWindow()

bindKey 'copy', 'Command-C', (env, args, request) ->
  text = editor.getSession().doc.getTextRange editor.getSelectionRange()
  Chrome.writeToPasteboard text

bindKey 'cut', 'Command-X', (env, args, request) ->
  text = editor.getSession().doc.getTextRange editor.getSelectionRange()
  Chrome.writeToPasteboard text
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

bindKey 'fullscreen', 'Command-Shift-Return', (env) ->
  Chrome.toggleFullscreen()



# HAX
# this should go in coffee.coffee or something
bindKey 'consolelog', 'Ctrl-L', (env) ->
  env.editor.insert 'console.log ""'
  env.editor.navigateLeft()

bindKey 'toggleProjectDrawer', 'Command-Ctrl-N', (env) ->
  Project.toggle()