_ = require 'underscore'
fs = require 'fs'
Point = require 'point'
Range = require 'range'
EventEmitter = require 'event-emitter'
UndoManager = require 'undo-manager'

module.exports =
class Buffer
  @idCounter = 1
  lines: null

  constructor: (@path) ->
    @id = @constructor.idCounter++
    @url = @path # we want this to be path on master, but let's not break it on a branch
    @lines = ['']
    if @path and fs.exists(@path)
      @setText(fs.read(@path))
    else
      @setText('')
    @undoManager = new UndoManager(this)

  getText: ->
    @lines.join('\n')

  setText: (text) ->
    @change(@getRange(), text)

  getRange: ->
    new Range([0, 0], [@lastRow(), @lastLine().length])

  getTextInRange: (range) ->
    range = Range.fromObject(range)
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

  lineForRow: (row) ->
    @lines[row]

  getLineLength: (row) ->
    @lines[row].length

  numLines: ->
    @getLines().length

  lastRow: ->
    @getLines().length - 1

  lastLine: ->
    @lineForRow(@lastRow())

  characterIndexForPosition: (position) ->
    position = Point.fromObject(position)

    index = 0
    index += @getLineLength(row) + 1 for row in [0...position.row]
    index + position.column

  deleteRow: (row) ->
    range = null
    if row == @lastRow()
      range = new Range([row - 1, @getLineLength(row - 1)], [row, @getLineLength(row)])
    else
      range = new Range([row, 0], [row + 1, 0])

    @change(range, '')

  insert: (point, text) ->
    @change(new Range(point, point), text)

  delete: (range) ->
    @change(range, '')

  change: (oldRange, newText) ->
    oldRange = Range.fromObject(oldRange)
    newRange = new Range(oldRange.start.copy(), oldRange.start.copy())
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

  undo: ->
    @undoManager.undo()

  redo: ->
    @undoManager.redo()

  save: ->
    if not @path then throw new Error("Tried to save buffer with no url")
    fs.write @path, @getText()

  getMode: ->
    return @mode if @mode
    extension = if @path then @path.split('/').pop().split('.').pop() else null
    modeName = switch extension
      when 'js' then 'javascript'
      when 'coffee' then 'coffee'
      when 'rb', 'ru' then 'ruby'
      when 'c', 'h', 'cpp' then 'c_cpp'
      when 'html', 'htm' then 'html'
      when 'css' then 'css'
      else 'text'

    @mode = new (require("ace/mode/#{modeName}").Mode)

_.extend(Buffer.prototype, EventEmitter)
