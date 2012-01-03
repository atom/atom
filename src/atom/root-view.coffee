$ = require 'jquery'
fs = require 'fs'

Editor = require 'editor'
FileFinder = require 'file-finder'
Template = require 'template'

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

      @editor.open url

    addPane: (view) ->
      pane = $('<div class="pane">')
      pane.append(view)
      @main.after(pane)

    toggleFileFinder: ->
      return unless @editor.buffer.url

      if @fileFinder
        @fileFinder.remove()
        @fileFinder = null
      else
        directory = fs.directory @editor.buffer.url
        urls = (url for url in fs.list(directory, true) when fs.isFile url)
        urls = (url.replace(directory, "") for url in urls)
        @fileFinder = FileFinder.build({urls})
        @addPane(@fileFinder)
        @fileFinder.input.focus()
