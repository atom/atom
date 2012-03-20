$ = require 'jquery'
fs = require 'fs'
_ = require 'underscore'

{View} = require 'space-pen'
Buffer = require 'buffer'
Editor = require 'editor'
FileFinder = require 'file-finder'
Project = require 'project'
VimMode = require 'vim-mode'

module.exports =
class RootView extends View
  @content: ->
    @div id: 'root-view', =>
      @subview 'editor', new Editor

  editors: null

  initialize: ({url}) ->
    @editors = []
    @editor.keyEventHandler = window.keymap
    @createProject(url)

    window.keymap.bindKeys '*'
      'meta-s': 'save'
      'meta-w': 'close'
      'meta-t': 'toggle-file-finder'
      'alt-meta-i': 'show-console'

    @on 'toggle-file-finder', => @toggleFileFinder()
    @on 'show-console', -> window.showConsole()

  createProject: (url) ->
    if url
      @project = new Project(fs.directory(url))
      @editor.setBuffer(@project.open(url)) if fs.isFile(url)

  addPane: (view) ->
    @append(view)

  editorFocused: (editor) ->
    _.remove(@editors, editor)
    @editors.push(editor)

  editorRemoved: (editor) ->
    _.remove(@editors, editor)
    @adjustSplitPanes()
    if @editors.length
      @focusLastActiveEditor()
    else
      window.close()

  focusLastActiveEditor: ->
    _.last(@editors).focus()

  adjustSplitPanes: (element = @children(':first'))->
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
      @editor.focus()
    else
      @project.getFilePaths().done (paths) =>
        relativePaths = (path.replace(@project.url, "") for path in paths)
        @fileFinder = new FileFinder
          urls: relativePaths
          selected: (relativePath) => @editor.setBuffer(@project.open(relativePath))
        @addPane @fileFinder
