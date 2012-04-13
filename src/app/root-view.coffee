$ = require 'jquery'
{$$} = require 'space-pen'
fs = require 'fs'
_ = require 'underscore'

{View} = require 'space-pen'
Buffer = require 'buffer'
Editor = require 'editor'
FileFinder = require 'file-finder'
Project = require 'project'
VimMode = require 'vim-mode'
CommandPanel = require 'command-panel'
Pane = require 'pane'
PaneColumn = require 'pane-column'
PaneRow = require 'pane-row'

module.exports =
class RootView extends View
  @content: ->
    @div id: 'root-view', tabindex: -1, =>
      @div id: 'panes', outlet: 'panes'

  @deserialize: (viewState) ->
    new RootView(viewState)

  initialize: ({ pathToOpen, projectPath, panesViewState }) ->
    @on 'toggle-file-finder', => @toggleFileFinder()
    @on 'show-console', => window.showConsole()
    @one 'attach', => @focus()
    @on 'focus', (e) =>
      if @editors().length
        @activeEditor().focus()
        false
      else
        @setTitle(@project?.path)

    @commandPanel = new CommandPanel({rootView: this})

    if projectPath?
      @project = new Project(projectPath)
    else if pathToOpen?
      @project = new Project(fs.directory(pathToOpen))
      @open(pathToOpen) if fs.isFile(pathToOpen)
    else if not panesViewState?
      @activeEditor().setBuffer(new Buffer)

    @deserializePanes(panesViewState) if panesViewState

  serialize: ->
    projectPath: @project?.path
    panesViewState: @serializePanes()

  serializePanes: () ->
    @panes.children().view().serialize()

  deserializePanes: (panesViewState) ->
    @panes.append @deserializeView(panesViewState)
    @adjustPaneDimensions()

  deserializeView: (viewState) ->
    switch viewState.viewClass
      when 'Pane' then Pane.deserialize(viewState, this)
      when 'PaneRow' then PaneRow.deserialize(viewState, this)
      when 'PaneColumn' then PaneColumn.deserialize(viewState, this)
      when 'Editor' then Editor.deserialize(viewState)

  open: (path) ->
    @activeEditor().setBuffer(@project.open(path))

  editorFocused: (editor) ->
    if @panes.containsElement(editor)
      @panes.find('.editor')
        .removeClass('active')
        .off('.root-view')

      editor
        .addClass('active')
        .on('buffer-path-change.root-view', => @setTitle(editor.buffer.path))

      @setTitle(editor.buffer.path)

  setTitle: (title='untitled') ->
    document.title = title

  editors: ->
    @panes.find('.editor').map -> $(this).view()

  activeEditor: ->
    editor = @panes.find('.editor.active')
    if editor.length
      editor.view()
    else
      editor = @panes.find('.editor:first')
      if editor.length
        editor.view()
      else
        editor = new Editor
        pane = new Pane(editor)
        @panes.append(pane)
        editor.focus()
        editor

  adjustPaneDimensions: ->
    rootPane = @panes.children().first().view()
    rootPane?.css(width: '100%', height: '100%')
    rootPane?.adjustDimensions()

  toggleFileFinder: ->
    return unless @project

    if @fileFinder and @fileFinder.parent()[0]
      @fileFinder.remove()
      @fileFinder = null
    else
      @project.getFilePaths().done (paths) =>
        relativePaths = (path.replace(@project.path, "") for path in paths)
        @fileFinder = new FileFinder
          paths: relativePaths
          selected: (relativePath) => @open(relativePath)
        @append @fileFinder
        @fileFinder.editor.focus()
