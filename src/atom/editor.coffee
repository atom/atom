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
    @buildAceEditor()
    @open(url)

  destroy: ->
    @aceEditor.destroy()

  open: (url) ->
    @buffer = new Buffer(url)
    @aceEditor.setSession(new EditSession(@buffer.aceDocument))

  buildAceEditor: ->
    @editorElement = $("<div class='editor'>").appendTo('#main')
    @aceEditor = ace.edit @editorElement[0]
    @aceEditor.setTheme(require "ace/theme/twilight")

  getAceSession: ->
    @aceEditor.getSession()

  save: ->
    if @buffer.url
      @buffer.save()
    else if url = atom.native.savePanel()
      @buffer.url = url
      @buffer.save()

