console.log = OSX.NSLog

editor = ace.edit "editor"
editor.setTheme "ace/theme/twilight"
JavaScriptMode = require("ace/mode/javascript").Mode
CoffeeMode = require("ace/mode/coffee").Mode
editor.getSession().setMode new JavaScriptMode
editor.getSession().setUseSoftTabs true
editor.getSession().setTabSize 2

filename = null
save = ->
  File.write filename, editor.getSession().getValue()
  setMode()
open = ->
  Chrome.title _.last filename.split('/')
  editor.getSession().setValue File.read filename
  setMode()
setMode = ->
  if /\.js$/.test filename
    editor.getSession().setMode new JavaScriptMode
  else if /\.coffee$/.test filename
    editor.getSession().setMode new CoffeeMode
saveAs = ->
  if file = Chrome.savePanel()
    filename = file
    Chrome.title _.last filename.split('/')
    save()

Chrome.bindKey 'open', 'Command-O', (env, args, request) ->
  if file = Chrome.openPanel()
    filename = file
    open()

Chrome.bindKey 'saveAs', 'Command-Shift-S', (env, args, request) ->
  saveAs()

Chrome.bindKey 'save', 'Command-S', (env, args, request) ->
  if filename then save() else saveAs()

Chrome.bindKey 'copy', 'Command-C', (env, args, request) ->
  text = editor.getSession().doc.getTextRange editor.getSelectionRange()
  Chrome.writeToPasteboard text

Chrome.bindKey 'eval', 'Command-R', (env, args, request) ->
  eval env.editor.getSession().getValue()

# textmate

Chrome.bindKey 'togglecomment', 'Command-/', (env) ->
  env.editor.toggleCommentLines()

# emacs > you

Chrome.bindKey 'moveforward', 'Alt-F', (env) ->
  env.editor.navigateWordRight()

Chrome.bindKey 'moveback', 'Alt-B', (env) ->
  env.editor.navigateWordLeft()

Chrome.bindKey 'deleteword', 'Alt-D', (env) ->
  env.editor.removeWordRight()

Chrome.bindKey 'selectwordright', 'Alt-B', (env) ->
  env.editor.navigateWordLeft()

Chrome.bindKey 'home', 'Alt-Shift-<', (env) ->
  env.editor.navigateFileStart()

Chrome.bindKey 'end', 'Alt-Shift->', (env) ->
  env.editor.navigateFileEnd()

Chrome.bindKey 'fullscreen', 'Command-Shift-Return', (env) ->
  Chrome.fullscreen()



# HAX
# this should go in coffee.coffee or something
Chrome.bindKey 'consolelog', 'Ctrl-L', (env) ->
  env.editor.insert 'console.log ""'
  env.editor.navigateLeft()