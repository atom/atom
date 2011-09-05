_ = require 'underscore'

File = require 'fs'
App  = require 'app'
Pane = require 'pane'
activeWindow = App.activeWindow

ace = require 'ace/ace'

module.exports =
class Editor extends Pane
  filename: null

  keymap:
    'Command-O'       : 'open'
    'Command-Shift-O' : 'openURL'
    'Command-S'       : 'save'
    'Command-Shift-S' : 'saveAs'
    'Command-N'       : 'new'
    'Command-C'       : 'copy'
    'Command-X'       : 'cut'
    'Command-R'       : 'eval'
    'Command-/'       : 'toggleComment'
    'Command-['       : 'outdent'
    'Command-]'       : 'indent'
    'Alt-F'           : 'forwardWord'
    'Alt-B'           : 'backWord'
    'Alt-D'           : 'deleteWord'
    'Alt-Shift-,'     : 'home'
    'Alt-Shift-.'     : 'end'
    'Command-Ctrl-K'  : 'console'
    'Command-Ctrl-R'  : 'reload'
    'Ctrl-L'          : 'consolelog'

  initialize: ->
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
    return @saveAs() if not @filename

    File.write @filename, @ace.getSession().getValue()
    activeWindow.setDirty false
    @ace._emit 'save', { @filename }

  open: (path) ->
    path = App.openPanel() if not path
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

  openURL: ->
    if url = prompt "Enter URL:"
      App.openURL url

  new: ->
    App.newWindow()

  copy: ->
    editor = @ace
    text = editor.getSession().doc.getTextRange editor.getSelectionRange()
    App.writeToPasteboard text

  cut: ->
    editor = @ace
    text = editor.getSession().doc.getTextRange editor.getSelectionRange()
    App.writeToPasteboard text
    editor.session.remove editor.getSelectionRange()

  eval: ->
    eval @ace.getSession().getValue()

  toggleComment: -> @ace.toggleCommentLines()
  outdent:       -> @ace.blockOutdent()
  indent:        -> @ace.indent()
  forwardWord:   -> @ace.navigateWordRight()
  backWord:      -> @ace.navigateWordLeft()
  deleteWord:    -> @ace.removeWordRight()
  home:          -> @ace.navigateFileStart()
  end:           -> @ace.navigateFileEnd()
  console:       -> activeWindow.inspector().showConsole(1)

  reload: ->
    App.newWindow()
    activeWindow.close()

  consolelog: ->
    @ace.insert 'console.log ""'
    @ace.navigateLeft()
