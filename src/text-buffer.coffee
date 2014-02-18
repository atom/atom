_ = require 'underscore-plus'
Q = require 'q'
{P} = require 'scandal'
Serializable = require 'serializable'
TextBufferCore = require 'text-buffer'
{Point, Range} = TextBufferCore
{Subscriber, Emitter} = require 'emissary'

File = require './file'

# Represents the contents of a file.
#
# The `TextBuffer` is often associated with a {File}. However, this is not
# always the case, as a `TextBuffer` could contain an unsaved chunk of text.
module.exports =
class TextBuffer extends TextBufferCore
  atom.deserializers.add(this)

  Serializable.includeInto(this)
  Subscriber.includeInto(this)
  Emitter.includeInto(this)

  stoppedChangingDelay: 300
  stoppedChangingTimeout: null
  cachedDiskContents: null
  conflict: false
  file: null
  refcount: 0

  constructor: ({filePath, @modifiedWhenLastPersisted, @digestWhenLastPersisted, loadWhenAttached}={}) ->
    super
    @loaded = false
    @modifiedWhenLastPersisted ?= false

    @useSerializedText = @modifiedWhenLastPersisted != false

    @subscribe this, 'changed', @handleTextChange

    @setPath(filePath)

    @load() if loadWhenAttached

  serializeParams: ->
    params = super
    _.extend params,
      filePath: @getPath()
      modifiedWhenLastPersisted: @isModified()
      digestWhenLastPersisted: @file?.getDigest()

  deserializeParams: (params) ->
    params = super(params)
    params.loadWhenAttached = true
    params

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
      @clearUndoStack()
    this

  handleTextChange: (event) =>
    @conflict = false if @conflict and !@isModified()
    @scheduleModifiedEvents()

  destroy: ->
    unless @destroyed
      @cancelStoppedChangingTimeout()
      @file?.off()
      @unsubscribe()
      @destroyed = true
      @emit 'destroyed'

  isAlive: -> not @destroyed

  isDestroyed: -> @destroyed

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
      modified = @getText() != @cachedDiskContents
      @wasModifiedBeforeRemove = modified
      if modified
        @updateCachedDiskContents()
      else
        @destroy()

    @file.on "moved", =>
      @emit "path-changed", this

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
    @setTextViaDiff(@cachedDiskContents)
    @emitModifiedStatusChanged(false)
    @emit 'reloaded'

  # Rereads the contents of the file, and stores them in the cache.
  updateCachedDiskContentsSync: ->
    @cachedDiskContents = @file?.readSync() ? ""

  # Rereads the contents of the file, and stores them in the cache.
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
  # filePath - A {String} representing the new file path
  setPath: (filePath) ->
    return if filePath == @getPath()

    @file?.off()

    if filePath
      @file = new File(filePath)
      @subscribeToFile()
    else
      @file = null

    @emit "path-changed", this

  # Deprecated: Use ::getEndPosition instead
  getEofPosition: -> @getEndPosition()

  # Saves the buffer.
  save: ->
    @saveAs(@getPath()) if @isModified()

  # Saves the buffer at a specific path.
  #
  # filePath - The path to save at.
  saveAs: (filePath) ->
    unless filePath then throw new Error("Can't save buffer with no file path")

    @emit 'will-be-saved', this
    @setPath(filePath)
    @file.write(@getText())
    @cachedDiskContents = @getText()
    @conflict = false
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
        @wasModifiedBeforeRemove ? not @isEmpty()
    else
      not @isEmpty()

  # Is the buffer's text in conflict with the text on disk?
  #
  # This occurs when the buffer's file changes on disk while the buffer has
  # unsaved changes.
  #
  # Returns a {Boolean}.
  isInConflict: -> @conflict

  destroyMarker: (id) ->
    @getMarker(id)?.destroy()

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

  change: (oldRange, newText, options={}) ->
    @setTextInRange(oldRange, newText, options.normalizeLineEndings)

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
