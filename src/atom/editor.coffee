Buffer = require 'buffer'
ace = require 'ace/ace'
$ = require 'jquery'

module.exports =
class Editor
  aceEditor: null
  buffer: null

  constructor: (url) ->
    @buffer = new Buffer(url)
    @buildAceEditor()
    @setText @buffer.text

  setText: (text) ->
    @aceEditor.getSession().setValue @buffer.text

  buildAceEditor: ->
    $('#main').append("<div id='editor'>")
    @aceEditor = ace.edit 'editor'

  destroy: ->
    @aceEditor.destroy()

