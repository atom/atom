$ = require 'jquery'
Template = require 'template'

module.exports =
class Layout extends Template
  @attach: ->
    view = @build()
    $('body').append(view)
    view

  content: ->
    @link rel: 'stylesheet', href: 'static/atom.css'
    @div id: 'app-horizontal', =>
      @div id: 'app-vertical', =>
        @div id: 'main'

