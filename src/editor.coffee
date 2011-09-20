_ = require 'underscore'

File = require 'fs'
Chrome = require 'chrome'
Pane = require 'pane'

ace = require 'ace/ace'

{EditSession} = require 'ace/edit_session'
{UndoManager} = require 'ace/undomanager'

module.exports =
class Editor extends Pane
  filename: null

  position: 'main'
  html: '<div id="editor"></div>'

  keymap:
    'Command-S'       : 'save'
    'Command-Shift-S' : 'saveAs'
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
    'Ctrl-L'          : 'consolelog'

  sessions: {}

  initialize: ->
    window.r = require 'app'

    @ace = ace.edit "editor"
    @ace.setTheme require "ace/theme/twilight"
    @ace.getSession().setUseSoftTabs true
    @ace.getSession().setTabSize 2
    @ace.pane = this
    @ace.setShowInvisibles(true)
    @ace.setPrintMarginColumn 78

    @ace.getSession().on 'change', ->
      App = require 'app' # Get rid of this!
      App.activeWindow.setDirty true

    el = document.body
    el.addEventListener 'DOMNodeInsertedIntoDocument', =>
      @resize()
    el.addEventListener 'DOMNodeRemovedFromDocument', =>
      @resize()

  save: ->
    return @saveAs() if not @filename
    
    @removeTrailingWhitespace()
    File.write @filename, @code()
    @sessions[@filename] = @ace.getSession()
    App = require 'app' # Get rid of this!
    App.activeWindow.setDirty false
    @ace._emit 'save', { @filename }

  open: (path) ->
    App = require 'app' # Get rid of this!
    path = Chrome.openPanel() if not path
    return if not path
    @filename = path

    if File.isDirectory @filename
      File.changeWorkingDirectory @filename
      window.x = App
      App.activeWindow.setTitle _.last @filename.split '/'
      @ace.setSession @newSession()
      App.activeWindow.setDirty false
    else
      if /png|jpe?g|gif/i.test @filename
        Chrome.openURL @filename
      else
        App.activeWindow.setTitle _.last @filename.split '/'
        @sessions[@filename] or= @newSession File.read @filename
        @ace.setSession @sessions[@filename]
        App.activeWindow.setDirty false
    @ace._emit 'open', { @filename }

  close: (path) ->
    @deleteSession path
    @ace._emit 'close', { filename : path }

  saveAs: ->
    if file = Chrome.savePanel()
      @filename = file
      App = require 'app' # Get rid of this!
      App.activeWindow.setTitle _.last @filename.split '/'
      @save()

  code: ->
    @ace.getSession().getValue()

  removeTrailingWhitespace: ->
    return
    @ace.replaceAll "",
      needle: "[ \t]+$"
      regExp: true
      wrap: true

  resize: (timeout=1) ->
    setTimeout =>
      @ace.focus()
      @ace.resize()
    , timeout

  switchToSession: (path) ->
    if @sessions[path]
      @filename = path
      @ace.setSession @sessions[path]

  deleteSession: (path) ->
    if path is @filename
      @filename = null
    delete @sessions[path]
    @ace.setSession @newSession()

  newSession: (code) ->
    doc = new EditSession code or ''
    doc.setUndoManager new UndoManager
    doc.setUseSoftTabs useSoftTabs = @usesSoftTabs code
    doc.setTabSize if useSoftTabs then @guessTabSize code else 8
    doc

  usesSoftTabs: (code) ->
    not /^\t/m.test code or @code()

  guessTabSize: (code) ->
    # * ignores indentation of css/js block comments
    match = /^( +)[^*]/im.exec code || @code()
    match?[1].length or 2

  copy: ->
    editor = @ace
    text = editor.getSession().doc.getTextRange editor.getSelectionRange()
    Chrome.writeToPasteboard text

  cut: ->
    editor = @ace
    text = editor.getSession().doc.getTextRange editor.getSelectionRange()
    Chrome.writeToPasteboard text
    editor.session.remove editor.getSelectionRange()

  eval: ->
    eval @code()

  toggleComment: -> @ace.toggleCommentLines()
  outdent:       -> @ace.blockOutdent()
  indent:        -> @ace.indent()
  forwardWord:   -> @ace.navigateWordRight()
  backWord:      -> @ace.navigateWordLeft()
  deleteWord:    -> @ace.removeWordRight()
  home:          -> @ace.navigateFileStart()
  end:           -> @ace.navigateFileEnd()

  consolelog: ->
    @ace.insert 'console.log ""'
    @ace.navigateLeft()
