_ = require 'underscore'

File = require 'fs'
Chrome = require 'chrome'
Extension = require 'extension'
EditorPane = require 'editor/editor-pane'

{bindKey} = require 'keybinder'

ace = require 'ace/ace'

{EditSession} = require 'ace/edit_session'
{UndoManager} = require 'ace/undomanager'

module.exports =
class Editor extends Extension
  filename: null

  keymap: ->
    # Maybe these don't go here?
    'Command-S'       : 'save'
    'Command-Shift-S' : 'saveAs'

    # These are cool though.
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

  modeMap:
    js: 'javascript'
    c: 'c_cpp'
    cpp: 'c_cpp'
    h: 'c_cpp'
    m: 'c_cpp'
    md: 'markdown'
    cs: 'csharp'
    rb: 'ruby'

  sessions: {}

  constructor: (args...) ->
    super(args...)

    @pane = new EditorPane @window
    @pane.add()

    @ace = ace.edit "editor"

    # This stuff should all be grabbed from the .atomicity dir
    @ace.setTheme require "ace/theme/twilight"
    @ace.getSession().setUseSoftTabs true
    @ace.getSession().setTabSize 2
    @ace.setShowInvisibles(true)
    @ace.setPrintMarginColumn 78

    @ace.getSession().on 'change', -> @window.setDirty true
    @window.on 'open', ({filename}) => @open filename
    @window.on 'close', ({filename}) => @close filename

  modeForLanguage: (language) ->
    language = language.toLowerCase()
    modeName = @modeMap[language] or language

    try
      require("ace/mode/#{modeName}").Mode
    catch e
      null

  setMode: ->
    if mode = @modeForLanguage _.last @filename.split '.'
      @ace.getSession().setMode new mode

  save: ->
    return @saveAs() if not @filename

    @removeTrailingWhitespace()
    File.write @filename, @code()
    @sessions[@filename] = @ace.getSession()
    @window.setDirty false
    @window._emit 'save', { filename: @filename }

  open: (path) ->
    path = Chrome.openPanel() if not path
    return if not path
    @filename = path

    if File.isDirectory @filename
      File.changeWorkingDirectory @filename
      @window.setTitle _.last @filename.split '/'
      @ace.setSession @newSession()
      @window.setDirty false
    else
      if /png|jpe?g|gif/i.test @filename
        Chrome.openURL @filename
      else
        @window.setTitle _.last @filename.split '/'
        @sessions[@filename] or= @newSession File.read @filename
        @ace.setSession @sessions[@filename]
        @window.setDirty false
        @setMode()

  close: (path) ->
    @deleteSession path

  saveAs: ->
    if file = Chrome.savePanel()
      @filename = file
      @window.setTitle _.last @filename.split '/'
      @save()

  code: ->
    @ace.getSession().getValue()

  removeTrailingWhitespace: ->
    return
    @ace.replaceAll "",
      needle: "[ \t]+$"
      regExp: true
      wrap: true

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
