$ = require 'jquery'
fs = require 'fs'
_ = require 'underscore'

Template = require 'template'
Buffer = require 'buffer'
Editor = require 'editor'
FileFinder = require 'file-finder'
Project = require 'project'
GlobalKeymap = require 'global-keymap'

module.exports =
class RootView extends Template
  content: ->
    @div id: 'app-horizontal', =>
      @link rel: 'stylesheet', href: "#{require.resolve('atom.css')}?#{(new Date).getTime()}"
      @div id: 'app-vertical', outlet: 'vertical', =>
        @div id: 'main', outlet: 'main', =>
          @subview 'editor', Editor.build()

  viewProperties:
    globalKeymap: null

    initialize: ({url}) ->
      @editor.keyEventHandler = atom.globalKeymap
      @createProject(url)

      atom.bindKeys '*'
        'meta-s': 'save'
        'meta-w': 'close'
        'meta-t': 'toggle-file-finder'

      @on 'toggle-file-finder', => @toggleFileFinder()

    createProject: (url) ->
      if url
        @project = new Project(fs.directory(url))
        @editor.setBuffer(@project.open(url)) if fs.isFile(url)

    bindKeys: (selector, bindings) ->
      @globalKeymap.bindKeys(selector, bindings)

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
          @fileFinder = FileFinder.build
            urls: relativePaths
            selected: (relativePath) => @editor.setBuffer(@project.open(relativePath))
          @addPane @fileFinder
          @fileFinder.input.focus()
