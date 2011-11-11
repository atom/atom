$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'
Document = require 'document'

ace = require 'ace/ace'
{EditSession} = require 'ace/edit_session'
{UndoManager} = require 'ace/undomanager'

module.exports =
class Editor extends Document
  @register (path) ->
    not path or fs.isFile path

  dirty: false
  path: null
  html: $ "<div id='ace-editor'></div>"

  constructor: ->
    @show()

    @ace = ace.edit 'ace-editor'

    # This stuff should all be grabbed from the .atomicity dir
    @ace.setTheme require "ace/theme/twilight"
    @ace.getSession().setUseSoftTabs true
    @ace.getSession().setTabSize 2
    @ace.setShowInvisibles true
    @ace.setPrintMarginColumn 78

    # Resize editor when panes are added/removed
    el = document.body
    el.addEventListener 'DOMNodeInsertedIntoDocument', => @resize()
    el.addEventListener 'DOMNodeRemovedFromDocument', => @resize()
    setTimeout (=> @resize()), 500

    session = new EditSession ''
    session.on 'change', => @dirty = true
    session.setUndoManager new UndoManager
    @ace.setSession session

    super()

  modeMap:
    js: 'javascript'
    c: 'c_cpp'
    cpp: 'c_cpp'
    h: 'c_cpp'
    m: 'c_cpp'
    md: 'markdown'
    cs: 'csharp'
    rb: 'ruby'
    ru: 'ruby'
    gemspec: 'ruby'

  modeFileMap:
    Gemfile: 'ruby'
    Rakefile: 'ruby'

  modeForPath: (path=@path) ->
    return null if not path

    if not modeName = @modeFileMap[ _.last path.split '/' ]
      language = _.last path.split '.'
      language = language.toLowerCase()
      modeName = @modeMap[language] or language

    try
      require("ace/mode/#{modeName}").Mode
    catch e
      null

  title: ->
    if @path then _.last @path.split '/' else 'untitled'

  open: (path) ->
    return false if not super

    @path = path
    @dirty = false

    code = if @path then fs.read @path else ''
    session = @ace.getSession()
    session.setValue code
    session.setUseSoftTabs useSoftTabs = @usesSoftTabs code
    session.setTabSize if useSoftTabs then @guessTabSize code else 8
    session.setUndoManager new UndoManager
    mode = @modeForPath()
    session.setMode new mode if mode

    window.setTitle @title()

    true

  close: ->
    if @dirty
      detailedMessage = if @path
        "#{@path} has changes."
      else
        "An untitled file has changes."

      close = atom.native.alert "Do you want to save your changes?",
        detailedMessage,
        "Save": => @save()
        "Cancel": => false
        "Don't Save": => true

      return if not close

    super

  save: ->
    return @saveAs() if not @path

    @removeTrailingWhitespace()
    fs.write @path, @code()
    @dirty = false

    @path

  saveAs: ->
    if path = atom.native.savePanel()?.toString()
      @path = path
      @save path

  code: ->
    @ace.getSession().getValue()

  removeTrailingWhitespace: ->
    return
    @ace.replaceAll "",
      needle: "[ \t]+$"
      regExp: true
      wrap: true

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
    atom.native.writeToPasteboard text

  cut: ->
    text = @ace.getSession().doc.getTextRange @ace.getSelectionRange()
    atom.native.writeToPasteboard text
    @ace.session.remove @ace.getSelectionRange()

  eval: -> eval @code()
  toggleComment: -> @ace.toggleCommentLines()
  outdent: -> @ace.blockOutdent()
  indent: -> @ace.indent()
  forwardWord: -> @ace.navigateWordRight()
  backWord: -> @ace.navigateWordLeft()
  deleteWord: -> @ace.removeWordRight()
  home: -> @ace.navigateFileStart()
  end: -> @ace.navigateFileEnd()

  consolelog: ->
    @ace.insert 'console.log ""'
    @ace.navigateLeft()
