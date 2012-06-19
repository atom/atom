$ = require 'jquery'
{$$} = require 'space-pen'
fs = require 'fs'
_ = require 'underscore'

{View} = require 'space-pen'
Buffer = require 'buffer'
Editor = require 'editor'
Project = require 'project'
VimMode = require 'vim-mode'
Pane = require 'pane'
PaneColumn = require 'pane-column'
PaneRow = require 'pane-row'
StatusBar = require 'status-bar'

module.exports =
class RootView extends View
  @content: ->
    @div id: 'root-view', tabindex: -1, =>
      @div id: 'horizontal', outlet: 'horizontal', =>
        @div id: 'panes', outlet: 'panes'

  @deserialize: ({ projectPath, panesViewState, extensionStates }) ->
    rootView = new RootView(projectPath)
    rootView.setRootPane(rootView.deserializeView(panesViewState)) if panesViewState
    rootView.extensionStates = extensionStates if extensionStates
    rootView

  extensions: null
  extensionStates: null
  fontSize: 20

  initialize: (pathToOpen) ->
    @extensions = {}
    @extensionStates = {}
    @project = new Project(pathToOpen)

    @handleEvents()
    @setTitle()
    @open(pathToOpen) if fs.isFile(pathToOpen)

  serialize: ->
    projectPath: @project?.getPath()
    panesViewState: @panes.children().view()?.serialize()
    extensionStates: @serializeExtensions()

  handleEvents: ->
    @on 'show-console', => window.showConsole()
    @on 'focus', (e) =>
      if @activeEditor()
        @activeEditor().focus()
        false
      else
        @setTitle(@project?.getPath())

    @on 'active-editor-path-change', (e, path) =>
      @project.setPath(path) unless @project.getRootDirectory()
      @setTitle(path)

    @on 'increase-font-size', => @setFontSize(@getFontSize() + 1)
    @on 'decrease-font-size', => @setFontSize(@getFontSize() - 1)
    @on 'focus-next-pane', => @focusNextPane()

  afterAttach: (onDom) ->
    @focus() if onDom

  serializeExtensions:  ->
    extensionStates = {}
    for name, extension of @extensions
      try
        extensionStates[name] = extension.serialize?()
      catch e
        console?.error("Exception serializing '#{name}' extension", e)
    extensionStates

  deserializeView: (viewState) ->
    switch viewState.viewClass
      when 'Pane' then Pane.deserialize(viewState, this)
      when 'PaneRow' then PaneRow.deserialize(viewState, this)
      when 'PaneColumn' then PaneColumn.deserialize(viewState, this)
      when 'Editor' then Editor.deserialize(viewState, this)

  activateExtension: (extension) ->
    throw new Error("Trying to activate an extension with no name") unless extension.name?
    @extensions[extension.name] = extension
    extension.activate(this, @extensionStates[extension.name])

  deactivate: ->
    atom.rootViewStates[$windowNumber] = JSON.stringify(@serialize())
    extension.deactivate?() for name, extension of @extensions
    @remove()

  open: (path, changeFocus=true) ->
    buffer = @project.open(path)

    if @activeEditor()
      @activeEditor().setBuffer(buffer)
    else
      editor = new Editor({ buffer })
      pane = new Pane(editor)
      @panes.append(pane)
      if changeFocus
        editor.focus()
      else
        @makeEditorActive(editor)

  editorFocused: (editor) ->
    @makeEditorActive(editor) if @panes.containsElement(editor)

  makeEditorActive: (editor) ->
    previousActiveEditor = @panes.find('.editor.active').view()
    previousActiveEditor?.removeClass('active').off('.root-view')
    editor.addClass('active')

    if not editor.mini
      editor.on 'editor-path-change.root-view', =>
        @trigger 'active-editor-path-change', editor.buffer.path
      if not previousActiveEditor or editor.buffer.path != previousActiveEditor.buffer.path
        @trigger 'active-editor-path-change', editor.buffer.path

  activeKeybindings: ->
    keymap.bindingsForElement(document.activeElement)

  setTitle: (title='untitled') ->
    document.title = title

  editors: ->
    @panes.find('.editor').map -> $(this).view()

  modifiedBuffers: ->
    modifiedBuffers = []
    for editor in @editors()
      for session in editor.editSessions
        modifiedBuffers.push session.buffer if session.buffer.isModified()

    modifiedBuffers

  activeEditor: ->
    if (editor = @panes.find('.editor.active')).length
      editor.view()
    else
      @panes.find('.editor:first').view()

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
    editor.remove() for editor in @editors()
    super

  setFontSize: (newFontSize) ->
    newFontSize = Math.max(1, newFontSize)
    [oldFontSize, @fontSize] = [@fontSize, newFontSize]
    @trigger 'font-size-change' if oldFontSize != newFontSize

  getFontSize: -> @fontSize
