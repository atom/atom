$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'
Resource = require 'resource'
EditorPane = require 'editor-pane'

{EditSession} = require 'ace/edit_session'
{UndoManager} = require 'ace/undomanager'

# Events:
#   editor:open (editor) -> Called when an editor is opened.
module.exports =
class Editor extends Resource
  window.resourceTypes.push this

  dirty: false

  url: null

  pane: null

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
    @ace.session.setMode new (@modeForURL url)

  title: ->
    if @url then _.last @url.split '/' else 'untitled'

  show: ->
    @ace.setSession @session
    @pane.show()
    @ace.resize()
    window.setTitle @title()

  open: (url) ->
    if url
      return false if not fs.isFile url
      return false if @url

    # HACK! We want only one EditorPane for all the Editors.
    @pane = Editor.pane ?= new EditorPane
    @ace = @pane.ace
    @url = url

    @session = new EditSession code = if @url then fs.read @url else ''
    @session.setValue code
    @session.setUseSoftTabs useSoftTabs = @usesSoftTabs code
    @session.setTabSize if useSoftTabs then @guessTabSize code else 8
    @session.setUndoManager new UndoManager
    @session.on 'change', => @dirty = true

    @show()
    @setModeForURL @url if @url

    @dirty = false
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

      return if not close

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
    @ace.getSession().getValue()

  setCode: (code) ->
    @ace.getSession().setValue code

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
