Buffer = require 'buffer'
{EditSession} = require 'ace/edit_session'
ace = require 'ace/ace'
$ = require 'jquery'

module.exports =
class Editor
  aceEditor: null
  buffer: null
  editorElement: null

  constructor: (url) ->
    @buffer = new Buffer(url)
    @buildAceEditor()
    $(document).keydown (event) =>
      if String.fromCharCode(event.which) == 'S' and event.metaKey
        @save()


  destroy: ->
    @aceEditor.destroy()

  buildAceEditor: ->
    @editorElement = $("<div class='editor'>")
    $('#main').append(@editorElement)
    @aceEditor = ace.edit @editorElement[0]
    @aceEditor.setSession(new EditSession(@buffer.aceDocument))
    @aceEditor.setTheme(require "ace/theme/twilight")

  getAceSession: ->
    @aceEditor.getSession()


  save: ->
    @buffer.save()

