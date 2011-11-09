$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'
ace = require 'ace/ace'

Pane = require 'pane'

{EditSession} = require 'ace/edit_session'
{UndoManager} = require 'ace/undomanager'

module.exports =
class Editor extends Pane
  activePath: null

  buffers: {}

  openPathsKey: "editor.openPaths.#{window.path}"

  focusedPathKey: "editor.focusedPath.#{window.path}"

  html: $ "<div id='ace-editor'></div>"

  position: "main"

  constructor: ->
    atom.keybinder.register "editor", @

    @show()

    @ace = ace.edit 'ace-editor'

    # This stuff should all be grabbed from the .atomicity dir
    @ace.setTheme require "ace/theme/twilight"
    @ace.getSession().setUseSoftTabs true
    @ace.getSession().setTabSize 2
    @ace.setShowInvisibles(true)
    @ace.setPrintMarginColumn 78

    atom.event.on 'window:open', (e) =>
      path = e.details
      @addBuffer e.details if fs.isFile path

    atom.event.on 'window:close', (e) => @removeBuffer e.details
    atom.event.on 'editor:bufferFocus', (e) => @resize()

    # Resize editor when panes are added/removed
    el = document.body
    el.addEventListener 'DOMNodeInsertedIntoDocument', => @resize()
    el.addEventListener 'DOMNodeRemovedFromDocument', => @resize()
    setTimeout =>
      @resize()
    , 500

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

  modeForPath: (path) ->
    return null if not path

    if not modeName = @modeFileMap[ _.last path.split '/' ]
      language = _.last path.split '.'
      language = language.toLowerCase()
      modeName = @modeMap[language] or language

    try
      require("ace/mode/#{modeName}").Mode
    catch e
      null

  restoreOpenBuffers: ->
    openPaths = atom.storage.get @openPathsKey, []
    focusedPath = atom.storage.get(@focusedPathKey)

    @addBuffer path for path in openPaths
    @focusBuffer focusedPath if focusedPath

  addBuffer: (path) ->
    throw "#{@constructor.name}: Cannot create buffer from a directory `#{path}`" if fs.isDirectory path

    buffer = @buffers[path]
    if not buffer
      code = if path then fs.read path else ''
      buffer = new EditSession code
      buffer.setUndoManager new UndoManager
      buffer.setUseSoftTabs useSoftTabs = @usesSoftTabs code
      buffer.setTabSize if useSoftTabs then @guessTabSize code else 8

      mode = @modeForPath path
      buffer.setMode new mode if mode

      @buffers[path] = buffer

    openPaths = atom.storage.get @openPathsKey, []
    unless path in openPaths
      openPaths.push path
      atom.storage.set @openPathsKey, openPaths

    buffer.on 'change', -> buffer.$atom_dirty = true
    atom.event.trigger "editor:bufferAdd", path

    @focusBuffer path

  removeBuffer: (path) ->
    path ?= @activePath

    return if not path

    buffer = @buffers[path]
    return if not buffer

    if buffer.$atom_dirty
      # This should be thrown into it's own method, but I can't think of a good
      # name.
      detailedMessage = if @activePath
        "#{@activePath} has changes."
      else
        "An untitled file has changes."

      canceled = atom.native.alert "Do you want to save the changes you made?", detailedMessage,
        "Save": =>
          path = @save()
          not path # if save modal fails/cancels, consider it canceled
        "Cancel": => true
        "Don't Save": => false

      return if canceled

    delete @buffers[path]

    openPaths = atom.storage.get @openPathsKey, []
    atom.storage.set @openPathsKey, _.without openPaths, path
    atom.event.trigger "editor:bufferRemove", path

    if path is @activePath
      newActivePath = Object.keys(@buffers)[0]
      if newActivePath
        @focusBuffer newActivePath
      else
        @ace.setSession  new EditSession ''

  focusBuffer: (path) ->
    return if not path

    @show()
    @activePath = path

    buffer = @buffers[path] or @addBuffer path
    @ace.setSession buffer

    atom.storage.set @focusedPathKey, path
    atom.event.trigger "editor:bufferFocus", path

  save: (path) ->
    path ?= @activePath

    return @saveAs() if not path

    @removeTrailingWhitespace()
    fs.write path, @code()
    if @buffers[path]
      @buffers[path].$atom_dirty = false

    path

  saveAs: ->
    path = atom.native.savePanel()?.toString()
    if path
      @save path
      @addBuffer path

    path

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
