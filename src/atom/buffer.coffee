_ = require 'underscore'
fs = require 'fs'
Range = require 'range'

module.exports =
class Buffer
  lines: null

  constructor: (@path) ->
    @url = @path # we want this to be path on master, but let's not break it on a branch
    @lines = ['']
    if @path and fs.exists(@path)
      @setText(fs.read(@path))
    else
      @setText('')

  getText: ->
    @lines.join('\n')

  setText: (text) ->
    @change(@getRange(), text)

  getRange: ->
    new Range([0, 0], [@lastRow(), @lastLine().length])

  getTextInRange: (range) ->
    if range.start.row == range.end.row
      return @lines[range.start.row][range.start.column...range.end.column]

    multipleLines = []
    multipleLines.push @lines[range.start.row][range.start.column..] # first line
    for row in [range.start.row + 1...range.end.row]
      multipleLines.push @lines[row] # middle lines
    multipleLines.push @lines[range.end.row][0...range.end.column] # last line

    return multipleLines.join '\n'

  getLines: ->
    @lines

  getLine: (row) ->
    @lines[row]

  numLines: ->
    @getLines().length

  lastRow: ->
    @getLines().length - 1

  lastLine: ->
    @getLine(@lastRow())

  insert: (point, text) ->
    @change(new Range(point, point), text)

  change: (preRange, newText) ->
    postRange = new Range(_.clone(preRange.start), _.clone(preRange.start))
    prefix = @lines[preRange.start.row][0...preRange.start.column]
    suffix = @lines[preRange.end.row][preRange.end.column..]
    newTextLines = newText.split('\n')

    if newTextLines.length == 1
      postRange.end.column += newText.length
      linesToInsert = [prefix + newText + suffix]
    else
      firstLineIndex = 0
      lastLineIndex = newTextLines.length - 1

      linesToInsert =
        for line, i in newTextLines
          switch i
            when firstLineIndex
              prefix + line
            when lastLineIndex
              postRange.end.row += i
              postRange.end.column = line.length
              line + suffix
            else
              line

    @lines[preRange.start.row..preRange.end.row] = linesToInsert
    @trigger 'change', { preRange, postRange, string: newText }

  save: ->
    if not @path then throw new Error("Tried to save buffer with no url")
    fs.write @path, @getText()

  on: (eventName, handler) ->
    @eventHandlers ?= {}
    @eventHandlers[eventName] ?= []
    @eventHandlers[eventName].push(handler)

  trigger: (eventName, event) ->
    @eventHandlers?[eventName]?.forEach (handler) -> handler(event)

  modeName: ->
    extension = if @path then @path.split('/').pop().split('.').pop() else null
    switch extension
      when 'js' then 'javascript'
      when 'coffee' then 'coffee'
      when 'rb', 'ru' then 'ruby'
      when 'c', 'h', 'cpp' then 'c_cpp'
      when 'html', 'htm' then 'html'
      when 'css' then 'css'
      else 'text'

