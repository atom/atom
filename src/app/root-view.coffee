$ = require 'jquery'
{$$} = require 'space-pen'
fsUtils = require 'fs-utils'
_ = require 'underscore'
telepath = require 'telepath'
{View} = require 'space-pen'
Buffer = require 'text-buffer'
Editor = require 'editor'
Project = require 'project'
Pane = require 'pane'
PaneColumn = require 'pane-column'
PaneRow = require 'pane-row'
PaneContainer = require 'pane-container'
EditSession = require 'edit-session'

# Public: The container for the entire Atom application.
module.exports =
class RootView extends View
  registerDeserializers(this, Pane, PaneRow, PaneColumn, Editor)

  @version: 1

  @configDefaults:
    ignoredNames: [".git", ".svn", ".DS_Store"]
    disabledPackages: []
    themes: ['atom-dark-ui', 'atom-dark-syntax']

  ### Internal ###
  @acceptsDocuments: true

  @content: (state) ->
    @div id: 'root-view', =>
      @div id: 'horizontal', outlet: 'horizontal', =>
        @div id: 'vertical', outlet: 'vertical', =>
          @subview 'panes', deserialize(state?.get?('panes')) ? new PaneContainer

  @deserialize: (state) ->
    new RootView(state)

  initialize: (state={}) ->
    if state instanceof telepath.Document
      @state = state
    else
      @state = telepath.Document.create(_.extend({version: RootView.version, deserializer: 'RootView', panes: @panes.serialize()}, state))

    @on 'focus', (e) => @handleFocus(e)
    @subscribe $(window), 'focus', (e) =>
      @handleFocus(e) if document.activeElement is document.body

    project.on 'path-changed', => @updateTitle()
    @on 'pane:became-active', => @updateTitle()
    @on 'pane:active-item-changed', '.active.pane', => @updateTitle()
    @on 'pane:removed', => @updateTitle() unless @getActivePane()
    @on 'pane:active-item-title-changed', '.active.pane', => @updateTitle()

    @command 'window:increase-font-size', =>
      config.set("editor.fontSize", config.get("editor.fontSize") + 1)

    @command 'window:decrease-font-size', =>
      fontSize = config.get "editor.fontSize"
      config.set("editor.fontSize", fontSize - 1) if fontSize > 1

    @command 'window:focus-next-pane', => @focusNextPane()
    @command 'window:focus-previous-pane', => @focusPreviousPane()
    @command 'window:save-all', => @saveAll()
    @command 'window:toggle-invisibles', =>
      config.set("editor.showInvisibles", !config.get("editor.showInvisibles"))
    @command 'window:toggle-ignored-files', =>
      config.set("core.hideGitIgnoredFiles", not config.core.hideGitIgnoredFiles)

    @command 'window:toggle-auto-indent', =>
      config.set("editor.autoIndent", !config.get("editor.autoIndent"))

    @command 'pane:reopen-closed-item', =>
      @panes.reopenItem()

    @command 'new-editor', =>
      @open()

    _.nextTick => atom.setFullScreen(@state.get('fullScreen'))

  serialize: ->
    @panes.serialize()
    @state.set('fullScreen', atom.isFullScreen())
    @state

  handleFocus: (e) ->
    if @getActivePane()
      @getActivePane().focus()
      false
    else
      @updateTitle()
      focusableChild = this.find("[tabindex=-1]:visible:first")
      if focusableChild.length
        focusableChild.focus()
        false
      else
        true

  afterAttach: (onDom) ->
    @focus() if onDom

  ### Public ###

  # Shows a dialog asking if the pane was _really_ meant to be closed.
  confirmClose: ->
    @panes.confirmClose()

  # Given a filepath, this opens it in Atom.
  #
  # Returns the `EditSession` for the file URI.
  open: (path, options = {}) ->
    changeFocus = options.changeFocus ? true
    path = project.resolve(path) if path?
    if activePane = @getActivePane()
      editSession = activePane.itemForUri(path) ? project.open(path)
      activePane.showItem(editSession)
    else
      editSession = project.open(path)
      activePane = new Pane(editSession)
      @panes.setRoot(activePane)

    activePane.focus() if changeFocus
    editSession

  # Updates the application's title, based on whichever file is open.
  updateTitle: ->
    if projectPath = project.getPath()
      if item = @getActivePaneItem()
        @setTitle("#{item.getTitle?() ? 'untitled'} - #{projectPath}")
      else
        @setTitle("atom - #{projectPath}")
    else
      @setTitle('untitled')

  # Sets the application's title.
  #
  # Returns a {String}.
  setTitle: (title) ->
    document.title = title

  # Retrieves all of the application's {Editor}s.
  #
  # Returns an {Array} of {Editor}s.
  getEditors: ->
    @panes.find('.pane > .item-views > .editor').map(-> $(this).view()).toArray()

  # Retrieves all of the modified buffers that are open and unsaved.
  #
  # Returns an {Array} of {Buffer}s.
  getModifiedBuffers: ->
    modifiedBuffers = []
    for pane in @getPanes()
      for item in pane.getItems() when item instanceof EditSession
        modifiedBuffers.push item.buffer if item.buffer.isModified()
    modifiedBuffers

  # Retrieves all of the paths to open files.
  #
  # Returns an {Array} of {String}s.
  getOpenBufferPaths: ->
    _.uniq(_.flatten(@getEditors().map (editor) -> editor.getOpenBufferPaths()))

  # Retrieves the pane that's currently open.
  #
  # Returns an {Pane}.
  getActivePane: ->
    @panes.getActivePane()

  getActivePaneItem: ->
    @panes.getActivePaneItem()

  getActiveView: ->
    @panes.getActiveView()

  focusPreviousPane: -> @panes.focusPreviousPane()
  focusNextPane: -> @panes.focusNextPane()
  getFocusedPane: -> @panes.getFocusedPane()

  # Saves all of the open buffers.
  saveAll: ->
    @panes.saveAll()

  # Fires a callback on each open {Pane}.
  #
  # callback - A {Function} to call
  eachPane: (callback) ->
    @panes.eachPane(callback)

  # Retrieves all of the open {Pane}s.
  #
  # Returns an {Array} of {Pane}.
  getPanes: ->
    @panes.getPanes()

  # Given a {Pane}, this fetches its ID.
  #
  # pane - An open {Pane}
  #
  # Returns a {Number}.
  indexOfPane: (pane) ->
    @panes.indexOfPane(pane)

  # Fires a callback on each open {Editor}.
  #
  # callback - A {Function} to call
  eachEditor: (callback) ->
    callback(editor) for editor in @getEditors()
    attachedCallback = (e, editor) -> callback(editor)
    @on('editor:attached', attachedCallback)
    off: => @off('editor:attached', attachedCallback)

  # Fires a callback on each open {EditSession}.
  #
  # callback - A {Function} to call
  eachEditSession: (callback) ->
    project.eachEditSession(callback)

  # Fires a callback on each open {Buffer}.
  #
  # callback - A {Function} to call
  eachBuffer: (callback) ->
    project.eachBuffer(callback)

  ### Internal ###

  # Destroys everything.
  remove: ->
    editor.remove() for editor in @getEditors()
    project.destroy()
    super
