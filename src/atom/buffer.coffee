fs = require 'fs'
{Document} = require 'ace/document'

module.exports =
class Buffer
  lines: null

  constructor: (@path) ->
    @url = @path # we want this to be path on master, but let's not break it on a branch
    if @path and fs.exists(@path)
      @setText(fs.read(@path))
    else
      @setText('')

  getText: ->
    @lines.join('\n')

  setText: (text) ->
    @lines = text.split('\n')

  getLines: ->
    @lines

  getLine: (n) ->
    @lines[n]

  insert: ({x, y}, string) ->
    line = @getLine(x)
    before = line.substring(0, y)
    after = line.substring(y)
    @lines[x] = before + string + after

    @trigger 'insert'
      string: string
      range:
        start: {x, y}
        end: {x, y}

  numLines: ->
    @getLines().length

  save: ->
    if not @path then throw new Error("Tried to save buffer with no url")
    fs.write @path, @getText()

  on: (eventName, handler) ->
    @handlers ?= {}
    @handlers[eventName] ?= []
    @handlers[eventName].push(handler)

  trigger: (eventName, data) ->
    @handlers?[eventName]?.forEach (handler) -> handler(data)

