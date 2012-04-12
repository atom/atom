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

  initialize: ({ pathToOpen, projectPath, panesViewState }) ->
    @on 'toggle-file-finder', => @toggleFileFinder()
    @on 'show-console', => window.showConsole()
    @one 'attach', => @focus()
    @on 'focus', (e) =>
      if @editors().length
        @activeEditor().focus()
        false

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
    @adjustSplitPanes()

  deserializeView: (viewState) ->
    switch viewState.viewClass
      when 'Pane' then Pane.deserialize(viewState, this)
      when 'PaneRow' then PaneRow.deserialize(viewState, this)
      when 'PaneColumn' then PaneColumn.deserialize(viewState, this)
      when 'Editor' then new Editor(viewState)

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

  editorRemoved: (editor) ->
    @adjustSplitPanes()
    if @editors().length
      @editors()[0].focus()
    else
      @focus()

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

  addPane: (view, sibling, axis, side) ->
    unless sibling.parent().hasClass(axis)
      container = if axis == 'column' then new PaneColumn else new PaneRow
      container.insertBefore(sibling).append(sibling.detach())
    pane = new Pane(view)
    sibling[side](pane)
    @adjustSplitPanes()
    view

  adjustSplitPanes: (element = @panes.children(':first'))->
    if element.hasClass('row')
      totalUnits = @horizontalGridUnits(element)
      unitsSoFar = 0
      for child in element.children()
        child = $(child)
        childUnits = @horizontalGridUnits(child)
        child.css
          width: "#{childUnits / totalUnits * 100}%"
          height: '100%'
          top: 0
          left: "#{unitsSoFar / totalUnits * 100}%"
        @adjustSplitPanes(child)
        unitsSoFar += childUnits

    else if element.hasClass('column')
      totalUnits = @verticalGridUnits(element)
      unitsSoFar = 0
      for child in element.children()
        child = $(child)
        childUnits = @verticalGridUnits(child)
        child.css
          width: '100%'
          height: "#{childUnits / totalUnits * 100}%"
          top: "#{unitsSoFar / totalUnits * 100}%"
          left: 0
        @adjustSplitPanes(child)
        unitsSoFar += childUnits

  horizontalGridUnits: (element) ->
    if element.is('.row, .column')
      childUnits = (@horizontalGridUnits($(child)) for child in element.children())
      if element.hasClass('row')
        _.sum(childUnits)
      else # it's a column
        Math.max(childUnits...)
    else
      1

  verticalGridUnits: (element) ->
    if element.is('.row, .column')
      childUnits = (@verticalGridUnits($(child)) for child in element.children())
      if element.hasClass('column')
        _.sum(childUnits)
      else # it's a row
        Math.max(childUnits...)
    else
      1

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
