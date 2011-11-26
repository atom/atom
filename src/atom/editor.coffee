$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'
Resource = require 'resource'
EditorPane = require 'editor-pane'

{EditSession} = require 'ace/edit_session'
{UndoManager} = require 'ace/undomanager'

# Events:
#   editor:open (editor) -> Called when an editor is opened.
#   editor:close (editor) -> Called when an editor is closed.
module.exports =
class Editor extends Resource
  window.resourceTypes.push this

  dirty: false

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
    mustache: 'html'

  modeFileMap:
    Gemfile: 'ruby'
    Rakefile: 'ruby'

  settings:
    theme: 'twilight'
    softTabs: true
    tabSize: 2
    showInvisibles: false
    marginColumn: 80

  modeForURL: (url) ->
    return if not url

    if not modeName = @modeFileMap[ _.last url.split '/' ]
      language = _.last url.split '.'
      language = language.toLowerCase()
      modeName = @modeMap[language] or language

    try
      require("ace/mode/#{modeName}").Mode
    catch e
      console.error e
      require("ace/mode/text").Mode

  setModeForURL: (url) ->
    @pane.ace.session.setMode new (@modeForURL url)

  title: ->
    if @url then _.last @url.split '/' else 'untitled'

  show: (code) ->
    window.setTitle @title()

    @pane ?= new EditorPane
    @pane.show()

    if not @session
      @session = new EditSession code or ''
      @session.setValue code or ''
      @session.setUseSoftTabs @settings.softTabs
      @session.setTabSize if @settings.softTabs then @settings.tabSize else 8
      @session.setUndoManager new UndoManager
      @session.on 'change', => @dirty = true
      @pane.ace.setSession @session
      @setModeForURL @url if @url
      @dirty = false
      @pane.ace.setTheme require "ace/theme/#{@settings.theme}"
      @pane.ace.setShowInvisibles @settings.showInvisibles
      @pane.ace.setPrintMarginColumn @settings.marginColumn

    @pane.ace.resize()

  open: (url) ->
    if url
      return false if not fs.isFile url
      return false if @url

    @url = url
    @show if @url then fs.read @url else ''

    atom.trigger 'editor:open', this

    true

  close: ->
    if @dirty
      detailedMessage = if @url
        "#{@url} has changes."
      else
        "An untitled file has changes."

      close = atom.native.alert "Do you want to save your changes?",
        detailedMessage,
        "Save": => @save()
        "Cancel": => false
        "Don't Save": => true

      return not close

    atom.trigger 'editor:close', this

    super

  save: ->
    return @saveAs() if not @url

    @removeTrailingWhitespace()
    fs.write @url, @code()
    @dirty = false

    @url

  saveAs: ->
    if url = atom.native.savePanel()?.toString()
      @url = url
      @save url

  code: ->
    @pane.ace.getSession().getValue()

  setCode: (code) ->
    @pane.ace.getSession().setValue code

  removeTrailingWhitespace: ->
    @pane.ace.replaceAll "",
      needle: "[ \t]+$"
      regExp: true
      wrap: true

  usesSoftTabs: (code) ->
    not /^\t/m.test code or @code()

  guessTabSize: (code) ->
    # * ignores indentation of css/js block comments
    match = /^( +)[^*]/im.exec code || @code()
    match?[1].length or 2

  copy: ->
    text = @pane.ace.getSession().doc.getTextRange @pane.ace.getSelectionRange()
    atom.native.writeToPasteboard text

  cut: ->
    text = @pane.ace.getSession().doc.getTextRange @pane.ace.getSelectionRange()
    atom.native.writeToPasteboard text
    @pane.ace.session.remove @pane.ace.getSelectionRange()

  eval: -> eval @code()
  toggleComment: -> @pane.ace.toggleCommentLines()
  outdent: -> @pane.ace.blockOutdent()
  indent: -> @pane.ace.indent()
  forwardWord: -> @pane.ace.navigateWordRight()
  backWord: -> @pane.ace.navigateWordLeft()
  deleteWord: -> @pane.ace.removeWordRight()
  home: -> @pane.ace.navigateFileStart()
  end: -> @pane.ace.navigateFileEnd()

  wordWrap: ->
    @pane.ace.getSession().setUseWrapMode true

  consolelog: ->
    @pane.ace.insert 'console.log ""'
    @pane.ace.navigateLeft()
