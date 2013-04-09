_ = require 'underscore'
fsUtils = require 'fs-utils'
File = require 'file'
Point = require 'point'
Range = require 'range'
EventEmitter = require 'event-emitter'
UndoManager = require 'undo-manager'
BufferChangeOperation = require 'buffer-change-operation'
BufferMarker = require 'buffer-marker'

module.exports =
class Buffer
  @idCounter = 1
  registerDeserializer(this)
  stoppedChangingDelay: 300
  stoppedChangingTimeout: null
  undoManager: null
  cachedDiskContents: null
  cachedMemoryContents: null
  conflict: false
  lines: null
  lineEndings: null
  file: null
  validMarkers: null
  invalidMarkers: null
  refcount: 0

  @deserialize: ({path, text}) ->
    project.bufferForPath(path, text)

  constructor: (path, initialText) ->
    @id = @constructor.idCounter++
    @nextMarkerId = 1
    @validMarkers = {}
    @invalidMarkers = {}
    @lines = ['']
    @lineEndings = []

    if path
      @setPath(path)
      if initialText?
        @setText(initialText)
        @updateCachedDiskContents()
      else if fsUtils.exists(path)
        @reload()
      else
        @setText('')
    else
      @setText(initialText ? '')

    @undoManager = new UndoManager(this)

  destroy: ->
    throw new Error("Destroying buffer twice with path '#{@getPath()}'") if @destroyed
    @file?.off()
    @destroyed = true
    project?.removeBuffer(this)

  retain: ->
    @refcount++
    this

  release: ->
    @refcount--
    @destroy() if @refcount <= 0
    this

  serialize: ->
    deserializer: 'TextBuffer'
    path: @getPath()
    text: @getText() if @isModified()

  hasMultipleEditors: -> @refcount > 1

  subscribeToFile: ->
    @file.on "contents-changed", =>
      if @isModified()
        @conflict = true
        @updateCachedDiskContents()
        @trigger "contents-conflicted"
      else
        @reload()

    @file.on "removed", =>
      @updateCachedDiskContents()
      @triggerModifiedStatusChanged(@isModified())

    @file.on "moved", =>
      @trigger "path-changed", this

  reload: ->
    @trigger 'will-reload'
    @updateCachedDiskContents()
    @setText(@cachedDiskContents)
    @triggerModifiedStatusChanged(false)
    @trigger 'reloaded'

  updateCachedDiskContents: ->
    if @file?
      @cachedDiskContents = @file.read()

  getBaseName: ->
    @file?.getBaseName()

  getPath: ->
    @file?.getPath()

  setPath: (path) ->
    return if path == @getPath()

    @file?.off()
    @file = new File(path)
    @file.read() if @file.exists()
    @subscribeToFile()

    @trigger "path-changed", this

  getExtension: ->
    if @getPath()
      @getPath().split('/').pop().split('.').pop()
    else
      null

  getText: ->
    @cachedMemoryContents ?= @getTextInRange(@getRange())

  setText: (text) ->
    @change(@getRange(), text, normalizeLineEndings: false)

  getRange: ->
    new Range([0, 0], [@getLastRow(), @getLastLine().length])

  getTextInRange: (range) ->
    range = @clipRange(range)
    if range.start.row == range.end.row
      return @lineForRow(range.start.row)[range.start.column...range.end.column]

    multipleLines = []
    multipleLines.push @lineForRow(range.start.row)[range.start.column..] # first line
    multipleLines.push @lineEndingForRow(range.start.row)
    for row in [range.start.row + 1...range.end.row]
      multipleLines.push @lineForRow(row) # middle lines
      multipleLines.push @lineEndingForRow(row)
    multipleLines.push @lineForRow(range.end.row)[0...range.end.column] # last line

    return multipleLines.join ''

  getLines: ->
    @lines

  lineForRow: (row) ->
    @lines[row]

  lineEndingForRow: (row) ->
    @lineEndings[row] unless row is @getLastRow()

  suggestedLineEndingForRow: (row) ->
    @lineEndingForRow(row) ? @lineEndingForRow(row - 1)

  lineLengthForRow: (row) ->
    @lines[row].length

  lineEndingLengthForRow: (row) ->
    (@lineEndingForRow(row) ? '').length

  rangeForRow: (row, { includeNewline } = {}) ->
    if includeNewline and row < @getLastRow()
      new Range([row, 0], [row + 1, 0])
    else
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
    position = @clipPosition(position)

    index = 0
    for row in [0...position.row]
      index += @lineLengthForRow(row) + Math.max(@lineEndingLengthForRow(row), 1)
    index + position.column

  positionForCharacterIndex: (index) ->
    row = 0
    while index >= (lineLength = @lineLengthForRow(row) + Math.max(@lineEndingLengthForRow(row), 1))
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

    @delete(new Range(startPoint, endPoint))

  append: (text) ->
    @insert(@getEofPosition(), text)

  insert: (point, text) ->
    @change(new Range(point, point), text)

  delete: (range) ->
    @change(range, '')

  change: (oldRange, newText, options) ->
    oldRange = Range.fromObject(oldRange)
    operation = new BufferChangeOperation({buffer: this, oldRange, newText, options})
    range = @pushOperation(operation)
    range

  clipPosition: (position) ->
    position = Point.fromObject(position)
    eofPosition = @getEofPosition()
    if position.isGreaterThan(eofPosition)
      eofPosition
    else
      row = Math.max(position.row, 0)
      column = Math.max(position.column, 0)
      column = Math.min(@lineLengthForRow(row), column)
      new Point(row, column)

  clipRange: (range) ->
    range = Range.fromObject(range)
    new Range(@clipPosition(range.start), @clipPosition(range.end))

  prefixAndSuffixForRange: (range) ->
    prefix: @lines[range.start.row][0...range.start.column]
    suffix: @lines[range.end.row][range.end.column..]

  pushOperation: (operation, editSession) ->
    if @undoManager
      @undoManager.pushOperation(operation, editSession)
    else
      operation.do()

  transact: (fn) ->  @undoManager.transact(fn)
  undo: (editSession) -> @undoManager.undo(editSession)
  redo: (editSession) -> @undoManager.redo(editSession)
  commit: -> @undoManager.commit()
  abort: -> @undoManager.abort()

  save: ->
    @saveAs(@getPath()) if @isModified()

  saveAs: (path) ->
    unless path then throw new Error("Can't save buffer with no file path")

    @trigger 'will-be-saved'
    @setPath(path)
    @cachedDiskContents = @getText()
    @file.write(@getText())
    @triggerModifiedStatusChanged(false)
    @trigger 'saved'

  isModified: ->
    if @file
      @getText() != @cachedDiskContents
    else
      not @isEmpty()

  isInConflict: -> @conflict

  isEmpty: -> @lines.length is 1 and @lines[0].length is 0

  getMarkers: ->
    _.values(@validMarkers)

  getMarkerCount: ->
    _.size(@validMarkers)

  markRange: (range, options={}) ->
    marker = new BufferMarker(_.defaults({
      id: (@nextMarkerId++).toString()
      buffer: this
      range
    }, options))
    @validMarkers[marker.id] = marker
    marker.id

  markPosition: (position, options) ->
    @markRange([position, position], _.defaults({noTail: true}, options))

  destroyMarker: (id) ->
    delete @validMarkers[id]
    delete @invalidMarkers[id]

  getMarkerPosition: (args...) ->
    @getMarkerHeadPosition(args...)

  setMarkerPosition: (args...) ->
    @setMarkerHeadPosition(args...)

  getMarkerHeadPosition: (id) ->
    @validMarkers[id]?.getHeadPosition()

  setMarkerHeadPosition: (id, position, options) ->
    @validMarkers[id]?.setHeadPosition(position)

  getMarkerTailPosition: (id) ->
    @validMarkers[id]?.getTailPosition()

  setMarkerTailPosition: (id, position, options) ->
    @validMarkers[id]?.setTailPosition(position)

  getMarkerRange: (id) ->
    @validMarkers[id]?.getRange()

  setMarkerRange: (id, range, options) ->
    @validMarkers[id]?.setRange(range, options)

  placeMarkerTail: (id) ->
    @validMarkers[id]?.placeTail()

  clearMarkerTail: (id) ->
    @validMarkers[id]?.clearTail()

  isMarkerReversed: (id) ->
    @validMarkers[id]?.isReversed()

  isMarkerRangeEmpty: (id) ->
    @validMarkers[id]?.isRangeEmpty()

  observeMarker: (id, callback) ->
    @validMarkers[id]?.observe(callback)

  markersForPosition: (bufferPosition) ->
    bufferPosition = Point.fromObject(bufferPosition)
    ids = []
    for id, marker of @validMarkers
      ids.push(id) if marker.containsPoint(bufferPosition)
    ids

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
    range = @clipRange(range)
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
      iterator({match, range, stop, replace })

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

  usesSoftTabs: ->
    for line in @getLines()
      if match = line.match(/^\s/)
        return match[0][0] != '\t'
    undefined

  checkoutHead: ->
    path = @getPath()
    return unless path
    git?.checkoutHead(path)

  scheduleModifiedEvents: ->
    clearTimeout(@stoppedChangingTimeout) if @stoppedChangingTimeout
    stoppedChangingCallback = =>
      @stoppedChangingTimeout = null
      modifiedStatus = @isModified()
      @trigger 'contents-modified', modifiedStatus
      @triggerModifiedStatusChanged(modifiedStatus)
    @stoppedChangingTimeout = setTimeout(stoppedChangingCallback, @stoppedChangingDelay)

  triggerModifiedStatusChanged: (modifiedStatus) ->
    return if modifiedStatus is @previousModifiedStatus
    @previousModifiedStatus = modifiedStatus
    @trigger 'modified-status-changed', modifiedStatus

  fileExists: ->
    @file? && @file.exists()

  logLines: (start=0, end=@getLastRow())->
    for row in [start..end]
      line = @lineForRow(row)
      console.log row, line, line.length

  getDebugSnapshot: ->
    lines = ['Buffer:']
    for row in [0..@getLastRow()]
      lines.push "#{row}: #{@lineForRow(row)}"
    lines.join('\n')

_.extend(Buffer.prototype, EventEmitter)
