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

  insert: ({row, col}, string) ->
    originalLine = @getLine(row)
    originalPrefix = originalLine[0...col]
    originalSuffix = originalLine[col..]

    if string == '\n'
      @lines[row] = originalPrefix
      @lines[row + 1...row + 1] = originalSuffix
    else
      @lines[row] = originalPrefix + string + originalSuffix

    @trigger 'insert'
      string: string
      range:
        start: {row, col}
        end: {row, col}

  backspace: ({row, col}) ->
    line = @lines[row]
    if col == 0
      @lines[row-1..row] = @lines[row - 1] + @lines[row]
    else
      @lines[row] = line[row..col] + line[col + 1..]

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

