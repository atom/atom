$ = require 'jquery'

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
        @div id: 'main', outlet: 'main'

  viewProperties:
    initialize: ->
      @editor = new Editor $atomController.url?.toString()

    addPane: (view) ->
      pane = $('<div class="pane">')
      pane.append(view)
      @main.after(pane)

    toggleFileFinder: ->
      if @fileFinder
        @fileFinder.remove()
        @fileFinder = null
      else
        @fileFinder = FileFinder.build(urls: [@editor.buffer.url])
        @addPane(@fileFinder)
        @fileFinder.input.focus()
