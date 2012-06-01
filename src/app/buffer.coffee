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
  path: null

  @deserialize: (state, project) ->
    if state.path
      project.open(state.path)
    else
      buffer = project.bufferWithId(state.id) ? project.open()
      buffer.setText(state.text)
      buffer

  constructor: (path) ->
    @id = @constructor.idCounter++
    @setPath(path)
    @lines = ['']
    if @getPath() and fs.exists(@getPath())
      @setText(fs.read(@getPath()))
    else
      @setText('')
    @undoManager = new UndoManager(this)

  serialize: ->
    if @getPath()
      { path: @path }
    else
      { text: @getText(), id: @id }

  getPath: ->
    @path

  setPath: (path) ->
    @path = path
    @trigger "path-change", this

  getText: ->
    @lines.join('\n')

  setText: (text) ->
    @change(@getRange(), text)

  getRange: ->
    new Range([0, 0], [@getLastRow(), @lastLine().length])

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

  lineLengthForRow: (row) ->
    @lines[row].length

  rangeForRow: (row) ->
    new Range([row, 0], [row, @lineLengthForRow(row)])

  getLineCount: ->
    @getLines().length

  getLastRow: ->
    @getLines().length - 1

  lastLine: ->
    @lineForRow(@getLastRow())

  getEofPosition: ->
    lastRow = @getLastRow()
    new Point(lastRow, @lineLengthForRow(lastRow))

  characterIndexForPosition: (position) ->
    position = Point.fromObject(position)

    index = 0
    index += @lineLengthForRow(row) + 1 for row in [0...position.row]
    index + position.column

  positionForCharacterIndex: (index) ->
    row = 0
    while index >= (lineLength = @lineLengthForRow(row) + 1)
      index -= lineLength
      row++

    new Point(row, index)

  deleteRow: (row) ->
    range = null
    if row == @getLastRow()
      range = new Range([row - 1, @lineLengthForRow(row - 1)], [row, @lineLengthForRow(row)])
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
    newRange

  startUndoBatch: (selectedBufferRanges) ->
    @undoManager.startUndoBatch(selectedBufferRanges)

  endUndoBatch: (selectedBufferRanges) ->
    @undoManager.endUndoBatch(selectedBufferRanges)

  undo: ->
    @undoManager.undo()

  redo: ->
    @undoManager.redo()

  save: ->
    if not @getPath() then throw new Error("Tried to save buffer with no file path")
    @trigger 'before-save'
    fs.write @getPath(), @getText()
    @trigger 'after-save'

  saveAs: (path) ->
    @setPath(path)
    @save()

  getMode: ->
    return @mode if @mode
    extension = if @getPath() then @getPath().split('/').pop().split('.').pop() else null
    modeName = switch extension
      when 'js' then 'javascript'
      when 'coffee' then 'coffee'
      when 'rb', 'ru' then 'ruby'
      when 'c', 'h', 'cpp' then 'c_cpp'
      when 'html', 'htm' then 'html'
      when 'css' then 'css'
      else 'text'

    @mode = new (require("ace/mode/#{modeName}").Mode)

  matchesInCharacterRange: (regex, startIndex, endIndex) ->
    text = @getText()
    matches = []

    regex.lastIndex = startIndex
    while match = regex.exec(text)
      matchLength = match[0].length
      matchStartIndex = match.index
      matchEndIndex = matchStartIndex + matchLength

      if matchEndIndex > endIndex
        regex.lastIndex = 0
        if matchStartIndex < endIndex and submatch = regex.exec(text[matchStartIndex...endIndex])
          submatch.index = matchStartIndex
          matches.push submatch
        break

      matchEndIndex++ if matchLength is 0
      regex.lastIndex = matchEndIndex
      matches.push match

    matches

  scan: (regex, iterator) ->
    @scanInRange(regex, @getRange(), iterator)

  scanInRange: (regex, range, iterator, reverse=false) ->
    range = Range.fromObject(range)
    global = regex.global
    regex = new RegExp(regex.source, 'gm')

    startIndex = @characterIndexForPosition(range.start)
    endIndex = @characterIndexForPosition(range.end)

    matches = @matchesInCharacterRange(regex, startIndex, endIndex)
    lengthDelta = 0

    keepLooping = null
    replacementText = null
    stop = -> keepLooping = false
    replace = (text) -> replacementText = text

    matches.reverse() if reverse
    for match in matches
      matchLength = match[0].length
      matchStartIndex = match.index
      matchEndIndex = matchStartIndex + matchLength

      startPosition = @positionForCharacterIndex(matchStartIndex + lengthDelta)
      endPosition = @positionForCharacterIndex(matchEndIndex + lengthDelta)
      range = new Range(startPosition, endPosition)
      keepLooping = true
      replacementText = null
      iterator(match, range, { stop, replace })

      if replacementText?
        @change(range, replacementText)
        lengthDelta += replacementText.length - matchLength unless reverse

      break unless global and keepLooping

  backwardsScanInRange: (regex, range, iterator) ->
    @scanInRange regex, range, iterator, true

  logLines: (start=0, end=@getLastRow())->
    for row in [start..end]
      line = @lineForRow(row)
      console.log row, line, line.length

_.extend(Buffer.prototype, EventEmitter)
