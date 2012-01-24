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
    keyEventHandler: null

    initialize: () ->
      @aceSessions = {}
      @buildAceEditor()
      @setBuffer(new Buffer)
      @on 'save', => @save()

    shutdown: ->
      @destroy()

    destroy: ->
      @aceEditor.destroy()

    setBuffer: (@buffer) ->
      @aceEditor.setSession @getAceSessionForBuffer(buffer)

    getAceSessionForBuffer: (buffer) ->
      @aceSessions[@buffer.url] ?= new EditSession(@buffer.aceDocument, @buffer.getMode())

    buildAceEditor: ->
      @aceEditor = ace.edit this[0]
      @aceEditor.setTheme(require "ace/theme/twilight")
      @aceEditor.setKeyboardHandler
        handleKeyboard: (data, hashId, keyString, keyCode, event) =>
          if event and @keyEventHandler and @keyEventHandler.handleKeyEvent(event) == false
            { command: { exec: -> }}
          else
            null

    getAceSession: ->
      @aceEditor.getSession()

    focus: ->
      @aceEditor.focus()

    save: ->
      if @buffer.url
        @buffer.save()
      else if url = atom.native.savePanel()
        @buffer.url = url
        @buffer.save()

    getPosition: ->
      @getAceSession().getSelection().getCursor()

    setPosition: ({column, row}) ->
      @aceEditor.navigateTo(row, column)

    selectToPosition: (position) ->
      if @aceEditor.selection.isEmpty()
        { row, column } = @getPosition()
        @aceEditor.selection.setSelectionAnchor(row, column)
      @aceEditor.moveCursorToPosition(position)

    delete: ->
      @getAceSession().remove(@aceEditor.getSelectionRange())

    getLineText: (row) ->
      @buffer.getLine(row)

    getRow: ->
      { row } = @getPosition()
      row

    deleteChar: ->
      @aceEditor.remove 'right'

    selectLine: ->
      @aceEditor.selection.selectLine()

    deleteLine: ->
      @aceEditor.removeLines()

    moveLeft: ->
      @aceEditor.navigateLeft()

    moveRight: ->
      @aceEditor.navigateRight()

    moveUp: ->
      @aceEditor.navigateUp()

    moveDown: ->
      @aceEditor.navigateDown()
