Template = require 'template'
Buffer = require 'buffer'
{EditSession} = require 'ace/edit_session'
ace = require 'ace/ace'
$ = require 'jquery'

module.exports =
class Editor extends Template
  content: ->
    @div class: 'editor'

  viewProperties:
    aceEditor: null
    buffer: null
    editorElement: null

    initialize: ({url}) ->
      @buildAceEditor()
      @open(url)

    shutdown: ->
      @destroy()

    destroy: ->
      @aceEditor.destroy()

    open: (url) ->
      $atomController.url = url
      @buffer = new Buffer(url)
      session = new EditSession(@buffer.aceDocument, @buffer.getMode())
      @aceEditor.setSession(session)

    buildAceEditor: ->
      @aceEditor = ace.edit this[0]
      @aceEditor.setTheme(require "ace/theme/twilight")

    getAceSession: ->
      @aceEditor.getSession()

    save: ->
      if @buffer.url
        @buffer.save()
      else if url = atom.native.savePanel()
        @buffer.url = url
        @buffer.save()

