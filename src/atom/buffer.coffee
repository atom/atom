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

  getLineLength: (row) ->
    @lines[row].length

  numLines: ->
    @getLines().length

  lastRow: ->
    @getLines().length - 1

  lastLine: ->
    @getLine(@lastRow())

  deleteRow: (row) ->
    range = null
    if row == @lastRow()
      range = new Range([row - 1, @getLineLength(row - 1)], [row, @getLineLength(row)])
    else
      range = new Range([row, 0], [row + 1, 0])

    @change(range, '')

  insert: (point, text) ->
    @change(new Range(point, point), text)

  change: (oldRange, newText) ->
    newRange = new Range(_.clone(oldRange.start), _.clone(oldRange.start))
    prefix = @lines[oldRange.start.row][0...oldRange.start.column]
    suffix = @lines[oldRange.end.row][oldRange.end.column..]
    oldText = @getTextInRange(oldRange)

    newTextLines = newText.split('\n')

    if newTextLines.length == 1
      newRange.end.column += newText.length
      newTextLines = [prefix + newText + suffix]
    else
      lastLineIndex = newTextLines.length - 1
      newTextLines[0] = prefix + newTextLines[0]
      newRange.end.row += lastLineIndex
      newRange.end.column = newTextLines[lastLineIndex].length
      newTextLines[lastLineIndex] += suffix

    @lines[oldRange.start.row..oldRange.end.row] = newTextLines
    @trigger 'change', { oldRange, newRange, oldText, newText }

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

