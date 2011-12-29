$ = require 'jquery'
fs = require 'fs'

Editor = require 'editor'
FileFinder = require 'file-finder'
Template = require 'template'

module.exports =
class RootView extends Template
  @attach: ->
    view = @build()
    $('body').append view
    view

  content: ->
    @link rel: 'stylesheet', href: "#{require.resolve('atom.css')}?#{(new Date).getTime()}"
    @div id: 'app-horizontal', =>
      @div id: 'app-vertical', outlet: 'vertical', =>
        @div id: 'main', outlet: 'main', =>
          @subview 'editor', Editor.build()

  viewProperties:
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
        urls = fs.list directory
        @fileFinder = FileFinder.build({urls})
        @addPane(@fileFinder)
        @fileFinder.input.focus()
