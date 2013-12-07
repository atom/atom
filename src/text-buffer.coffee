_ = require 'underscore-plus'
{Emitter, Subscriber} = require 'emissary'
Q = require 'q'
{P} = require 'scandal'
telepath = require 'telepath'

File = require './file'

{Point, Range} = telepath

# Private: Represents the contents of a file.
#
# The `TextBuffer` is often associated with a {File}. However, this is not always
# the case, as a `TextBuffer` could be an unsaved chunk of text.
module.exports =
class TextBuffer extends telepath.Model
  Emitter.includeInto(this)
  Subscriber.includeInto(this)

  @properties
    text: -> new telepath.String('', replicated: false)
    filePath: null
    relativePath: null
    modifiedWhenLastPersisted: false
    digestWhenLastPersisted: null

  stoppedChangingDelay: 300
  stoppedChangingTimeout: null
  cachedDiskContents: null
  cachedMemoryContents: null
  conflict: false
  file: null
  refcount: 0

  constructor: ->
    super

    @loadWhenAttached = @getState()?

  # Private: Called by telepath.
  created: ->
    @loaded = false
    @useSerializedText = @modifiedWhenLastPersisted != false

    @subscribe @text, 'changed', @handleTextChange
    @subscribe @text, 'marker-created', (marker) => @emit 'marker-created', marker
    @subscribe @text, 'markers-updated', => @emit 'markers-updated'

    @setPath(@filePath)

    @load() if @loadWhenAttached

  # Private: Called by telepath.
  beforePersistence: ->
    @modifiedWhenLastPersisted = @isModified()
    @digestWhenLastPersisted = @file?.getDigest()

  loadSync: ->
    @updateCachedDiskContentsSync()
    @finishLoading()

  load: ->
    @updateCachedDiskContents().then => @finishLoading()

  finishLoading: ->
    if @isAlive()
      @loaded = true
      if @useSerializedText and @digestWhenLastPersisted is @file?.getDigest()
        @emitModifiedStatusChanged(true)
      else
        @reload()
      @text.clearUndoStack()
    this

  ### Internal ###

  handleTextChange: (event) =>
    @cachedMemoryContents = null
    @conflict = false if @conflict and !@isModified()
    bufferChangeEvent = _.pick(event, 'oldRange', 'newRange', 'oldText', 'newText')
    @emit 'changed', bufferChangeEvent
    @scheduleModifiedEvents()

  destroy: ->
    unless @destroyed
      @cancelStoppedChangingTimeout()
      @file?.off()
      @unsubscribe()
      @destroyed = true
      @emit 'destroyed', this

  isRetained: -> @refcount > 0

  retain: ->
    @refcount++
    this

  release: ->
    @refcount--
    @destroy() unless @isRetained()
    this

  subscribeToFile: ->
    @file.on "contents-changed", =>
      @conflict = true if @isModified()
      previousContents = @cachedDiskContents

      # Synchrounously update the disk contents because the {File} has already cached them. If the
      # contents updated asynchrounously multiple `conlict` events could trigger for the same disk
      # contents.
      @updateCachedDiskContentsSync()
      return if previousContents == @cachedDiskContents

      if @conflict
        @emit "contents-conflicted"
      else
        @reload()

    @file.on "removed", =>
      @updateCachedDiskContents().done =>
        @emitModifiedStatusChanged(@isModified())

    @file.on "moved", =>
      @emit "path-changed", this

  ### Public ###

  # Identifies if the buffer belongs to multiple editors.
  #
  # For example, if the {EditorView} was split.
  #
  # Returns a {Boolean}.
  hasMultipleEditors: -> @refcount > 1

  # Reloads a file in the {Editor}.
  #
  # Sets the buffer's content to the cached disk contents
  reload: ->
    @emit 'will-reload'
    @setText(@cachedDiskContents)
    @emitModifiedStatusChanged(false)
    @emit 'reloaded'

  # Private: Rereads the contents of the file, and stores them in the cache.
  updateCachedDiskContentsSync: ->
    @cachedDiskContents = @file?.readSync() ? ""

  # Private: Rereads the contents of the file, and stores them in the cache.
  updateCachedDiskContents: ->
    Q(@file?.read() ? "").then (contents) =>
      @cachedDiskContents = contents

  # Gets the file's basename--that is, the file without any directory information.
  #
  # Returns a {String}.
  getBaseName: ->
    @file?.getBaseName()

  # Retrieves the path for the file.
  #
  # Returns a {String}.
  getPath: ->
    @file?.getPath()

  getUri: ->
    atom.project.relativize(@getPath())

  # Sets the path for the file.
  #
  # path - A {String} representing the new file path
  setPath: (path) ->
    return if path == @getPath()

    @file?.off()

    if path
      @file = new File(path)
      @subscribeToFile()
    else
      @file = null

    @emit "path-changed", this

  # Retrieves the current buffer's file extension.
  #
  # Returns a {String}.
  getExtension: ->
    if @getPath()
      @getPath().split('/').pop().split('.').pop()
    else
      null

  # Retrieves the cached buffer contents.
  #
  # Returns a {String}.
  getText: ->
    @cachedMemoryContents ?= @getTextInRange(@getRange())

  # Replaces the current buffer contents.
  #
  # text - A {String} containing the new buffer contents.
  setText: (text) ->
    @change(@getRange(), text, normalizeLineEndings: false)

  # Gets the range of the buffer contents.
  #
  # Returns a new {Range}, from `[0, 0]` to the end of the buffer.
  getRange: ->
    lastRow = @getLastRow()
    new Range([0, 0], [lastRow, @lineLengthForRow(lastRow)])

  # Given a range, returns the lines of text within it.
  #
  # range - A {Range} object specifying your points of interest
  #
  # Returns a {String} of the combined lines.
  getTextInRange: (range) ->
    @text.getTextInRange(@clipRange(range))

  # Gets all the lines in a file.
  #
  # Returns an {Array} of {String}s.
  getLines: ->
    @text.getLines()

  # Given a row, returns the line of text.
  #
  # row - A {Number} indicating the row.
  #
  # Returns a {String}.
  lineForRow: (row) ->
    @text.lineForRow(row)

  # Given a row, returns its line ending.
  #
  # row - A {Number} indicating the row.
  #
  # Returns a {String}, or `undefined` if `row` is the final row.
  lineEndingForRow: (row) ->
    @text.lineEndingForRow(row)

  suggestedLineEndingForRow: (row) ->
    if row is @getLastRow()
      @lineEndingForRow(row - 1)
    else
      @lineEndingForRow(row)

  # Given a row, returns the length of the line of text.
  #
  # row - A {Number} indicating the row.
  #
  # Returns a {Number}.
  lineLengthForRow: (row) ->
    @text.lineLengthForRow(row)

  # Given a row, returns the length of the line ending
  #
  # row - A {Number} indicating the row.
  #
  # Returns a {Number}.
  lineEndingLengthForRow: (row) ->
    (@lineEndingForRow(row) ? '').length

  # Given a buffer row, this retrieves the range for that line.
  #
  # row - A {Number} identifying the row
  # options - A hash with one key, `includeNewline`, which specifies whether you
  #           want to include the trailing newline
  #
  # Returns a {Range}.
  rangeForRow: (row, { includeNewline } = {}) ->
    if includeNewline and row < @getLastRow()
      new Range([row, 0], [row + 1, 0])
    else
      new Range([row, 0], [row, @lineLengthForRow(row)])

  # Gets the number of lines in a file.
  #
  # Returns a {Number}.
  getLineCount: ->
    @text.getLineCount()

  # Gets the row number of the last line.
  #
  # Returns a {Number}.
  getLastRow: ->
    @getLineCount() - 1

  # Finds the last line in the current buffer.
  #
  # Returns a {String}.
  getLastLine: ->
    @lineForRow(@getLastRow())

  # Finds the last point in the current buffer.
  #
  # Returns a {Point} representing the last position.
  getEofPosition: ->
    lastRow = @getLastRow()
    new Point(lastRow, @lineLengthForRow(lastRow))

  characterIndexForPosition: (position) ->
    @text.indexForPoint(@clipPosition(position))

  positionForCharacterIndex: (index) ->
    @text.pointForIndex(index)

  # Given a row, this deletes it from the buffer.
  #
  # row - A {Number} representing the row to delete
  deleteRow: (row) ->
    @deleteRows(row, row)

  # Deletes a range of rows from the buffer.
  #
  # start - A {Number} representing the starting row
  # end - A {Number} representing the ending row
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

  # Adds text to the end of the buffer.
  #
  # text - A {String} of text to add
  append: (text) ->
    @insert(@getEofPosition(), text)

  # Adds text to a specific point in the buffer
  #
  # position - A {Point} in the buffer to insert into
  # text - A {String} of text to add
  insert: (position, text) ->
    @change(new Range(position, position), text)

  # Deletes text from the buffer
  #
  # range - A {Range} whose text to delete
  delete: (range) ->
    @change(range, '')

  # Given a position, this clips it to a real position.
  #
  # For example, if `position`'s row exceeds the row count of the buffer,
  # or if its column goes beyond a line's length, this "sanitizes" the value
  # to a real position.
  #
  # Returns the new, clipped {Point}. Note that this could be the same as `position` if no clipping was performed.
  clipPosition: (position) ->
    @text.clipPosition(position)

  # Given a range, this clips it to a real range.
  #
  # For example, if `range`'s row exceeds the row count of the buffer,
  # or if its column goes beyond a line's length, this "sanitizes" the value
  # to a real range.
  #
  # range - The {Range} to clip
  #
  # Returns the new, clipped {Range}. Note that this could be the same as `range` if no clipping was performed.
  clipRange: (range) ->
    range = Range.fromObject(range)
    new Range(@clipPosition(range.start), @clipPosition(range.end))

  undo: ->
    @text.undo()

  redo: ->
    @text.redo()

  # Saves the buffer.
  save: ->
    @saveAs(@getPath()) if @isModified()

  # Saves the buffer at a specific path.
  #
  # path - The path to save at.
  saveAs: (path) ->
    unless path then throw new Error("Can't save buffer with no file path")

    @emit 'will-be-saved', this
    @setPath(path)
    @cachedDiskContents = @getText()
    @file.write(@getText())
    @emitModifiedStatusChanged(false)
    @emit 'saved', this

  # Identifies if the buffer was modified.
  #
  # Returns a {Boolean}.
  isModified: ->
    return false unless @loaded
    if @file
      if @file.exists()
        @getText() != @cachedDiskContents
      else
        true
    else
      not @isEmpty()

  # Identifies if a buffer is in a git conflict with `HEAD`.
  #
  # Returns a {Boolean}.
  isInConflict: -> @conflict

  # Identifies if a buffer is empty.
  #
  # Returns a {Boolean}.
  isEmpty: -> @text.isEmpty()

  # Returns all valid {StringMarker}s on the buffer.
  getMarkers: ->
    @text.getMarkers()

  # Returns the {StringMarker} with the given id.
  getMarker: (id) ->
    @text.getMarker(id)

  destroyMarker: (id) ->
    @getMarker(id)?.destroy()

  # Public: Finds the first marker satisfying the given attributes
  #
  # Returns a {String} marker-identifier
  findMarker: (attributes) ->
    @text.findMarker(attributes)

  # Public: Finds all markers satisfying the given attributes
  #
  # attributes - The attributes against which to compare the markers' attributes
  #   There are some reserved keys that match against derived marker properties:
  #   startRow - The row at which the marker starts
  #   endRow - The row at which the marker ends
  #
  # Returns an {Array} of {StringMarker}s
  findMarkers: (attributes) ->
    @text.findMarkers(attributes)

  # Retrieves the quantity of markers in a buffer.
  #
  # Returns a {Number}.
  getMarkerCount: ->
    @text.getMarkers().length

  # Constructs a new marker at a given range.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # attributes - An optional hash of serializable attributes
  #   Any attributes you pass will be associated with the marker and can be retrieved
  #   or used in marker queries.
  #   The following attribute keys reserved, and control the marker's initial range
  #   isReversed - if `true`, the marker is reversed; that is, its head precedes the tail
  #   hasTail - if `false`, the marker is created without a tail
  #
  # Returns a {Number} representing the new marker's ID.
  markRange: (range, options={}) ->
    @text.markRange(range, options)

  # Constructs a new marker at a given position.
  #
  # position - The marker {Point}; there won't be a tail
  # options - Options to pass to the {StringMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markPosition: (position, options) ->
    @text.markPosition(position, options)

  # Identifies if a character sequence is within a certain range.
  #
  # regex - The {RegExp} to check
  # startIndex - The starting row {Number}
  # endIndex - The ending row {Number}
  #
  # Returns an {Array} of {RegExp}s, representing the matches.
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

  # Scans for text in the buffer, calling a function on each match.
  #
  # regex - A {RegExp} representing the text to find
  # iterator - A {Function} that's called on each match
  scan: (regex, iterator) ->
    @scanInRange regex, @getRange(), (result) =>
      result.lineText = @lineForRow(result.range.start.row)
      result.lineTextOffset = 0
      iterator(result)

  # Replace all matches of regex with replacementText
  #
  # regex: A {RegExp} representing the text to find
  # replacementText: A {String} representing the text to replace
  #
  # Returns the number of replacements made
  replace: (regex, replacementText) ->
    doSave = !@isModified()
    replacements = 0

    @transact =>
      @scan regex, ({matchText, replace}) ->
        replace(matchText.replace(regex, replacementText))
        replacements++

    @save() if doSave

    replacements

  # Scans for text in a given range, calling a function on each match.
  #
  # regex - A {RegExp} representing the text to find
  # range - A {Range} in the buffer to search within
  # iterator - A {Function} that's called on each match
  # reverse - A {Boolean} indicating if the search should be backwards (default: `false`)
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
      matchText = match[0]
      iterator({ match, matchText, range, stop, replace })

      if replacementText?
        @change(range, replacementText)
        lengthDelta += replacementText.length - matchLength unless reverse

      break unless global and keepLooping

  # Scans for text in a given range _backwards_, calling a function on each match.
  #
  # regex - A {RegExp} representing the text to find
  # range - A {Range} in the buffer to search within
  # iterator - A {Function} that's called on each match
  backwardsScanInRange: (regex, range, iterator) ->
    @scanInRange regex, range, iterator, true

  # Given a row, identifies if it is blank.
  #
  # row - A row {Number} to check
  #
  # Returns a {Boolean}.
  isRowBlank: (row) ->
    not /\S/.test @lineForRow(row)

  # Given a row, this finds the next row above it that's empty.
  #
  # startRow - A {Number} identifying the row to start checking at
  #
  # Returns the row {Number} of the first blank row.
  # Returns `null` if there's no other blank row.
  previousNonBlankRow: (startRow) ->
    return null if startRow == 0

    startRow = Math.min(startRow, @getLastRow())
    for row in [(startRow - 1)..0]
      return row unless @isRowBlank(row)
    null

  # Given a row, this finds the next row that's blank.
  #
  # startRow - A row {Number} to check
  #
  # Returns the row {Number} of the next blank row.
  # Returns `null` if there's no other blank row.
  nextNonBlankRow: (startRow) ->
    lastRow = @getLastRow()
    if startRow < lastRow
      for row in [(startRow + 1)..lastRow]
        return row unless @isRowBlank(row)
    null

  # Identifies if the buffer has soft tabs anywhere.
  #
  # Returns a {Boolean},
  usesSoftTabs: ->
    for row in [0..@getLastRow()]
      if match = @lineForRow(row).match(/^\s/)
        return match[0][0] != '\t'
    undefined

  ### Internal ###

  transact: (fn) -> @text.transact fn

  beginTransaction: -> @text.beginTransaction()

  commitTransaction: -> @text.commitTransaction()

  abortTransaction: -> @text.abortTransaction()

  change: (oldRange, newText, options={}) ->
    oldRange = @clipRange(oldRange)
    newText = @normalizeLineEndings(oldRange.start.row, newText) if options.normalizeLineEndings ? true
    @text.setTextInRange(oldRange, newText, options)

  normalizeLineEndings: (startRow, text) ->
    if lineEnding = @suggestedLineEndingForRow(startRow)
      text.replace(/\r?\n/g, lineEnding)
    else
      text

  cancelStoppedChangingTimeout: ->
    clearTimeout(@stoppedChangingTimeout) if @stoppedChangingTimeout

  scheduleModifiedEvents: ->
    @cancelStoppedChangingTimeout()
    stoppedChangingCallback = =>
      @stoppedChangingTimeout = null
      modifiedStatus = @isModified()
      @emit 'contents-modified', modifiedStatus
      @emitModifiedStatusChanged(modifiedStatus)
    @stoppedChangingTimeout = setTimeout(stoppedChangingCallback, @stoppedChangingDelay)

  emitModifiedStatusChanged: (modifiedStatus) ->
    return if modifiedStatus is @previousModifiedStatus
    @previousModifiedStatus = modifiedStatus
    @emit 'modified-status-changed', modifiedStatus

  logLines: (start=0, end=@getLastRow())->
    for row in [start..end]
      line = @lineForRow(row)
      console.log row, line, line.length
