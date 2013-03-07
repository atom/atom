$ = require 'jquery'
{$$} = require 'space-pen'
fs = require 'fs'
_ = require 'underscore'

{View} = require 'space-pen'
Buffer = require 'buffer'
Editor = require 'editor'
Project = require 'project'
Pane = require 'pane'
PaneColumn = require 'pane-column'
PaneRow = require 'pane-row'

module.exports =
class RootView extends View
  registerDeserializers(this, Pane, PaneRow, PaneColumn, Editor)

  @configDefaults:
    ignoredNames: [".git", ".svn", ".DS_Store"]
    disabledPackages: []

  @content: ->
    @div id: 'root-view', =>
      @div id: 'horizontal', outlet: 'horizontal', =>
        @div id: 'vertical', outlet: 'vertical', =>
          @div id: 'panes', outlet: 'panes'

  @deserialize: ({ panesViewState, packageStates, projectPath }) ->
    atom.atomPackageStates = packageStates ? {}
    rootView = new RootView
    rootView.setRootPane(deserialize(panesViewState)) if panesViewState
    rootView

  title: null

  initialize: ->
    @command 'toggle-dev-tools', => atom.toggleDevTools()
    @on 'focus', (e) => @handleFocus(e)
    @subscribe $(window), 'focus', (e) =>
      @handleFocus(e) if document.activeElement is document.body

    @on 'root-view:active-path-changed', (e, path) =>
      if path
        project.setPath(path) unless project.getRootDirectory()
        @setTitle(fs.base(path))
      else
        @setTitle("untitled")

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
    @command 'window:toggle-auto-indent-on-paste', =>
      config.set("editor.autoIndentOnPaste", !config.get("editor.autoIndentOnPaste"))

  serialize: ->
    deserializer: 'RootView'
    panesViewState: @panes.children().view()?.serialize()
    packageStates: atom.serializeAtomPackages()

  handleFocus: (e) ->
    if @getActiveEditor()
      @getActiveEditor().focus()
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

  deactivate: ->
    atom.deactivateAtomPackages()
    @remove()

  open: (path, options = {}) ->
    changeFocus = options.changeFocus ? true
    allowActiveEditorChange = options.allowActiveEditorChange ? false

    unless editSession = @openInExistingEditor(path, allowActiveEditorChange, changeFocus)
      editSession = project.buildEditSessionForPath(path)
      editor = new Editor({editSession})
      pane = new Pane(editor)
      @panes.append(pane)
      if changeFocus
        editor.focus()
      else
        @makeEditorActive(editor, changeFocus)

    editSession

  openInExistingEditor: (path, allowActiveEditorChange, changeFocus) ->
    if activeEditor = @getActiveEditor()
      activeEditor.focus() if changeFocus

      path = project.resolve(path) if path

      if editSession = activeEditor.activateEditSessionForPath(path)
        return editSession

      if allowActiveEditorChange
        for editor in @getEditors()
          if editSession = editor.activateEditSessionForPath(path)
            @makeEditorActive(editor, changeFocus)
            return editSession

      editSession = project.buildEditSessionForPath(path)
      activeEditor.edit(editSession)
      editSession

  editorFocused: (editor) ->
    @makeEditorActive(editor) if @panes.containsElement(editor)

  makeEditorActive: (editor, focus) ->
    if focus
      editor.focus()
      return

    previousActiveEditor = @panes.find('.editor.active').view()
    previousActiveEditor?.removeClass('active').off('.root-view')
    editor.addClass('active')

    if not editor.mini
      editor.on 'editor:path-changed.root-view', =>
        @trigger 'root-view:active-path-changed', editor.getPath()
      if not previousActiveEditor or editor.getPath() != previousActiveEditor.getPath()
        @trigger 'root-view:active-path-changed', editor.getPath()

  activeKeybindings: ->
    keymap.bindingsForElement(document.activeElement)

  getTitle: ->
    @title or "untitled"

  setTitle: (title) ->
    projectPath = project.getPath()
    if not projectPath
      @title = "untitled"
    else if title
      @title = "#{title} – #{projectPath}"
    else
      @title = projectPath

    @updateWindowTitle()

  updateWindowTitle: ->
    document.title = @title

  getEditors: ->
    @panes.find('.pane > .editor').map(-> $(this).view()).toArray()

  getModifiedBuffers: ->
    modifiedBuffers = []
    for editor in @getEditors()
      for session in editor.editSessions
        modifiedBuffers.push session.buffer if session.buffer.isModified()

    modifiedBuffers

  getOpenBufferPaths: ->
    _.uniq(_.flatten(@getEditors().map (editor) -> editor.getOpenBufferPaths()))

  getActiveEditor: ->
    if (editor = @panes.find('.editor.active')).length
      editor.view()
    else
      @panes.find('.editor:first').view()

  getActiveEditSession: ->
    @getActiveEditor()?.activeEditSession

  focusNextPane: ->
    panes = @panes.find('.pane')
    currentIndex = panes.toArray().indexOf(@getFocusedPane()[0])
    nextIndex = (currentIndex + 1) % panes.length
    panes.eq(nextIndex).view().wrappedView.focus()

  focusPreviousPane: ->
    panes = @panes.find('.pane')
    currentIndex = panes.toArray().indexOf(@getFocusedPane()[0])
    previousIndex = (currentIndex - 1) % panes.length
    panes.eq(previousIndex).view().wrappedView.focus()

  getFocusedPane: ->
    @panes.find('.pane:has(:focus)')

  setRootPane: (pane) ->
    @panes.empty()
    @panes.append(pane)
    @adjustPaneDimensions()

  adjustPaneDimensions: ->
    rootPane = @panes.children().first().view()
    rootPane?.css(width: '100%', height: '100%', top: 0, left: 0)
    rootPane?.adjustDimensions()

  remove: ->
    editor.remove() for editor in @getEditors()
    project.destroy()
    super

  saveAll: ->
    editor.save() for editor in @getEditors()

  eachEditor: (callback) ->
    callback(editor) for editor in @getEditors()
    @on 'editor:attached', (e, editor) -> callback(editor)

  eachEditSession: (callback) ->
    project.eachEditSession(callback)

  eachBuffer: (callback) ->
    project.eachBuffer(callback)

  indexOfPane: (pane) ->
    index = -1
    for p, idx in @panes.find('.pane')
      if pane.is(p)
        index = idx
        break
    index
