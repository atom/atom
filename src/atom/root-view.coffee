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
    @div id: 'app-horizontal', =>
      @div id: 'app-vertical', outlet: 'vertical', =>
        @div id: 'main', outlet: 'main', =>
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
      # if anything but the editor and its input loses focus, restore focus to the editor
      unless $(e.target).closest('.editor').length
        @editor.focus()

  createProject: (url) ->
    if url
      @project = new Project(fs.directory(url))
      @editor.setBuffer(@project.open(url)) if fs.isFile(url)

  addPane: (view) ->
    pane = $('<div class="pane">')
    pane.append(view)
    @main.after(pane)

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
        @fileFinder.input.focus()
