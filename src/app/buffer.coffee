_ = require 'underscore'
fs = require 'fs'
File = require 'file'
Point = require 'point'
Range = require 'range'
EventEmitter = require 'event-emitter'
UndoManager = require 'undo-manager'
BufferChangeOperation = require 'buffer-change-operation'
Anchor = require 'anchor'
AnchorRange = require 'anchor-range'

module.exports =
class Buffer
  @idCounter = 1
  undoManager: null
  modified: null
  modifiedOnDisk: null
  lines: null
  file: null
  anchors: null
  anchorRanges: null
  refcount: 0

  constructor: (path, @project) ->
    @id = @constructor.idCounter++
    @anchors = []
    @anchorRanges = []
    @lines = ['']

    if path
      throw "Path '#{path}' does not exist" unless fs.exists(path)
      @setPath(path)
      @setText(fs.read(@getPath()))
    else
      @setText('')

    @undoManager = new UndoManager(this)
    @modified = false

  destroy: ->
    throw new Error("Destroying buffer twice with path '#{@getPath()}'") if @destroyed
    @file?.off()
    @destroyed = true
    @project?.removeBuffer(this)

  retain: ->
    @refcount++
    this

  release: ->
    @refcount--
    @destroy() if @refcount <= 0
    this

  subscribeToFile: ->
    @file.on "contents-change", =>
      if @isModified()
        @modifiedOnDisk = true
      else
        @setText(fs.read(@file.getPath()))
        @modified = false

    @file.on "remove", =>
      @file = null
      @trigger "path-change", this

    @file.on "move", =>
      @trigger "path-change", this

  reload: ->
    @setText(fs.read(@file.getPath()))
    @modified = false
    @modifiedOnDisk = false

  getBaseName: ->
    @file?.getBaseName()

  getPath: ->
    @file?.getPath()

  setPath: (path) ->
    return if path == @getPath()

    @file?.off()
    @file = new File(path)
    @subscribeToFile()
    @file.on "contents-change", =>
      if @isModified()
        @modifiedOnDisk = true
        @trigger "contents-change-on-disk"
      else
        @setText(fs.read(@file.getPath()))
        @modified = false
    @trigger "path-change", this

  getExtension: ->
    if @getPath()
      @getPath().split('/').pop().split('.').pop()
    else
      null

  getText: ->
    @lines.join('\n')

  setText: (text) ->
    @change(@getRange(), text)

  getRange: ->
    new Range([0, 0], [@getLastRow(), @getLastLine().length])

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

  getLastLine: ->
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
    @deleteRows(row, row)

  deleteRows: (start, end) ->
    startPoint = null
    endPoint = null
    if end == @getLastRow()
      if start > 0
        startPoint = [start - 1, @lineLengthForRow(start - 1)]
      else
        startPoint = [start, 0]
      endPoint = [end, @lineLengthForRow(end)]
    else
      startPoint = [start, 0]
      endPoint = [end + 1, 0]

    @change(new Range(startPoint, endPoint), '')

  insert: (point, text) ->
    @change(new Range(point, point), text)

  delete: (range) ->
    @change(range, '')

  change: (oldRange, newText) ->
    @trigger 'buffer-change'
    oldRange = Range.fromObject(oldRange)
    operation = new BufferChangeOperation({buffer: this, oldRange, newText})
    @pushOperation(operation)

  clipPosition: (position) ->
    { row, column } = Point.fromObject(position)
    row = 0 if row < 0
    column = 0 if column < 0
    row = Math.min(@getLastRow(), row)
    column = Math.min(@lineLengthForRow(row), column)

    new Point(row, column)

  prefixAndSuffixForRange: (range) ->
    prefix: @lines[range.start.row][0...range.start.column]
    suffix: @lines[range.end.row][range.end.column..]

  replaceLines: (startRow, endRow, newLines) ->
    @lines[startRow..endRow] = newLines
    @modified = true

  pushOperation: (operation, editSession) ->
    if @undoManager
      @undoManager.pushOperation(operation, editSession)
    else
      operation.do()

  transact: (fn) ->
    @undoManager.transact(fn)

  undo: (editSession) ->
    @undoManager.undo(editSession)

  redo: (editSession) ->
    @undoManager.redo(editSession)

  save: ->
    @trigger 'buffer-change'
    @saveAs(@getPath())

  saveAs: (path) ->
    if not path then throw new Error("Can't save buffer with no file path")

    @trigger 'before-save'
    fs.write path, @getText()
    @file?.updateMd5()
    @modified = false
    @modifiedOnDisk = false
    @setPath(path)
    @trigger 'after-save'

  isInConflict: ->
    @isModified() and @isModifiedOnDisk()

  isModifiedOnDisk: ->
    @modifiedOnDisk

  isModified: ->
    @modified

  getAnchors: -> new Array(@anchors...)

  addAnchor: (options) ->
    anchor = new Anchor(this, options)
    @anchors.push(anchor)
    anchor

  addAnchorAtPosition: (position, options) ->
    anchor = @addAnchor(options)
    anchor.setBufferPosition(position)
    anchor

  addAnchorRange: (range, editSession) ->
    anchorRange = new AnchorRange(range, this, editSession)
    @anchorRanges.push(anchorRange)
    anchorRange

  removeAnchor: (anchor) ->
    _.remove(@anchors, anchor)

  removeAnchorRange: (anchorRange) ->
    _.remove(@anchorRanges, anchorRange)

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
    flags = "gm"
    flags += "i" if regex.ignoreCase
    regex = new RegExp(regex.source, flags)

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

  isRowBlank: (row) ->
    not /\S/.test @lineForRow(row)

  previousNonBlankRow: (startRow) ->
    return null if startRow == 0

    startRow = Math.min(startRow, @getLastRow())
    for row in [(startRow - 1)..0]
      return row unless @isRowBlank(row)
    null

  nextNonBlankRow: (startRow) ->
    lastRow = @getLastRow()
    if startRow < lastRow
      for row in [(startRow + 1)..lastRow]
        return row unless @isRowBlank(row)
    null

  indentationForRow: (row) ->
    @lineForRow(row).match(/^\s*/)?[0].length

  setIndentationForRow: (bufferRow, newLevel) ->
    currentLevel = @indentationForRow(bufferRow)
    indentString = [0...newLevel].map(-> ' ').join('')
    @change([[bufferRow, 0], [bufferRow, currentLevel]], indentString)

  logLines: (start=0, end=@getLastRow())->
    for row in [start..end]
      line = @lineForRow(row)
      console.log row, line, line.length

_.extend(Buffer.prototype, EventEmitter)
