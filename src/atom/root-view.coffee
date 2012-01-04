$ = require 'jquery'
fs = require 'fs'

Template = require 'template'
Editor = require 'editor'
FileFinder = require 'file-finder'
Project = require 'project'

module.exports =
class RootView extends Template
  content: ->
    @link rel: 'stylesheet', href: "#{require.resolve('atom.css')}?#{(new Date).getTime()}"
    @div id: 'app-horizontal', =>
      @div id: 'app-vertical', outlet: 'vertical', =>
        @div id: 'main', outlet: 'main', =>
          @subview 'editor', Editor.build()

  viewProperties:
    initialize: ({url}) ->
      @bindKey 'meta+s', => @editor.save()
      @bindKey 'meta+w', => window.close()
      @bindKey 'meta+t', => @toggleFileFinder()

      if not url
        # not sure what to do
      else if fs.isDirectory url
        @project = new Project url
        @editor.open()
      else
        @project = new Project(fs.directory(url))
        @editor.open url

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
        @project.getFilePaths().done (urls) =>
          @fileFinder = FileFinder.build({urls, selected: (url) => @editor.open(url)})
          @addPane(@fileFinder)
          @fileFinder.input.focus()
