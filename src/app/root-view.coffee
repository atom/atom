$ = require 'jquery'
{$$} = require 'space-pen'
fs = require 'fs-utils'
_ = require 'underscore'

{View} = require 'space-pen'
Buffer = require 'text-buffer'
Editor = require 'editor'
Project = require 'project'
Pane = require 'pane'
PaneColumn = require 'pane-column'
PaneRow = require 'pane-row'
PaneContainer = require 'pane-container'
EditSession = require 'edit-session'

module.exports =
class RootView extends View
  registerDeserializers(this, Pane, PaneRow, PaneColumn, Editor)

  @version: 1

  @configDefaults:
    ignoredNames: [".git", ".svn", ".DS_Store"]
    disabledPackages: []

  @content: ({panes}={}) ->
    @div id: 'root-view', =>
      @div id: 'horizontal', outlet: 'horizontal', =>
        @div id: 'vertical', outlet: 'vertical', =>
          @subview 'panes', panes ? new PaneContainer

  @deserialize: ({ panes }) ->
    panes = deserialize(panes) if panes?.deserializer is 'PaneContainer'
    new RootView({panes})

  initialize: ->
    @command 'toggle-dev-tools', => atom.toggleDevTools()
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
    @command 'window:save-all', => @saveAll()
    @command 'window:toggle-invisibles', =>
      config.set("editor.showInvisibles", !config.get("editor.showInvisibles"))
    @command 'window:toggle-ignored-files', =>
      config.set("core.hideGitIgnoredFiles", not config.core.hideGitIgnoredFiles)

    @command 'window:toggle-auto-indent', =>
      config.set("editor.autoIndent", !config.get("editor.autoIndent"))

    @command 'window:toggle-auto-indent-on-paste', =>
      config.set("editor.autoIndentOnPaste", !config.get("editor.autoIndentOnPaste"))

    @command 'pane:reopen-closed-item', =>
      @panes.reopenItem()

  serialize: ->
    version: RootView.version
    deserializer: 'RootView'
    panes: @panes.serialize()

  confirmClose: ->
    @panes.confirmClose()

  handleFocus: (e) ->
    if @getActivePane()
      @getActivePane().focus()
      false
    else
      @setTitle(null)
      focusableChild = this.find("[tabindex=-1]:visible:first")
      if focusableChild.length
        focusableChild.focus()
        false
      else
        true

  afterAttach: (onDom) ->
    @focus() if onDom

  open: (path, options = {}) ->
    changeFocus = options.changeFocus ? true
    path = project.resolve(path) if path?
    if activePane = @getActivePane()
      if editSession = activePane.itemForUri(path)
        activePane.showItem(editSession)
      else
        editSession = project.buildEditSession(path)
        activePane.showItem(editSession)
    else
      editSession = project.buildEditSession(path)
      activePane = new Pane(editSession)
      @panes.append(activePane)

    activePane.focus() if changeFocus
    editSession

  updateTitle: ->
    if projectPath = project.getPath()
      if item = @getActivePaneItem()
        @setTitle("#{item.getTitle?() ? 'untitled'} - #{projectPath}")
      else
        @setTitle(projectPath)
    else
      @setTitle('untitled')

  setTitle: (title) ->
    document.title = title

  getEditors: ->
    @panes.find('.pane > .item-views > .editor').map(-> $(this).view()).toArray()

  getModifiedBuffers: ->
    modifiedBuffers = []
    for pane in @getPanes()
      for item in pane.getItems() when item instanceof EditSession
        modifiedBuffers.push item.buffer if item.buffer.isModified()
    modifiedBuffers

  getOpenBufferPaths: ->
    _.uniq(_.flatten(@getEditors().map (editor) -> editor.getOpenBufferPaths()))

  getActivePane: ->
    @panes.getActivePane()

  getActivePaneItem: ->
    @panes.getActivePaneItem()

  getActiveView: ->
    @panes.getActiveView()

  focusNextPane: -> @panes.focusNextPane()
  getFocusedPane: -> @panes.getFocusedPane()

  remove: ->
    editor.remove() for editor in @getEditors()
    project.destroy()
    super

  saveAll: ->
    @panes.saveAll()

  eachPane: (callback) ->
    @panes.eachPane(callback)

  getPanes: ->
    @panes.getPanes()

  indexOfPane: (pane) ->
    @panes.indexOfPane(pane)

  eachEditor: (callback) ->
    callback(editor) for editor in @getEditors()
    @on 'editor:attached', (e, editor) -> callback(editor)

  eachEditSession: (callback) ->
    project.eachEditSession(callback)

  eachBuffer: (callback) ->
    project.eachBuffer(callback)

