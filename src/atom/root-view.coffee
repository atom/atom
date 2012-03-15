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

  initialize: ({url}) ->
    @editor.keyEventHandler = window.keymap
    @createProject(url)

    window.keymap.bindKeys '*'
      'meta-s': 'save'
      'meta-w': 'close'
      'meta-t': 'toggle-file-finder'
      'alt-meta-i': 'show-console'

    @on 'toggle-file-finder', => @toggleFileFinder()
    @on 'show-console', -> window.showConsole()

    @on 'focusout', (e) =>
      # if anything but the main editor's hidden input loses focus, restore focus to the main editor
      unless @editor.containsElement($(e.target))
        @editor.focus()

  createProject: (url) ->
    if url
      @project = new Project(fs.directory(url))
      @editor.setBuffer(@project.open(url)) if fs.isFile(url)

  addPane: (view) ->
    @append(view)

  toggleFileFinder: ->
    return unless @project

    if @fileFinder and @fileFinder.parent()[0]
      @fileFinder.remove()
      @fileFinder = null
    else
      @project.getFilePaths().done (paths) =>
        relativePaths = (path.replace(@project.url, "") for path in paths)
        @fileFinder = new FileFinder
          urls: relativePaths
          selected: (relativePath) => @editor.setBuffer(@project.open(relativePath))
        @addPane @fileFinder
