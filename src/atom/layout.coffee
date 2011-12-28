$ = require 'jquery'
Template = require 'template'

module.exports =
class Layout extends Template
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
    addPane: (view) ->
      pane = $('<div class="pane">')
      pane.append(view)
      @main.after(pane)
