_ = require 'underscore'
fs = require 'fs'
ace = require 'ace/ace'

Event = require 'event'
KeyBinder = require 'key-binder'
Native = require 'native'

{EditSession} = require 'ace/edit_session'
{UndoManager} = require 'ace/undomanager'

module.exports =
class Editor
  filename: null

  sessions: {}

  constructor: ->
    KeyBinder.register "editor", @
    # Resize editor when panes are added/removed
    el = document.body
    el.addEventListener 'DOMNodeInsertedIntoDocument', => @resize()
    el.addEventListener 'DOMNodeRemovedFromDocument', => @resize()

    @ace = ace.edit "ace-editor"

    # This stuff should all be grabbed from the .atomicity dir
    @ace.setTheme require "ace/theme/twilight"
    @ace.getSession().setUseSoftTabs true
    @ace.getSession().setTabSize 2
    @ace.setShowInvisibles(true)
    @ace.setPrintMarginColumn 78

    #@ace.getSession().on 'change', -> @window.setDirty true
    Event.on 'window:open', (e) => @open e.details
    Event.on 'window:close', (e) => @close e.details

  modeMap:
    js: 'javascript'
    c: 'c_cpp'
    cpp: 'c_cpp'
    h: 'c_cpp'
    m: 'c_cpp'
    md: 'markdown'
    cs: 'csharp'
    rb: 'ruby'

  modeForLanguage: (language) ->
    language = language.toLowerCase()
    modeName = @modeMap[language] or language

    try
      require("ace/mode/#{modeName}").Mode
    catch e
      null

  setMode: ->
    if mode = @modeForLanguage _.last @activePath.split '.'
      @ace.getSession().setMode new mode

  save: ->
    return @saveAs() if not @activePath

    @removeTrailingWhitespace()
    fs.write @activePath, @code()
    @sessions[@activePath] = @ace.getSession()
    #@window.setDirty false
    #@window._emit 'save', { filename: @activePath }

  open: (path) ->
    return unless fs.isFile path
    @activePath = path

    @sessions[@activePath] ?= @newSession fs.read @activePath
    @ace.setSession @sessions[@activePath]
    @setMode()

  close: (path) ->
    @activePath = null if path is @activePath

    delete @sessions[path]
    @ace.setSession @newSession()

  saveAs: ->
    if path = Native.savePanel()
      @activePath = path
      #@window.setTitle _.last @activePath.split '/'
      @save()

  code: ->
    @ace.getSession().getValue()

  removeTrailingWhitespace: ->
    return
    @ace.replaceAll "",
      needle: "[ \t]+$"
      regExp: true
      wrap: true

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

  resize: (timeout=1) ->
    setTimeout =>
      @editor.ace.focus()
      @editor.ace.resize()
    , timeout

  copy: ->
    editor = @ace
    text = editor.getSession().doc.getTextRange editor.getSelectionRange()
    Native.writeToPasteboard text

  cut: ->
    editor = @ace
    text = editor.getSession().doc.getTextRange editor.getSelectionRange()
    Native.writeToPasteboard text
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
