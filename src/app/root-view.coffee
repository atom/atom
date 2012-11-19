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
StatusBar = require 'status-bar'
TextMateTheme = require 'text-mate-theme'

module.exports =
class RootView extends View
  @content: ->
    @div id: 'root-view', tabindex: -1, =>
      @div id: 'horizontal', outlet: 'horizontal', =>
        @div id: 'vertical', outlet: 'vertical', =>
          @div id: 'panes', outlet: 'panes'

  @deserialize: ({ projectPath, panesViewState, extensionStates, fontSize }) ->
    rootView = new RootView(projectPath, extensionStates: extensionStates, suppressOpen: true)
    rootView.setRootPane(rootView.deserializeView(panesViewState)) if panesViewState
    rootView.setFontSize(fontSize) if fontSize > 0
    rootView

  extensions: null
  extensionStates: null
  fontSize: 20
  showInvisibles: false
  invisibles: null
  title: null

  initialize: (pathToOpen, { @extensionStates, suppressOpen } = {}) ->
    window.rootView = this
    TextMateTheme.activate('IR_Black')

    @invisibles =
      eol: '¬'
      space: '•'
      tab: '▸'

    @extensionStates ?= {}
    @extensions = {}
    @project = new Project(pathToOpen)
    @handleEvents()
    @loadUserConfiguration()

    if pathToOpen
      @open(pathToOpen) if fs.isFile(pathToOpen) and not suppressOpen
    else
      @open()

  serialize: ->
    projectPath: @project?.getPath()
    panesViewState: @panes.children().view()?.serialize()
    extensionStates: @serializeExtensions()
    fontSize: @getFontSize()

  handleEvents: ->
    @on 'toggle-dev-tools', => atom.toggleDevTools()
    @on 'focus', (e) =>
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

    @on 'active-editor-path-change', (e, path) =>
      @project.setPath(path) unless @project.getRootDirectory()
      if path
        @setTitle(fs.base(path))
      else
        @setTitle("untitled")

    @command 'window:increase-font-size', => @setFontSize(@getFontSize() + 1)
    @command 'window:decrease-font-size', => @setFontSize(@getFontSize() - 1)
    @command 'window:focus-next-pane', => @focusNextPane()
    @command 'window:save-all', => @saveAll()
    @command 'window:toggle-invisibles', => @setShowInvisibles(not @showInvisibles)

  afterAttach: (onDom) ->
    @focus() if onDom

  serializeExtensions:  ->
    extensionStates = {}
    for name, extension of @extensions
      try
        extensionStates[name] = extension.serialize?()
      catch e
        console?.error("Exception serializing '#{name}' extension\n", e.stack)
    extensionStates

  deserializeView: (viewState) ->
    switch viewState.viewClass
      when 'Pane' then Pane.deserialize(viewState, this)
      when 'PaneRow' then PaneRow.deserialize(viewState, this)
      when 'PaneColumn' then PaneColumn.deserialize(viewState, this)
      when 'Editor' then Editor.deserialize(viewState, this)

  activateExtension: (extension, config) ->
    throw new Error("Trying to activate an extension with no name attribute") unless extension.name?
    @extensions[extension.name] = extension
    extension.activate(this, @extensionStates[extension.name], config)

  deactivateExtension: (extension) ->
    extension.deactivate?()
    delete @extensions[extension.name]

  deactivate: ->
    atom.setRootViewStateForPath(@project.getPath(), @serialize())
    @deactivateExtension(extension) for name, extension of @extensions
    @remove()

  open: (path, options = {}) ->
    changeFocus = options.changeFocus ? true
    allowActiveEditorChange = options.allowActiveEditorChange ? false

    unless editSession = @openInExistingEditor(path, allowActiveEditorChange, changeFocus)
      editSession = @project.buildEditSessionForPath(path)
      editor = new Editor({editSession, @showInvisibles})
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

      path = @project.resolve(path) if path

      if editSession = activeEditor.activateEditSessionForPath(path)
        return editSession

      if allowActiveEditorChange
        for editor in @getEditors()
          if editSession = editor.activateEditSessionForPath(path)
            @makeEditorActive(editor, changeFocus)
            return editSession

      editSession = @project.buildEditSessionForPath(path)
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
      editor.on 'editor-path-change.root-view', =>
        @trigger 'active-editor-path-change', editor.getPath()
      if not previousActiveEditor or editor.getPath() != previousActiveEditor.getPath()
        @trigger 'active-editor-path-change', editor.getPath()

  activeKeybindings: ->
    keymap.bindingsForElement(document.activeElement)

  getTitle: ->
    @title or "untitled"

  setTitle: (title) ->
    projectPath = @project.getPath()
    if not projectPath
      @title = "untitled"
    else if title
      @title = "#{title} – #{projectPath}"
    else
      @title = projectPath

    @updateWindowTitle()

  updateWindowTitle: ->
    document.title = @title

  setShowInvisibles: (showInvisibles) ->
    return if @showInvisibles == showInvisibles
    @showInvisibles = showInvisibles
    editor.setShowInvisibles(@showInvisibles) for editor in @getEditors()

  toggleIgnoredFiles: ->
    @project.toggleIgnoredFiles()

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
    @project.destroy()
    super

  setFontSize: (newFontSize) ->
    newFontSize = Math.max(1, newFontSize)
    [oldFontSize, @fontSize] = [@fontSize, newFontSize]
    @trigger 'font-size-change' if oldFontSize != newFontSize

  getFontSize: -> @fontSize

  setInvisibles: (invisibles={}) ->
    _.extend(@invisibles, invisibles)
    editor.setInvisibles(@invisibles) for editor in @getEditors()

  getInvisibles: -> @invisibles

  loadUserConfiguration: ->
    try
      require atom.configFilePath if fs.exists(atom.configFilePath)
    catch error
      console.error "Failed to load `#{atom.configFilePath}`", error.stack, error

  saveAll: ->
    editor.save() for editor in @getEditors()
