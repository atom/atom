_ = require 'underscore'
fsUtils = require 'fs-utils'
path = require 'path'
telepath = require 'telepath'
guid = require 'guid'
{Point, Range} = telepath
Buffer = require 'text-buffer'
LanguageMode = require 'language-mode'
DisplayBuffer = require 'display-buffer'
Cursor = require 'cursor'
Selection = require 'selection'
EventEmitter = require 'event-emitter'
Subscriber = require 'subscriber'
TextMateScopeSelector = require('first-mate').ScopeSelector

# An `EditSession` manages the states between {Editor}s, {Buffer}s, and the project as a whole.
module.exports =
class EditSession
  @acceptsDocuments: true

  registerDeserializer(this)

  ### Internal ###

  @version: 4

  @deserialize: (state) ->
    new EditSession(state)

  id: null
  languageMode: null
  displayBuffer: null
  cursors: null
  remoteCursors: null
  selections: null
  remoteSelections: null
  suppressSelectionMerging: false

  constructor: (optionsOrState) ->
    @cursors = []
    @remoteCursors = []
    @selections = []
    @remoteSelections = []
    if optionsOrState instanceof telepath.Document
      @state = optionsOrState
      @id = @state.get('id')
      displayBuffer = deserialize(@state.get('displayBuffer'))
      @setBuffer(displayBuffer.buffer)
      @setDisplayBuffer(displayBuffer)
      for marker in @findMarkers(@getSelectionMarkerAttributes())
        marker.setAttributes(preserveFolds: true)
        @addSelection(marker)
      @setScrollTop(@state.get('scrollTop'))
      @setScrollLeft(@state.get('scrollLeft'))
      registerEditSession = true
    else
      {buffer, displayBuffer, tabLength, softTabs, softWrap, suppressCursorCreation} = optionsOrState
      @id = guid.create().toString()
      displayBuffer ?= new DisplayBuffer({buffer, tabLength})
      @state = site.createDocument
        deserializer: @constructor.name
        version: @constructor.version
        id: @id
        displayBuffer: displayBuffer.getState()
        softWrap: softWrap ? false
        softTabs: buffer.usesSoftTabs() ? softTabs ? true
        scrollTop: 0
        scrollLeft: 0
      @setBuffer(buffer)
      @setDisplayBuffer(displayBuffer)

    if @getCursors().length is 0 and not suppressCursorCreation
      position = _.last(@getRemoteCursors())?.getBufferPosition() ? [0, 0]
      @addCursorAtBufferPosition(position)

    @languageMode = new LanguageMode(this, @buffer.getExtension())
    @state.on 'changed', ({key, newValue}) =>
      switch key
        when 'scrollTop'
          @trigger 'scroll-top-changed', newValue
        when 'scrollLeft'
          @trigger 'scroll-left-changed', newValue

    project.addEditSession(this) if registerEditSession

  setBuffer: (@buffer) ->
    @buffer.retain()
    @subscribe @buffer, "path-changed", =>
      project.setPath(path.dirname(@getPath())) unless project.getPath()?
      @trigger "title-changed"
      @trigger "path-changed"
    @subscribe @buffer, "contents-conflicted", => @trigger "contents-conflicted"
    @subscribe @buffer, "modified-status-changed", => @trigger "modified-status-changed"
    @preserveCursorPositionOnBufferReload()

  setDisplayBuffer: (@displayBuffer) ->
    @subscribe @displayBuffer, 'marker-created', @handleMarkerCreated
    @subscribe @displayBuffer, "changed", (e) => @trigger 'screen-lines-changed', e
    @subscribe @displayBuffer, "markers-updated", => @mergeIntersectingSelections()
    @subscribe @displayBuffer, 'grammar-changed', => @handleGrammarChange()

  getViewClass: ->
    require 'editor'

  destroy: ->
    return if @destroyed
    @destroyed = true
    @unsubscribe()
    @buffer.release()
    selection.destroy() for selection in @getSelections()
    @displayBuffer.destroy()
    @languageMode.destroy()
    project?.removeEditSession(this)
    @trigger 'destroyed'
    @off()

  serialize: -> @state.clone()
  getState: -> @state

  # Creates an {EditSession} with the same initial state
  copy: ->
    tabLength = @getTabLength()
    displayBuffer = @displayBuffer.copy()
    softTabs = @getSoftTabs()
    softWrap = @getSoftWrap()
    newEditSession = new EditSession({@buffer, displayBuffer, tabLength, softTabs, softWrap, suppressCursorCreation: true})
    newEditSession.setScrollTop(@getScrollTop())
    newEditSession.setScrollLeft(@getScrollLeft())
    for marker in @findMarkers(editSessionId: @id)
      marker.copy(editSessionId: newEditSession.id, preserveFolds: true)
    newEditSession

  ### Public ###

  # Retrieves the filename of the open file.
  #
  # This is `'untitled'` if the file is new and not saved to the disk.
  #
  # Returns a {String}.
  getTitle: ->
    if sessionPath = @getPath()
      path.basename(sessionPath)
    else
      'untitled'

  # Retrieves the filename of the open file, followed by a dash, then the file's directory.
  #
  # If the file is brand new, the title is `untitled`.
  #
  # Returns a {String}.
  getLongTitle: ->
    if sessionPath = @getPath()
      fileName = path.basename(sessionPath)
      directory = path.basename(path.dirname(sessionPath))
      "#{fileName} - #{directory}"
    else
      'untitled'

  # Compares two `EditSession`s to determine equality.
  #
  # Equality is based on the condition that:
  #
  # * the two {Buffer}s are the same
  # * the two `scrollTop` and `scrollLeft` property are the same
  # * the two {Cursor} screen positions are the same
  #
  # Returns a {Boolean}.
  isEqual: (other) ->
    return false unless other instanceof EditSession
    @buffer == other.buffer and
      @getScrollTop() == other.getScrollTop() and
      @getScrollLeft() == other.getScrollLeft() and
      @getCursorScreenPosition().isEqual(other.getCursorScreenPosition())

  setVisible: (visible) -> @displayBuffer.setVisible(visible)

  # Defines the value of the `EditSession`'s `scrollTop` property.
  #
  # scrollTop - A {Number} defining the `scrollTop`, in pixels.
  setScrollTop: (scrollTop) -> @state.set('scrollTop', scrollTop)

  # Gets the value of the `EditSession`'s `scrollTop` property.
  #
  # Returns a {Number} defining the `scrollTop`, in pixels.
  getScrollTop: ->
    @state.get('scrollTop') ? 0

  # Defines the value of the `EditSession`'s `scrollLeft` property.
  #
  # scrollLeft - A {Number} defining the `scrollLeft`, in pixels.
  setScrollLeft: (scrollLeft) -> @state.set('scrollLeft', scrollLeft)

  # Gets the value of the `EditSession`'s `scrollLeft` property.
  #
  # Returns a {Number} defining the `scrollLeft`, in pixels.
  getScrollLeft: -> @state.get('scrollLeft')

  # Defines the limit at which the buffer begins to soft wrap text.
  #
  # softWrapColumn - A {Number} defining the soft wrap limit
  setSoftWrapColumn: (@softWrapColumn) -> @displayBuffer.setSoftWrapColumn(@softWrapColumn)

  getSoftTabs: ->
    @state.get('softTabs')

  # Defines whether to use soft tabs.
  #
  # softTabs - A {Boolean} which, if `true`, indicates that you want soft tabs.
  setSoftTabs: (softTabs) ->
    @state.set('softTabs', softTabs)

  # Retrieves whether soft tabs are enabled.
  #
  # Returns a {Boolean}.
  getSoftWrap: ->
    @state.get('softWrap')

  # Defines whether to use soft wrapping of text.
  #
  # softTabs - A {Boolean} which, if `true`, indicates that you want soft wraps.
  setSoftWrap: (softWrap) ->
    @state.set('softWrap', softWrap)

  # Retrieves that character used to indicate a tab.
  #
  # If soft tabs are enabled, this is a space (`" "`) times the {.getTabLength} value.
  # Otherwise, it's a tab (`\t`).
  #
  # Returns a {String}.
  getTabText: -> @buildIndentString(1)

  # Retrieves the current tab length.
  #
  # Returns a {Number}.
  getTabLength: -> @displayBuffer.getTabLength()

  # Specifies the tab length.
  #
  # tabLength - A {Number} that defines the new tab length.
  setTabLength: (tabLength) -> @displayBuffer.setTabLength(tabLength)

  # Given a position, this clips it to a real position.
  #
  # For example, if `position`'s row exceeds the row count of the buffer,
  # or if its column goes beyond a line's length, this "sanitizes" the value
  # to a real position.
  #
  # position - The {Point} to clip
  #
  # Returns the new, clipped {Point}. Note that this could be the same as `position` if no clipping was performed.
  clipBufferPosition: (bufferPosition) -> @buffer.clipPosition(bufferPosition)

  # Given a range, this clips it to a real range.
  #
  # For example, if `range`'s row exceeds the row count of the buffer,
  # or if its column goes beyond a line's length, this "sanitizes" the value
  # to a real range.
  #
  # range - The {Point} to clip
  #
  # Returns the new, clipped {Point}. Note that this could be the same as `range` if no clipping was performed.
  clipBufferRange: (range) -> @buffer.clipRange(range)

  # Given a buffer row, this retrieves the indentation level.
  #
  # bufferRow - A {Number} indicating the buffer row.
  #
  # Returns the indentation level as a {Number}.
  indentationForBufferRow: (bufferRow) ->
    @indentLevelForLine(@lineForBufferRow(bufferRow))

  # This specifies the new indentation level for a buffer row.
  #
  # bufferRow - A {Number} indicating the buffer row.
  # newLevel - A {Number} indicating the new indentation level.
  setIndentationForBufferRow: (bufferRow, newLevel) ->
    currentLevel = @indentationForBufferRow(bufferRow)
    currentIndentString = @buildIndentString(currentLevel)
    newIndentString = @buildIndentString(newLevel)
    @buffer.change([[bufferRow, 0], [bufferRow, currentIndentString.length]], newIndentString)

  # Given a line, this retrieves the indentation level.
  #
  # line - A {String} in the current {Buffer}.
  #
  # Returns a {Number}.
  indentLevelForLine: (line) ->
    if match = line.match(/^[\t ]+/)
      leadingWhitespace = match[0]
      tabCount = leadingWhitespace.match(/\t/g)?.length ? 0
      spaceCount = leadingWhitespace.match(/[ ]/g)?.length ? 0
      tabCount + (spaceCount / @getTabLength())
    else
      0

  # Constructs the string used for tabs.
  buildIndentString: (number) ->
    if @getSoftTabs()
      _.multiplyString(" ", number * @getTabLength())
    else
      _.multiplyString("\t", Math.floor(number))

  # {Delegates to: Buffer.save}
  save: -> @buffer.save()

  # {Delegates to: Buffer.saveAs}
  saveAs: (path) -> @buffer.saveAs(path)

  # {Delegates to: Buffer.getExtension}
  getFileExtension: -> @buffer.getExtension()

  # {Delegates to: Buffer.getPath}
  getPath: -> @buffer.getPath()

  # {Delegates to: Buffer.getRelativePath}
  getRelativePath: -> @buffer.getRelativePath()

  # {Delegates to: Buffer.getText}
  getText: -> @buffer.getText()

  # {Delegates to: Buffer.setText}
  setText: (text) -> @buffer.setText(text)

  # Retrieves the current buffer.
  #
  # Returns a {Buffer}.
  getBuffer: -> @buffer

  # Retrieves the current buffer's URI.
  #
  # Returns a {String}.
  getUri: -> @buffer.getUri()

  # {Delegates to: Buffer.isRowBlank}
  isBufferRowBlank: (bufferRow) -> @buffer.isRowBlank(bufferRow)

  # Test if an entire row is a comment
  #
  # Returns a {Boolean}.
  isBufferRowCommented: (bufferRow) ->
    if match = @lineForBufferRow(bufferRow).match(/\S/)
      scopes = @tokenForBufferPosition([bufferRow, match.index]).scopes
      new TextMateScopeSelector('comment.*').matches(scopes)

  # {Delegates to: Buffer.nextNonBlankRow}
  nextNonBlankBufferRow: (bufferRow) -> @buffer.nextNonBlankRow(bufferRow)

  # {Delegates to: Buffer.getEofPosition}
  getEofBufferPosition: -> @buffer.getEofPosition()

  # {Delegates to: Buffer.getLastRow}
  getLastBufferRow: -> @buffer.getLastRow()

  # {Delegates to: Buffer.rangeForRow}
  bufferRangeForBufferRow: (row, options) -> @buffer.rangeForRow(row, options)

  # {Delegates to: Buffer.lineForRow}
  lineForBufferRow: (row) -> @buffer.lineForRow(row)

  # {Delegates to: Buffer.lineLengthForRow}
  lineLengthForBufferRow: (row) -> @buffer.lineLengthForRow(row)

  # {Delegates to: Buffer.scanInRange}
  scanInBufferRange: (args...) -> @buffer.scanInRange(args...)

  # {Delegates to: Buffer.backwardsScanInRange}
  backwardsScanInBufferRange: (args...) -> @buffer.backwardsScanInRange(args...)

  # {Delegates to: Buffer.isModified}
  isModified: -> @buffer.isModified()

  # Identifies if the modified buffer should let you know if it's closing
  # without being saved.
  #
  # Returns a {Boolean}.
  shouldPromptToSave: -> @isModified() and not @buffer.hasMultipleEditors()

  # {Delegates to: DisplayBuffer.screenPositionForBufferPosition}
  screenPositionForBufferPosition: (bufferPosition, options) -> @displayBuffer.screenPositionForBufferPosition(bufferPosition, options)

  # {Delegates to: DisplayBuffer.bufferPositionForScreenPosition}
  bufferPositionForScreenPosition: (screenPosition, options) -> @displayBuffer.bufferPositionForScreenPosition(screenPosition, options)

  # {Delegates to: DisplayBuffer.screenRangeForBufferRange}
  screenRangeForBufferRange: (bufferRange) -> @displayBuffer.screenRangeForBufferRange(bufferRange)

  # {Delegates to: DisplayBuffer.bufferRangeForScreenRange}
  bufferRangeForScreenRange: (screenRange) -> @displayBuffer.bufferRangeForScreenRange(screenRange)

  # {Delegates to: DisplayBuffer.clipScreenPosition}
  clipScreenPosition: (screenPosition, options) -> @displayBuffer.clipScreenPosition(screenPosition, options)

  # {Delegates to: DisplayBuffer.lineForRow}
  lineForScreenRow: (row) -> @displayBuffer.lineForRow(row)

  # {Delegates to: DisplayBuffer.linesForRows}
  linesForScreenRows: (start, end) -> @displayBuffer.linesForRows(start, end)

  # {Delegates to: DisplayBuffer.getLineCount}
  getScreenLineCount: -> @displayBuffer.getLineCount()

  # {Delegates to: DisplayBuffer.getMaxLineLength}
  getMaxScreenLineLength: -> @displayBuffer.getMaxLineLength()

  # {Delegates to: DisplayBuffer.getLastRow}
  getLastScreenRow: -> @displayBuffer.getLastRow()

  # {Delegates to: DisplayBuffer.bufferRowsForScreenRows}
  bufferRowsForScreenRows: (startRow, endRow) -> @displayBuffer.bufferRowsForScreenRows(startRow, endRow)

  # {Delegates to: DisplayBuffer.scopesForBufferPosition}
  scopesForBufferPosition: (bufferPosition) -> @displayBuffer.scopesForBufferPosition(bufferPosition)

  bufferRangeForScopeAtCursor: (selector) ->
    @displayBuffer.bufferRangeForScopeAtPosition(selector, @getCursorBufferPosition())

  # {Delegates to: DisplayBuffer.tokenForBufferPosition}
  tokenForBufferPosition: (bufferPosition) -> @displayBuffer.tokenForBufferPosition(bufferPosition)

  # Retrieves the grammar's token scopes for the line with the most recently added cursor.
  #
  # Returns an {Array} of {String}s.
  getCursorScopes: -> @getCursor().getScopes()

  # Inserts text at the current cursor positions
  #
  # text - A {String} representing the text to insert.
  # options - A set of options equivalent to {Selection.insertText}
  insertText: (text, options={}) ->
    options.autoIndentNewline ?= @shouldAutoIndent()
    options.autoDecreaseIndent ?= @shouldAutoIndent()
    @mutateSelectedText (selection) -> selection.insertText(text, options)

  # Inserts a new line at the current cursor positions.
  insertNewline: ->
    @insertText('\n')

  # Inserts a new line below the current cursor positions.
  insertNewlineBelow: ->
    @transact =>
      @moveCursorToEndOfLine()
      @insertNewline()

  # Inserts a new line above the current cursor positions.
  insertNewlineAbove: ->
    @transact =>
      onFirstLine = @getCursorBufferPosition().row is 0
      @moveCursorToBeginningOfLine()
      @moveCursorLeft()
      @insertNewline()
      @moveCursorUp() if onFirstLine

  # Indents the current line.
  #
  # options - A set of options equivalent to {Selection.indent}.
  indent: (options={})->
    options.autoIndent ?= @shouldAutoIndent()
    @mutateSelectedText (selection) -> selection.indent(options)

  # Performs a backspace, removing the character found behind the cursor position.
  backspace: ->
    @mutateSelectedText (selection) -> selection.backspace()

  # Performs a backspace to the beginning of the current word, removing characters found there.
  backspaceToBeginningOfWord: ->
    @mutateSelectedText (selection) -> selection.backspaceToBeginningOfWord()

  # Performs a backspace to the beginning of the current line, removing characters found there.
  backspaceToBeginningOfLine: ->
    @mutateSelectedText (selection) -> selection.backspaceToBeginningOfLine()

  # Performs a delete, removing the character found ahead of the cursor position.
  delete: ->
    @mutateSelectedText (selection) -> selection.delete()

  # Performs a delete to the end of the current word, removing characters found there.
  deleteToEndOfWord: ->
    @mutateSelectedText (selection) -> selection.deleteToEndOfWord()

  # Deletes the entire line.
  deleteLine: ->
    @mutateSelectedText (selection) -> selection.deleteLine()

  # Indents the selected rows.
  indentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.indentSelectedRows()

  # Outdents the selected rows.
  outdentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.outdentSelectedRows()

  # Wraps the lines within a selection in comments.
  #
  # If the language doesn't have comments, nothing happens.
  #
  # selection - The {Selection} to comment
  #
  # Returns an {Array} of the commented {Ranges}.
  toggleLineCommentsInSelection: ->
    @mutateSelectedText (selection) -> selection.toggleLineComments()

  autoIndentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.autoIndentSelectedRows()

  # Given a buffer range, this converts all `\t` characters to the appropriate {.getTabText} value.
  #
  # bufferRange - The {Range} to perform the replace in
  normalizeTabsInBufferRange: (bufferRange) ->
    return unless @getSoftTabs()
    @scanInBufferRange /\t/, bufferRange, ({replace}) => replace(@getTabText())

  # Performs a cut to the end of the current line.
  #
  # Characters are removed, but the text remains in the clipboard.
  cutToEndOfLine: ->
    maintainPasteboard = false
    @mutateSelectedText (selection) ->
      selection.cutToEndOfLine(maintainPasteboard)
      maintainPasteboard = true

  # Cuts the selected text.
  cutSelectedText: ->
    maintainPasteboard = false
    @mutateSelectedText (selection) ->
      selection.cut(maintainPasteboard)
      maintainPasteboard = true

  # Copies the selected text.
  copySelectedText: ->
    maintainPasteboard = false
    for selection in @getSelections()
      selection.copy(maintainPasteboard)
      maintainPasteboard = true

  # Pastes the text in the clipboard.
  #
  # options - A set of options equivalent to {Selection.insertText}.
  pasteText: (options={}) ->
    [text, metadata] = pasteboard.read()

    if config.get('editor.normalizeIndentOnPaste') and metadata
      options.indentBasis ?= metadata.indentBasis

    @insertText(text, options)

  # Undos the last {Buffer} change.
  undo: ->
    @buffer.undo(this)

  # Redos the last {Buffer} change.
  redo: ->
    @buffer.redo(this)

  # Folds all the rows.
  foldAll: ->
    @languageMode.foldAll()

  # Unfolds all the rows.
  unfoldAll: ->
    @languageMode.unfoldAll()

  foldAllAtIndentLevel: (indentLevel) ->
    @languageMode.foldAllAtIndentLevel(indentLevel)

  # Folds the current row.
  foldCurrentRow: ->
    bufferRow = @bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @foldBufferRow(bufferRow)

  # Given a buffer row, this folds it.
  #
  # bufferRow - A {Number} indicating the buffer row
  foldBufferRow: (bufferRow) ->
    @languageMode.foldBufferRow(bufferRow)

  # Unfolds the current row.
  unfoldCurrentRow: ->
    bufferRow = @bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @unfoldBufferRow(bufferRow)

  # Given a buffer row, this unfolds it.
  #
  # bufferRow - A {Number} indicating the buffer row
  unfoldBufferRow: (bufferRow) ->
    @languageMode.unfoldBufferRow(bufferRow)

  # Folds all selections.
  foldSelection: ->
    selection.fold() for selection in @getSelections()

  # {Delegates to: DisplayBuffer.createFold}
  createFold: (startRow, endRow) ->
    @displayBuffer.createFold(startRow, endRow)

  # {Delegates to: DisplayBuffer.destroyFoldWithId}
  destroyFoldWithId: (id) ->
    @displayBuffer.destroyFoldWithId(id)

  # {Delegates to: DisplayBuffer.destroyFoldsContainingBufferRow}
  destroyFoldsContainingBufferRow: (bufferRow) ->
    @displayBuffer.destroyFoldsContainingBufferRow(bufferRow)

  # Removes any {Fold}s found that intersect the given buffer row.
  #
  # bufferRow - The buffer row {Number} to check against
  destroyFoldsIntersectingBufferRange: (bufferRange) ->
    for row in [bufferRange.start.row..bufferRange.end.row]
      @destroyFoldsContainingBufferRow(row)

  # Determines if the given row that the cursor is at is folded.
  #
  # Returns `true` if the row is folded, `false` otherwise.
  isFoldedAtCursorRow: ->
    @isFoldedAtScreenRow(@getCursorScreenRow())

  # Determines if the given buffer row is folded.
  #
  # bufferRow - A {Number} indicating the buffer row.
  #
  # Returns `true` if the buffer row is folded, `false` otherwise.
  isFoldedAtBufferRow: (bufferRow) ->
    @displayBuffer.isFoldedAtBufferRow(bufferRow)

  # Determines if the given screen row is folded.
  #
  # screenRow - A {Number} indicating the screen row.
  #
  # Returns `true` if the screen row is folded, `false` otherwise.
  isFoldedAtScreenRow: (screenRow) ->
    @displayBuffer.isFoldedAtScreenRow(screenRow)

  # {Delegates to: DisplayBuffer.largestFoldContainingBufferRow}
  largestFoldContainingBufferRow: (bufferRow) ->
    @displayBuffer.largestFoldContainingBufferRow(bufferRow)

  # {Delegates to: DisplayBuffer.largestFoldStartingAtScreenRow}
  largestFoldStartingAtScreenRow: (screenRow) ->
    @displayBuffer.largestFoldStartingAtScreenRow(screenRow)

  # Given a buffer row, this returns a suggested indentation level.
  #
  # The indentation level provided is based on the current language.
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns a {Number}.
  suggestedIndentForBufferRow: (bufferRow) ->
    @languageMode.suggestedIndentForBufferRow(bufferRow)

  # Indents all the rows between two buffer rows.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  autoIndentBufferRows: (startRow, endRow) ->
    @languageMode.autoIndentBufferRows(startRow, endRow)

  # Given a buffer row, this indents it.
  #
  # bufferRow - The row {Number}
  autoIndentBufferRow: (bufferRow) ->
    @languageMode.autoIndentBufferRow(bufferRow)

  # Given a buffer row, this decreases the indentation.
  #
  # bufferRow - The row {Number}
  autoDecreaseIndentForBufferRow: (bufferRow) ->
    @languageMode.autoDecreaseIndentForBufferRow(bufferRow)

  # Wraps the lines between two rows in comments.
  #
  # If the language doesn't have comments, nothing happens.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  #
  # Returns an {Array} of the commented {Ranges}.
  toggleLineCommentsForBufferRows: (start, end) ->
    @languageMode.toggleLineCommentsForBufferRows(start, end)

  # Moves the selected line up one row.
  moveLineUp: ->
    selection = @getSelectedBufferRange()
    return if selection.start.row is 0
    lastRow = @buffer.getLastRow()
    return if selection.isEmpty() and selection.start.row is lastRow and @buffer.getLastLine() is ''

    @transact =>
      foldedRows = []
      rows = [selection.start.row..selection.end.row]
      if selection.start.row isnt selection.end.row and selection.end.column is 0
        rows.pop() unless @isFoldedAtBufferRow(selection.end.row)
      for row in rows
        screenRow = @screenPositionForBufferPosition([row]).row
        if @isFoldedAtScreenRow(screenRow)
          bufferRange = @bufferRangeForScreenRange([[screenRow], [screenRow + 1]])
          startRow = bufferRange.start.row
          endRow = bufferRange.end.row - 1
          foldedRows.push(endRow - 1)
        else
          startRow = row
          endRow = row

        endPosition = Point.min([endRow + 1], @buffer.getEofPosition())
        lines = @buffer.getTextInRange([[startRow], endPosition])
        if endPosition.row is lastRow and endPosition.column > 0 and not @buffer.lineEndingForRow(endPosition.row)
          lines = "#{lines}\n"
        @buffer.deleteRows(startRow, endRow)
        @buffer.insert([startRow - 1], lines)

      @foldBufferRow(foldedRow) for foldedRow in foldedRows

      @setSelectedBufferRange(selection.translate([-1]), preserveFolds: true)

  # Moves the selected line down one row.
  moveLineDown: ->
    selection = @getSelectedBufferRange()
    lastRow = @buffer.getLastRow()
    return if selection.end.row is lastRow
    return if selection.end.row is lastRow - 1 and @buffer.getLastLine() is ''

    @transact =>
      foldedRows = []
      rows = [selection.end.row..selection.start.row]
      if selection.start.row isnt selection.end.row and selection.end.column is 0
        rows.shift() unless @isFoldedAtBufferRow(selection.end.row)
      for row in rows
        screenRow = @screenPositionForBufferPosition([row]).row
        if @isFoldedAtScreenRow(screenRow)
          bufferRange = @bufferRangeForScreenRange([[screenRow], [screenRow + 1]])
          startRow = bufferRange.start.row
          endRow = bufferRange.end.row - 1
          foldedRows.push(endRow + 1)
        else
          startRow = row
          endRow = row

        if endRow + 1 is lastRow
          endPosition = [endRow, @buffer.lineLengthForRow(endRow)]
        else
          endPosition = [endRow + 1]
        lines = @buffer.getTextInRange([[startRow], endPosition])
        @buffer.deleteRows(startRow, endRow)
        insertPosition = Point.min([startRow + 1], @buffer.getEofPosition())
        if insertPosition.row is @buffer.getLastRow() and insertPosition.column > 0
          lines = "\n#{lines}"
        @buffer.insert(insertPosition, lines)

      @foldBufferRow(foldedRow) for foldedRow in foldedRows

      @setSelectedBufferRange(selection.translate([1]), preserveFolds: true)

  # Duplicates the current line.
  #
  # If more than one cursor is present, only the most recently added one is considered.
  duplicateLine: ->
    return unless @getSelection().isEmpty()

    @transact =>
      cursorPosition = @getCursorBufferPosition()
      cursorRowFolded = @isFoldedAtCursorRow()
      if cursorRowFolded
        screenRow = @screenPositionForBufferPosition(cursorPosition).row
        bufferRange = @bufferRangeForScreenRange([[screenRow], [screenRow + 1]])
      else
        bufferRange = new Range([cursorPosition.row], [cursorPosition.row + 1])

      insertPosition = new Point(bufferRange.end.row)
      if insertPosition.row > @buffer.getLastRow()
        @unfoldCurrentRow() if cursorRowFolded
        @buffer.append("\n#{@getTextInBufferRange(bufferRange)}")
        @foldCurrentRow() if cursorRowFolded
      else
        @buffer.insert(insertPosition, @getTextInBufferRange(bufferRange))

      @setCursorScreenPosition(@getCursorScreenPosition().translate([1]))
      @foldCurrentRow() if cursorRowFolded

  ### Internal ###

  mutateSelectedText: (fn) ->
    @transact => fn(selection) for selection in @getSelections()

  replaceSelectedText: (options={}, fn) ->
    {selectWordIfEmpty} = options
    @mutateSelectedText (selection) ->
      range = selection.getBufferRange()
      if selectWordIfEmpty and selection.isEmpty()
        selection.selectWord()
      text = selection.getText()
      selection.deleteSelectedText()
      selection.insertText(fn(text))
      selection.setBufferRange(range)

  ### Public ###

  # Returns a valid {DisplayBufferMarker} object for the given id if one exists.
  getMarker: (id) ->
    @displayBuffer.getMarker(id)

  getMarkers: ->
    @displayBuffer.getMarkers()

  findMarkers: (attributes) ->
    @displayBuffer.findMarkers(attributes)

  # {Delegates to: DisplayBuffer.markScreenRange}
  markScreenRange: (args...) ->
    @displayBuffer.markScreenRange(args...)

  # {Delegates to: DisplayBuffer.markBufferRange}
  markBufferRange: (args...) ->
    @displayBuffer.markBufferRange(args...)

  # {Delegates to: DisplayBuffer.markScreenPosition}
  markScreenPosition: (args...) ->
    @displayBuffer.markScreenPosition(args...)

  # {Delegates to: DisplayBuffer.markBufferPosition}
  markBufferPosition: (args...) ->
    @displayBuffer.markBufferPosition(args...)

  # {Delegates to: DisplayBuffer.destroyMarker}
  destroyMarker: (args...) ->
    @displayBuffer.destroyMarker(args...)

  # {Delegates to: Buffer.getMarkerCount}
  getMarkerCount: ->
    @buffer.getMarkerCount()

  # Returns `true` if there are multiple cursors in the edit session.
  #
  # Returns a {Boolean}.
  hasMultipleCursors: ->
    @getCursors().length > 1

  getAllCursors: ->
    @getCursors().concat(@getRemoteCursors())

  # Retrieves all the cursors.
  #
  # Returns an {Array} of {Cursor}s.
  getCursors: -> new Array(@cursors...)

  # Retrieves the most recently added cursor.
  #
  # Returns a {Cursor}.
  getCursor: ->
    _.last(@cursors)

  getRemoteCursors: -> new Array(@remoteCursors...)

  # Adds a cursor at the provided `screenPosition`.
  #
  # screenPosition - An {Array} of two numbers: the screen row, and the screen column.
  #
  # Returns the new {Cursor}.
  addCursorAtScreenPosition: (screenPosition) ->
    @markScreenPosition(screenPosition, @getSelectionMarkerAttributes())
    @getLastSelection().cursor

  # Adds a cursor at the provided `bufferPosition`.
  #
  # bufferPosition - An {Array} of two numbers: the buffer row, and the buffer column.
  #
  # Returns the new {Cursor}.
  addCursorAtBufferPosition: (bufferPosition) ->
    @markBufferPosition(bufferPosition, @getSelectionMarkerAttributes())
    @getLastSelection().cursor

  # Adds a cursor to the `EditSession`.
  #
  # marker - The marker where the cursor should be added
  #
  # Returns the new {Cursor}.
  addCursor: (marker) ->
    cursor = new Cursor(editSession: this, marker: marker)
    if marker.isLocal()
      @cursors.push(cursor)
    else
      @remoteCursors.push(cursor)
    @trigger 'cursor-added', cursor
    cursor

  # Removes a cursor from the `EditSession`.
  #
  # cursor - The cursor to remove
  #
  # Returns the removed {Cursor}.
  removeCursor: (cursor) ->
    _.remove(@cursors, cursor)

  # Creates a new selection at the given marker.
  #
  # marker - The marker to highlight
  # options - A hash of options that pertain to the {Selection} constructor.
  #
  # Returns the new {Selection}.
  addSelection: (marker, options={}) ->
    unless marker.getAttributes().preserveFolds
      @destroyFoldsIntersectingBufferRange(marker.getBufferRange())
    cursor = @addCursor(marker)
    selection = new Selection(_.extend({editSession: this, marker, cursor}, options))

    if marker.isLocal()
      @selections.push(selection)
    else
      @remoteSelections.push(selection)

    selectionBufferRange = selection.getBufferRange()
    @mergeIntersectingSelections()
    if selection.destroyed
      for selection in @getSelections()
        if selection.intersectsBufferRange(selectionBufferRange)
          return selection
    else
      @trigger 'selection-added', selection
      selection

  # Given a buffer range, this adds a new selection for it.
  #
  # bufferRange - A {Range} in the buffer
  # options - A hash of options
  #
  # Returns the new {Selection}.
  addSelectionForBufferRange: (bufferRange, options={}) ->
    @markBufferRange(bufferRange, _.defaults(@getSelectionMarkerAttributes(), options))
    @getLastSelection()

  # Given a buffer range, this removes all previous selections and creates a new selection for it.
  #
  # bufferRange - A {Range} in the buffer
  # options - A hash of options
  setSelectedBufferRange: (bufferRange, options) ->
    @setSelectedBufferRanges([bufferRange], options)

  # Given an array of buffer ranges, this removes all previous selections and creates new selections for them.
  #
  # bufferRanges - An {Array} of {Range}s in the buffer
  # options - A hash of options
  setSelectedBufferRanges: (bufferRanges, options={}) ->
    throw new Error("Passed an empty array to setSelectedBufferRanges") unless bufferRanges.length

    selections = @getSelections()
    selection.destroy() for selection in selections[bufferRanges.length...]

    @mergeIntersectingSelections options, =>
      for bufferRange, i in bufferRanges
        bufferRange = Range.fromObject(bufferRange)
        if selections[i]
          selections[i].setBufferRange(bufferRange, options)
        else
          @addSelectionForBufferRange(bufferRange, options)

  # Unselects a given selection.
  #
  # selection - The {Selection} to remove.
  removeSelection: (selection) ->
    if selection.isLocal()
      _.remove(@selections, selection)
    else
      _.remove(@remoteSelections, selection)

  # Clears every selection. TODO
  clearSelections: ->
    @consolidateSelections()
    @getSelection().clear()

  consolidateSelections: ->
    selections = @getSelections()
    if selections.length > 1
      selection.destroy() for selection in selections[0...-1]
      true
    else
      false

  getAllSelections: ->
    @getSelections().concat(@getRemoteSelections())

  # Gets all the selections.
  #
  # Returns an {Array} of {Selection}s.
  getSelections: -> new Array(@selections...)

  # Gets the selection at the specified index.
  #
  # index - The id {Number} of the selection
  #
  # Returns a {Selection}.
  getSelection: (index) ->
    index ?= @selections.length - 1
    @selections[index]

  # Gets the last selection, _i.e._ the most recently added.
  #
  # Returns a {Selection}.
  getLastSelection: ->
    _.last(@selections)

  getRemoteSelections: -> new Array(@remoteSelections...)

  # Gets all selections, ordered by their position in the buffer.
  #
  # Returns an {Array} of {Selection}s.
  getSelectionsOrderedByBufferPosition: ->
    @getSelections().sort (a, b) -> a.compare(b)

  getRemoteSelectionsOrderedByBufferPosition: ->
    @getRemoteSelections().sort (a, b) -> a.compare(b)

  # Gets the very last selection, as it's ordered in the buffer.
  #
  # Returns a {Selection}.
  getLastSelectionInBuffer: ->
    _.last(@getSelectionsOrderedByBufferPosition())

  # Determines if a given buffer range is included in a {Selection}.
  #
  # bufferRange - The {Range} you're checking against
  #
  # Returns a {Boolean}.
  selectionIntersectsBufferRange: (bufferRange) ->
    _.any @getSelections(), (selection) ->
      selection.intersectsBufferRange(bufferRange)

  # Moves every cursor to a given screen position.
  #
  # position - An {Array} of two numbers: the screen row, and the screen column.
  # options - An object with properties based on {Cursor.setScreenPosition}
  #
  setCursorScreenPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setScreenPosition(position, options)

  # Gets the current screen position of the most recently added {Cursor}.
  #
  # Returns an {Array} of two numbers: the screen row, and the screen column.
  getCursorScreenPosition: ->
    @getCursor().getScreenPosition()

  # Gets the screen row of the most recently added {Cursor}.
  #
  # Returns the screen row {Number}.
  getCursorScreenRow: ->
    @getCursor().getScreenRow()

  # Moves every cursor to a given buffer position.
  #
  # position - An {Array} of two numbers: the buffer row, and the buffer column.
  # options - An object with properties based on {Cursor.setBufferPosition}
  #
  setCursorBufferPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setBufferPosition(position, options)

  # Gets the current buffer position of the most recently added {Cursor}.
  #
  # Returns an {Array} of two numbers: the buffer row, and the buffer column.
  getCursorBufferPosition: ->
    @getCursor().getBufferPosition()

  # Gets the screen range of the most recently added {Selection}.
  #
  # Returns a {Range}.
  getSelectedScreenRange: ->
    @getLastSelection().getScreenRange()

  # Gets the buffer range of the most recently added {Selection}.
  #
  # Returns a {Range}.
  getSelectedBufferRange: ->
    @getLastSelection().getBufferRange()

  # Gets the buffer ranges of all the {Selection}s.
  #
  # This is ordered by their position in the file itself.
  #
  # Returns an {Array} of {Range}s.
  getSelectedBufferRanges: ->
    selection.getBufferRange() for selection in @getSelectionsOrderedByBufferPosition()

  getRemoteSelectedBufferRanges: ->
    selection.getBufferRange() for selection in @getRemoteSelectionsOrderedByBufferPosition()

  # Gets the selected text of the most recently added {Selection}.
  #
  # Returns a {String}.
  getSelectedText: ->
    @getLastSelection().getText()

  # Given a buffer range, this retrieves the text in that range.
  #
  # range - The {Range} you're interested in
  #
  # Returns a {String} of the combined lines.
  getTextInBufferRange: (range) ->
    @buffer.getTextInRange(range)

  setTextInBufferRange: (range, text) -> @getBuffer().change(range, text)

  # Retrieves the range for the current paragraph.
  #
  # A paragraph is defined as a block of text surrounded by empty lines.
  #
  # Returns a {Range}.
  getCurrentParagraphBufferRange: ->
    @getCursor().getCurrentParagraphBufferRange()

  # Gets the word located under the most recently added {Cursor}.
  #
  # options - An object with properties based on {Cursor.getBeginningOfCurrentWordBufferPosition}.
  #
  # Returns a {String}.
  getWordUnderCursor: (options) ->
    @getTextInBufferRange(@getCursor().getCurrentWordBufferRange(options))

  # Moves every cursor up one row.
  moveCursorUp: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveUp(lineCount, moveToEndOfSelection: true)

  # Moves every cursor down one row.
  moveCursorDown: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveDown(lineCount, moveToEndOfSelection: true)

  # Moves every cursor left one column.
  moveCursorLeft: ->
    @moveCursors (cursor) -> cursor.moveLeft(moveToEndOfSelection: true)

  # Moves every cursor right one column.
  moveCursorRight: ->
    @moveCursors (cursor) -> cursor.moveRight(moveToEndOfSelection: true)

  # Moves every cursor to the top of the buffer.
  moveCursorToTop: ->
    @moveCursors (cursor) -> cursor.moveToTop()

  # Moves every cursor to the bottom of the buffer.
  moveCursorToBottom: ->
    @moveCursors (cursor) -> cursor.moveToBottom()

  # Moves every cursor to the beginning of the line.
  moveCursorToBeginningOfLine: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfLine()

  # Moves every cursor to the first non-whitespace character of the line.
  moveCursorToFirstCharacterOfLine: ->
    @moveCursors (cursor) -> cursor.moveToFirstCharacterOfLine()

  # Moves every cursor to the end of the line.
  moveCursorToEndOfLine: ->
    @moveCursors (cursor) -> cursor.moveToEndOfLine()

  # Moves every cursor to the beginning of the current word.
  moveCursorToBeginningOfWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfWord()

  # Moves every cursor to the end of the current word.
  moveCursorToEndOfWord: ->
    @moveCursors (cursor) -> cursor.moveToEndOfWord()

  # Moves every cursor to the beginning of the next word.
  moveCursorToBeginningOfNextWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfNextWord()

  moveCursorToPreviousWordBoundary: ->
    @moveCursors (cursor) -> cursor.moveToPreviousWordBoundary()

  moveCursorToNextWordBoundary: ->
    @moveCursors (cursor) -> cursor.moveToNextWordBoundary()

  # Internal:
  moveCursors: (fn) ->
    fn(cursor) for cursor in @getCursors()
    @mergeCursors()

  # Selects the text from the current cursor position to a given screen position.
  #
  # position - An instance of {Point}, with a given `row` and `column`.
  selectToScreenPosition: (position) ->
    lastSelection = @getLastSelection()
    lastSelection.selectToScreenPosition(position)
    @mergeIntersectingSelections(isReversed: lastSelection.isReversed())

  # Selects the text one position right of the cursor.
  selectRight: ->
    @expandSelectionsForward (selection) => selection.selectRight()

  # Selects the text one position left of the cursor.
  selectLeft: ->
    @expandSelectionsBackward (selection) => selection.selectLeft()

  # Selects all the text one position above the cursor.
  selectUp: ->
    @expandSelectionsBackward (selection) => selection.selectUp()

  # Selects all the text one position below the cursor.
  selectDown: ->
    @expandSelectionsForward (selection) => selection.selectDown()

  # Selects all the text from the current cursor position to the top of the buffer.
  selectToTop: ->
    @expandSelectionsBackward (selection) => selection.selectToTop()

  # Selects all the text in the buffer.
  selectAll: ->
    @expandSelectionsForward (selection) => selection.selectAll()

  # Selects all the text from the current cursor position to the bottom of the buffer.
  selectToBottom: ->
    @expandSelectionsForward (selection) => selection.selectToBottom()

  # Selects all the text from the current cursor position to the beginning of the line.
  selectToBeginningOfLine: ->
    @expandSelectionsBackward (selection) => selection.selectToBeginningOfLine()

  # Selects to the first non-whitespace character of the line.
  selectToFirstCharacterOfLine: ->
    @expandSelectionsBackward (selection) => selection.selectToFirstCharacterOfLine()

  # Selects all the text from the current cursor position to the end of the line.
  selectToEndOfLine: ->
    @expandSelectionsForward (selection) => selection.selectToEndOfLine()

  selectToPreviousWordBoundary: ->
    @expandSelectionsBackward (selection) => selection.selectToPreviousWordBoundary()

  selectToNextWordBoundary: ->
    @expandSelectionsForward (selection) => selection.selectToNextWordBoundary()

  # Selects the current line.
  selectLine: ->
    @expandSelectionsForward (selection) => selection.selectLine()

  # Moves the current selection down one row.
  addSelectionBelow: ->
    @expandSelectionsForward (selection) => selection.addSelectionBelow()

  # Moves the current selection up one row.
  addSelectionAbove: ->
    @expandSelectionsBackward (selection) => selection.addSelectionAbove()

  # Transposes the current text selections.
  #
  # This only works if there is more than one selection. Each selection is transferred
  # to the position of the selection after it. The last selection is transferred to the
  # position of the first.
  transpose: ->
    @mutateSelectedText (selection) =>
      if selection.isEmpty()
        selection.selectRight()
        text = selection.getText()
        selection.delete()
        selection.cursor.moveLeft()
        selection.insertText text
      else
        selection.insertText selection.getText().split('').reverse().join('')

  # Turns the current selection into upper case.
  upperCase: ->
    @replaceSelectedText selectWordIfEmpty:true, (text) => text.toUpperCase()

  # Turns the current selection into lower case.
  lowerCase: ->
    @replaceSelectedText selectWordIfEmpty:true, (text) => text.toLowerCase()

  # Joins the current line with the one below it.
  #
  # Multiple cursors are considered equally. If there's a selection in the editor,
  # all the lines are joined together.
  joinLine: ->
    @mutateSelectedText (selection) -> selection.joinLine()

  expandLastSelectionOverLine: ->
    @getLastSelection().expandOverLine()

  # Selects all the text from the current cursor position to the beginning of the word.
  selectToBeginningOfWord: ->
    @expandSelectionsBackward (selection) => selection.selectToBeginningOfWord()

  # Selects all the text from the current cursor position to the end of the word.
  selectToEndOfWord: ->
    @expandSelectionsForward (selection) => selection.selectToEndOfWord()

  # Selects all the text from the current cursor position to the beginning of the next word.
  selectToBeginningOfNextWord: ->
    @expandSelectionsForward (selection) => selection.selectToBeginningOfNextWord()

  # Selects the current word.
  selectWord: ->
    @expandSelectionsForward (selection) => selection.selectWord()

  expandLastSelectionOverWord: ->
    @getLastSelection().expandOverWord()

  # Selects the range associated with the given marker if it is valid.
  #
  # Returns the selected {Range} or a falsy value if the marker is invalid.
  selectMarker: (marker) ->
    if marker.isValid()
      range = marker.getBufferRange()
      @setSelectedBufferRange(range)
      range

  mergeCursors: ->
    positions = []
    for cursor in @getCursors()
      position = cursor.getBufferPosition().toString()
      if position in positions
        cursor.destroy()
      else
        positions.push(position)

  expandSelectionsForward: (fn) ->
    @mergeIntersectingSelections =>
      fn(selection) for selection in @getSelections()

  expandSelectionsBackward: (fn) ->
    @mergeIntersectingSelections isReversed: true, =>
      fn(selection) for selection in @getSelections()

  finalizeSelections: ->
    selection.finalize() for selection in @getSelections()

  # Merges intersecting selections. If passed a function, it executes the function
  # with merging suppressed, then merges intersecting selections afterward.
  mergeIntersectingSelections: (args...) ->
    fn = args.pop() if _.isFunction(_.last(args))
    options = args.pop() ? {}

    return fn?() if @suppressSelectionMerging

    if fn?
      @suppressSelectionMerging = true
      result = fn()
      @suppressSelectionMerging = false

    reducer = (disjointSelections, selection) ->
      intersectingSelection = _.find(disjointSelections, (s) -> s.intersectsWith(selection))
      if intersectingSelection?
        intersectingSelection.merge(selection, options)
        disjointSelections
      else
        disjointSelections.concat([selection])

    _.reduce(@getSelections(), reducer, [])

  preserveCursorPositionOnBufferReload: ->
    cursorPosition = null
    @subscribe @buffer, "will-reload", =>
      cursorPosition = @getCursorBufferPosition()
    @subscribe @buffer, "reloaded", =>
      @setCursorBufferPosition(cursorPosition) if cursorPosition
      cursorPosition = null

  # {Delegates to: DisplayBuffer.getGrammar}
  getGrammar: ->
    @displayBuffer.getGrammar()

  # {Delegates to: DisplayBuffer.setGrammar}
  setGrammar: (grammar) ->
    @displayBuffer.setGrammar(grammar)

  # {Delegates to: DisplayBuffer.reloadGrammar}
  reloadGrammar: ->
    @displayBuffer.reloadGrammar()

  ### Internal ###

  shouldAutoIndent: ->
    config.get("editor.autoIndent")

  transact: (fn) -> @buffer.transact(fn)

  beginTransaction: -> @buffer.beginTransaction()

  commitTransaction: -> @buffer.commitTransaction()

  abortTransaction: -> @buffer.abortTransaction()

  inspect: ->
    JSON.stringify @state.toObject()

  logScreenLines: (start, end) -> @displayBuffer.logLines(start, end)

  handleGrammarChange: ->
    @unfoldAll()
    @trigger 'grammar-changed'

  handleMarkerCreated: (marker) =>
    if marker.matchesAttributes(@getSelectionMarkerAttributes())
      @addSelection(marker)

  getSelectionMarkerAttributes: ->
    type: 'selection', editSessionId: @id, invalidation: 'never'

  getDebugSnapshot: ->
    [
      @displayBuffer.getDebugSnapshot()
      @displayBuffer.tokenizedBuffer.getDebugSnapshot()
    ].join('\n\n')

_.extend(EditSession.prototype, EventEmitter)
_.extend(EditSession.prototype, Subscriber)
