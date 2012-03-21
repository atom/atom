$ = require 'jquery'
fs = require 'fs'
_ = require 'underscore'

{View} = require 'space-pen'
Buffer = require 'buffer'
Editor = require 'editor'
FileFinder = require 'file-finder'
Project = require 'project'
VimMode = require 'vim-mode'
CommandPanel = require 'command-panel'

module.exports =
class RootView extends View
  @content: ->
    @div id: 'root-view', =>
      @div id: 'panes', outlet: 'panes'

  editors: null

  initialize: ({url}) ->
    @editors = []
    @createProject(url)

    window.keymap.bindKeys '*'
      'meta-s': 'save'
      'meta-w': 'close'
      'meta-t': 'toggle-file-finder'
      'meta-:': 'command-panel:toggle'
      'alt-meta-i': 'show-console'

    @on 'toggle-file-finder', => @toggleFileFinder()
    @on 'show-console', -> window.showConsole()

    @commandPanel = new CommandPanel({rootView: this})

  createProject: (path) ->
    if path
      @project = new Project(fs.directory(path))
      @open(path) if fs.isFile(path)

  open: (path) ->
    @lastActiveEditor().setBuffer(@project.open(path))

  editorFocused: (editor) ->
    if @panes.containsElement(editor)
      _.remove(@editors, editor)
      @editors.push(editor)

  editorRemoved: (editor) ->
    if @panes.containsElement
      _.remove(@editors, editor)
      @adjustSplitPanes()
      if @editors.length
        @lastActiveEditor().focus()
      else
        window.close()

  lastActiveEditor: ->
    if @editors.length
      _.last(@editors)
    else
      new Editor()
        .appendTo(@panes)
        .focus()

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
      @lastActiveEditor().focus()
    else
      @project.getFilePaths().done (paths) =>
        relativePaths = (path.replace(@project.url, "") for path in paths)
        @fileFinder = new FileFinder
          urls: relativePaths
          selected: (relativePath) => @open(relativePath)
        @append @fileFinder
