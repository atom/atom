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
  activePath: null

  sessions: {}

  constructor: (path) ->
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
    @ace.setSession @newSession()

    #@ace.getSession().on 'change', -> @window.setDirty true
    Event.on 'window:open', (e) => @open e.details
    Event.on 'window:close', (e) => @close e.details

    @open path

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
    return unless @activePath
    if mode = @modeForLanguage _.last @activePath.split '.'
      @ace.getSession().setMode new mode

  open: (path) ->
    return if fs.isDirectory path

    if not path
      @activePath = null
      @ace.setSession @newSession()
    else
      @activePath = path

      session = @sessions[path]
      if not session
        @sessions[path] = session = @newSession fs.read path
        session.on 'change', -> session.$atom_dirty = true

      @ace.setSession session
      @setMode()

      Event.trigger "editor:open", path

  close: (path) ->
    path ?= @activePath

    # ICK, clean this up... too many assumptions being made
    session = @sessions[path]
    if session?.$atom_dirty or (not session and @code.length > 0)
      detailedMessage = if @activePath
        "#{@activePath} has changes."
      else
        "An untitled file has changes."

      canceled = Native.alert "Do you want to save the changes you made?", detailedMessage,
        "Save": =>
          path = @save()
          not path # if save fails/cancels, consider it canceled
        "Cancel": => true
        "Don't Save": => false

      return if canceled

    delete @sessions[path]

    if path is @activePath
      @activePath = null
      @ace.setSession @newSession()

    Event.trigger "editor:close", path

  save: (path) ->
    path ?= @activePath

    return @saveAs() if not path

    @removeTrailingWhitespace()
    fs.write path, @code()
    if @sessions[path]
      @sessions[path].$atom_dirty = false

    path

  saveAs: ->
    path = Native.savePanel()?.toString()
    if path
      @save path
      @open path

    path

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
      @ace.focus()
      @ace.resize()
    , timeout

  copy: ->
    text = @ace.getSession().doc.getTextRange @ace.getSelectionRange()
    Native.writeToPasteboard text

  cut: ->
    text = @ace.getSession().doc.getTextRange @ace.getSelectionRange()
    Native.writeToPasteboard text
    @ace.session.remove @ace.getSelectionRange()

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
