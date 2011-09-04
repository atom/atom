# nice!

$ = require 'jquery'
_ = require 'underscore'

File = require 'fs'
App  = require 'app'
Pane = require 'pane'
activeWindow = App.activeWindow
{bindKey} = require 'keybinder'

ace = require 'ace/ace'

module.exports =
class Editor extends Pane
  filename: null

  constructor: ->
    @ace = ace.edit "editor"
    @ace.setTheme require "ace/theme/twilight"
    @ace.getSession().setUseSoftTabs true
    @ace.getSession().setTabSize 2
    @ace.pane = this

    @ace.getSession().on 'change', ->
      activeWindow.setDirty true

    el = document.body
    el.addEventListener 'DOMNodeInsertedIntoDocument', =>
      @resize()
    el.addEventListener 'DOMNodeRemovedFromDocument', =>
      @resize()

    # bug #13
    @resize 200

  save: ->
    File.write @filename, @ace.getSession().getValue()
    activeWindow.setDirty false
    @ace._emit 'save', { @filename }

  open: (path) ->
    @filename = path

    if File.isDirectory @filename
      File.changeWorkingDirectory @filename
      activeWindow.setTitle _.last @filename.split '/'
      @ace.getSession().setValue ""
      activeWindow.setDirty false
    else
      if /png|jpe?g|gif/i.test @filename
        App.openURL @filename
      else
        activeWindow.setTitle _.last @filename.split '/'
        @ace.getSession().setValue File.read @filename
        activeWindow.setDirty false
    @ace._emit 'open', { @filename }

  saveAs: ->
    if file = App.savePanel()
      @filename = file
      activeWindow.setTitle _.last @filename.split '/'
      @save()

  resize: (timeout=1) ->
    setTimeout =>
      @ace.focus()
      @ace.resize()
    , timeout


#
# keybindings
#

bindKey 'open', 'Command-O', (env, args, request) ->
  if file = App.openPanel()
    env.editor.pane.open file

bindKey 'openURL', 'Command-Shift-O', (env, args, request) ->
  if url = prompt "Enter URL:"
    App.openURL url

bindKey 'saveAs', 'Command-Shift-S', (env, args, request) ->
  env.editor.pane.saveAs()

bindKey 'save', 'Command-S', (env, args, request) ->
  doc = env.editor.pane
  if doc.filename then doc.save() else doc.saveAs()

bindKey 'new', 'Command-N', (env, args, request) ->
  App.newWindow()

bindKey 'copy', 'Command-C', (env, args, request) ->
  editor = env.editor
  text = editor.getSession().doc.getTextRange editor.getSelectionRange()
  App.writeToPasteboard text

bindKey 'cut', 'Command-X', (env, args, request) ->
  editor = env.editor
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
