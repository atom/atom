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

    preRange =
      start: { row, col }
      end: { row, col }

    if col == 0
      preRange.start.col = @lines[row - 1].length
      preRange.start.row--
      @lines[row-1..row] = @lines[row - 1] + @lines[row]
    else
      preRange.start.col--
      @lines[row] = line[0...col-1] + line[col..]

    postRange = { start: preRange.start, end: preRange.start }

    @trigger 'change', { preRange, postRange,  string: '' }

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

