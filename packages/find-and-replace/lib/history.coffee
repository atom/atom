_ = require 'underscore-plus'
{Emitter} = require 'atom'

HISTORY_MAX = 25

class History
  constructor: (@items=[]) ->
    @emitter = new Emitter
    @length = @items.length

  onDidAddItem: (callback) ->
    @emitter.on 'did-add-item', callback

  serialize: ->
    @items[-HISTORY_MAX..]

  getLast: ->
    _.last(@items)

  getAtIndex: (index) ->
    @items[index]

  add: (text) ->
    @items.push(text)
    @length = @items.length
    @emitter.emit 'did-add-item', text

  clear: ->
    @items = []
    @length = 0

# Adds the ability to cycle through history
class HistoryCycler

  # * `buffer` an {Editor} instance to attach the cycler to
  # * `history` a {History} object
  constructor: (@buffer, @history) ->
    @index = @history.length
    @history.onDidAddItem (text) =>
      @buffer.setText(text) if text isnt @buffer.getText()

  addEditorElement: (editorElement) ->
    atom.commands.add editorElement,
      'core:move-up': => @previous()
      'core:move-down': => @next()

  previous: ->
    if @history.length is 0 or (@atLastItem() and @buffer.getText() isnt @history.getLast())
      @scratch = @buffer.getText()
    else if @index > 0
      @index--

    @buffer.setText @history.getAtIndex(@index) ? ''

  next: ->
    if @index < @history.length - 1
      @index++
      item = @history.getAtIndex(@index)
    else if @scratch
      item = @scratch
    else
      item = ''

    @buffer.setText item

  atLastItem: ->
    @index is @history.length - 1

  store: ->
    text = @buffer.getText()
    return if not text or text is @history.getLast()
    @scratch = null
    @history.add(text)
    @index = @history.length - 1

module.exports = {History, HistoryCycler}
