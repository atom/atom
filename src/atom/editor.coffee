Buffer = require 'buffer'
{EditSession} = require 'ace/edit_session'
ace = require 'ace/ace'
$ = require 'jquery'

module.exports =
class Editor
  aceEditor: null
  buffer: null

  constructor: (url) ->
    @buffer = new Buffer(url)
    @buildAceEditor()

  buildAceEditor: ->
    editorElement = $("<div class='editor'>")
    $('#main').append(editorElement)
    @aceEditor = ace.edit editorElement[0]
    @aceEditor.setSession(new EditSession(@buffer.aceDocument))
    @aceEditor.setTheme(require "ace/theme/twilight")
    window.x = this

  getAceSession: ->
    @aceEditor.getSession()

  destroy: ->
    @aceEditor.destroy()

