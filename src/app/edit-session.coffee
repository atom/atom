Point = require 'point'
Buffer = require 'text-buffer'
LanguageMode = require 'language-mode'
DisplayBuffer = require 'display-buffer'
Cursor = require 'cursor'
Selection = require 'selection'
EventEmitter = require 'event-emitter'
Subscriber = require 'subscriber'
Range = require 'range'
_ = require 'underscore'
fsUtils = require 'fs-utils'

# Public: An `EditSession` manages the states between {Editor}s, {Buffer}s, and the project as a whole.
module.exports =
class EditSession
  registerDeserializer(this)

  ###
  # Internal #
  ###

  @version: 1

  @deserialize: (state) ->
    session = project.buildEditSessionForBuffer(Buffer.deserialize(state.buffer))
    if !session?
      console.warn "Could not build edit session for path '#{state.buffer}' because that file no longer exists" if state.buffer
      session = project.buildEditSession(null)
    session.setScrollTop(state.scrollTop)
    session.setScrollLeft(state.scrollLeft)
    session.setCursorScreenPosition(state.cursorScreenPosition)
    session

  scrollTop: 0
  scrollLeft: 0
  languageMode: null
  displayBuffer: null
  cursors: null
  selections: null
  softTabs: true
  softWrap: false

  constructor: ({@project, @buffer, tabLength, softTabs, @softWrap }) ->
    @softTabs = @buffer.usesSoftTabs() ? softTabs ? true
    @languageMode = new LanguageMode(this, @buffer.getExtension())
    @displayBuffer = new DisplayBuffer(@buffer, { @languageMode, tabLength })
    @cursors = []
    @selections = []
    @addCursorAtScreenPosition([0, 0])

    @buffer.retain()
    @subscribe @buffer, "path-changed", =>
      @project.setPath(fsUtils.directory(@getPath())) unless @project.getPath()?
      @trigger "title-changed"
      @trigger "path-changed"
    @subscribe @buffer, "contents-conflicted", => @trigger "contents-conflicted"
    @subscribe @buffer, "markers-updated", => @mergeCursors()
    @subscribe @buffer, "modified-status-changed", => @trigger "modified-status-changed"

    @preserveCursorPositionOnBufferReload()

    @subscribe @displayBuffer, "changed", (e) =>
      @trigger 'screen-lines-changed', e

    @displayBuffer.on 'grammar-changed', => @handleGrammarChange()

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
    @project?.removeEditSession(this)
    @trigger 'destroyed'
    @off()

  serialize: ->
    deserializer: 'EditSession'
    version: @constructor.version
    buffer: @buffer.serialize()
    scrollTop: @getScrollTop()
    scrollLeft: @getScrollLeft()
    cursorScreenPosition: @getCursorScreenPosition().serialize()

  # Internal: Creates a copy of the current {EditSession}.
  #
  # Returns an identical `EditSession`.
  copy: ->
    EditSession.deserialize(@serialize(), @project)

  ###
  # Public #
  ###

  # Public: Retrieves the filename of the open file.
  #
  # This is `'untitled'` if the file is new and not saved to the disk.
  #
  # Returns a {String}.
  getTitle: ->
    if path = @getPath()
      fsUtils.base(path)
    else
      'untitled'

  # Public: Retrieves the filename of the open file, followed by a dash, then the file's directory.
  #
  # If the file is brand new, the title is `untitled`.
  #
  # Returns a {String}.
  getLongTitle: ->
    if path = @getPath()
      fileName = fsUtils.base(path)
      directory = fsUtils.base(fsUtils.directory(path))
      "#{fileName} - #{directory}"
    else
      'untitled'

  # Public: Compares two `EditSession`s to determine equality.
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
      @scrollTop == other.getScrollTop() and
      @scrollLeft == other.getScrollLeft() and
      @getCursorScreenPosition().isEqual(other.getCursorScreenPosition())


  setVisible: (visible) -> @displayBuffer.setVisible(visible)

  # Public: Defines the value of the `EditSession`'s `scrollTop` property.
  #
  # scrollTop - A {Number} defining the `scrollTop`, in pixels.
  setScrollTop: (@scrollTop) ->
  # Public: Gets the value of the `EditSession`'s `scrollTop` property.
  #
  # Returns a {Number} defining the `scrollTop`, in pixels.
  getScrollTop: -> @scrollTop

  # Public: Defines the value of the `EditSession`'s `scrollLeft` property.
  #
  # scrollLeft - A {Number} defining the `scrollLeft`, in pixels.
  setScrollLeft: (@scrollLeft) ->
  # Public: Gets the value of the `EditSession`'s `scrollLeft` property.
  #
  # Returns a {Number} defining the `scrollLeft`, in pixels.
  getScrollLeft: -> @scrollLeft

  # Public: Defines the limit at which the buffer begins to soft wrap text.
  #
  # softWrapColumn - A {Number} defining the soft wrap limit
  setSoftWrapColumn: (@softWrapColumn) -> @displayBuffer.setSoftWrapColumn(@softWrapColumn)

  # Public: Defines whether to use soft tabs.
  #
  # softTabs - A {Boolean} which, if `true`, indicates that you want soft tabs.
  setSoftTabs: (@softTabs) ->

  # Public: Retrieves whether soft tabs are enabled.
  #
  # Returns a {Boolean}.
  getSoftWrap: -> @softWrap

  # Public: Defines whether to use soft wrapping of text.
  #
  # softTabs - A {Boolean} which, if `true`, indicates that you want soft wraps.
  setSoftWrap: (@softWrap) ->

  # Public: Retrieves that character used to indicate a tab.
  #
  # If soft tabs are enabled, this is a space (`" "`) times the {.getTabLength} value.
  # Otherwise, it's a tab (`\t`).
  #
  # Returns a {String}.
  getTabText: -> @buildIndentString(1)

  # Public: Retrieves the current tab length.
  #
  # Returns a {Number}.
  getTabLength: -> @displayBuffer.getTabLength()

  # Public: Specifies the tab length.
  #
  # tabLength - A {Number} that defines the new tab length.
  setTabLength: (tabLength) -> @displayBuffer.setTabLength(tabLength)

  # Public: Given a position, this clips it to a real position.
  #
  # For example, if `position`'s row exceeds the row count of the buffer,
  # or if its column goes beyond a line's length, this "sanitizes" the value
  # to a real position.
  #
  # position - The {Point} to clip
  #
  # Returns the new, clipped {Point}. Note that this could be the same as `position` if no clipping was performed.
  clipBufferPosition: (bufferPosition) -> @buffer.clipPosition(bufferPosition)

  # Public: Given a range, this clips it to a real range.
  #
  # For example, if `range`'s row exceeds the row count of the buffer,
  # or if its column goes beyond a line's length, this "sanitizes" the value
  # to a real range.
  #
  # range - The {Point} to clip
  #
  # Returns the new, clipped {Point}. Note that this could be the same as `range` if no clipping was performed.
  clipBufferRange: (range) -> @buffer.clipRange(range)

  # Public: Given a buffer row, this retrieves the indentation level.
  #
  # bufferRow - A {Number} indicating the buffer row.
  #
  # Returns the indentation level as a {Number}.
  indentationForBufferRow: (bufferRow) ->
    @indentLevelForLine(@lineForBufferRow(bufferRow))

  # Public: This specifies the new indentation level for a buffer row.
  #
  # bufferRow - A {Number} indicating the buffer row.
  # newLevel - A {Number} indicating the new indentation level.
  setIndentationForBufferRow: (bufferRow, newLevel) ->
    currentLevel = @indentationForBufferRow(bufferRow)
    currentIndentString = @buildIndentString(currentLevel)
    newIndentString = @buildIndentString(newLevel)
    @buffer.change([[bufferRow, 0], [bufferRow, currentIndentString.length]], newIndentString)

  # Internal: Given a line, this gets the indentation level.
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

  # Internal: Constructs the string used for tabs.
  buildIndentString: (number) ->
    if @softTabs
      _.multiplyString(" ", number * @getTabLength())
    else
      _.multiplyString("\t", Math.floor(number))

  # Public: Saves the buffer.
  save: -> @buffer.save()

  # Public: Saves the buffer at a specific path.
  #
  # path - The path to save at.
  saveAs: (path) -> @buffer.saveAs(path)

  # Public: Retrieves the current buffer's file extension.
  #
  # Returns a {String}.
  getFileExtension: -> @buffer.getExtension()

  # Public: Retrieves the current buffer's file path.
  #
  # Returns a {String}.
  getPath: -> @buffer.getPath()

  # Public: Retrieves the current buffer's text.
  #
  # Return a {String}.
  getText: -> @buffer.getText()

  # Public: Set the current buffer's text content.
  #
  # Return a {String}.
  setText: (text) -> @buffer.setText(text)

  # Public: Retrieves the current buffer.
  #
  # Returns a {String}.
  getBuffer: -> @buffer

  # Public: Retrieves the current buffer's URI.
  #
  # Returns a {String}.
  getUri: -> @getPath()

  # Public: Given a buffer row, identifies if it is blank.
  #
  # bufferRow - A buffer row {Number} to check
  #
  # Returns a {Boolean}.
  isBufferRowBlank: (bufferRow) -> @buffer.isRowBlank(bufferRow)

  # Public: Given a buffer row, this finds the next row that's blank.
  #
  # bufferRow - A buffer row {Number} to check
  #
  # Returns a {Number}, or `null` if there's no other blank row.
  nextNonBlankBufferRow: (bufferRow) -> @buffer.nextNonBlankRow(bufferRow)

  # Public: Finds the last point in the current buffer.
  #
  # Returns a {Point} representing the last position.
  getEofBufferPosition: -> @buffer.getEofPosition()

  # Public: Finds the last line in the current buffer.
  #
  # Returns a {Number}.
  getLastBufferRow: -> @buffer.getLastRow()

  # Public: Given a buffer row, this retrieves the range for that line.
  #
  # row - A {Number} identifying the row
  # options - A hash with one key, `includeNewline`, which specifies whether you
  #           want to include the trailing newline
  #
  # Returns a {Range}.
  bufferRangeForBufferRow: (row, options) -> @buffer.rangeForRow(row, options)

  # Public: Given a buffer row, this retrieves that line.
  #
  # row - A {Number} identifying the row
  #
  # Returns a {String}.
  lineForBufferRow: (row) -> @buffer.lineForRow(row)

  # Public: Given a buffer row, this retrieves that line's length.
  #
  # row - A {Number} identifying the row
  #
  # Returns a {Number}.
  lineLengthForBufferRow: (row) -> @buffer.lineLengthForRow(row)

  # Public: Scans for text in the buffer, calling a function on each match.
  #
  # regex - A {RegExp} representing the text to find
  # range - A {Range} in the buffer to search within
  # iterator - A {Function} that's called on each match
  scanInBufferRange: (args...) -> @buffer.scanInRange(args...)

  # Public: Scans for text in the buffer _backwards_, calling a function on each match.
  #
  # regex - A {RegExp} representing the text to find
  # range - A {Range} in the buffer to search within
  # iterator - A {Function} that's called on each match
  backwardsScanInBufferRange: (args...) -> @buffer.backwardsScanInRange(args...)

  # Public: Identifies if the {Buffer} is modified (and not saved).
  #
  # Returns a {Boolean}.
  isModified: -> @buffer.isModified()

  # Public: Identifies if the modified buffer should let you know if it's closing
  # without being saved.
  #
  # Returns a {Boolean}.
  shouldPromptToSave: -> @isModified() and not @buffer.hasMultipleEditors()

  # Public: Given a buffer position, this converts it into a screen position.
  #
  # bufferPosition - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - The same options available to {DisplayBuffer.screenPositionForBufferPosition}.
  #
  # Returns a {Point}.
  screenPositionForBufferPosition: (bufferPosition, options) -> @displayBuffer.screenPositionForBufferPosition(bufferPosition, options)

  # Public: Given a buffer range, this converts it into a screen position.
  #
  # screenPosition - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - The same options available to {DisplayBuffer.bufferPositionForScreenPosition}.
  #
  # Returns a {Point}.
  bufferPositionForScreenPosition: (screenPosition, options) -> @displayBuffer.bufferPositionForScreenPosition(screenPosition, options)

  # Public: Given a buffer range, this converts it into a screen position.
  #
  # bufferRange - The {Range} to convert
  #
  # Returns a {Range}.
  screenRangeForBufferRange: (bufferRange) -> @displayBuffer.screenRangeForBufferRange(bufferRange)

  # Public: Given a screen range, this converts it into a buffer position.
  #
  # screenRange - The {Range} to convert
  #
  # Returns a {Range}.
  bufferRangeForScreenRange: (screenRange) -> @displayBuffer.bufferRangeForScreenRange(screenRange)
  # Public: Given a position, this clips it to a real position.
  #
  # For example, if `position`'s row exceeds the row count of the buffer,
  # or if its column goes beyond a line's length, this "sanitizes" the value
  # to a real position.
  #
  # position - The {Point} to clip
  # options - A hash with the following values:
  #           :wrapBeyondNewlines - if `true`, continues wrapping past newlines
  #           :wrapAtSoftNewlines - if `true`, continues wrapping past soft newlines
  #           :screenLine - if `true`, indicates that you're using a line number, not a row number
  #
  # Returns the new, clipped {Point}. Note that this could be the same as `position` if no clipping was performed.
  clipScreenPosition: (screenPosition, options) -> @displayBuffer.clipScreenPosition(screenPosition, options)

  # Public: Gets the line for the given screen row.
  #
  # screenRow - A {Number} indicating the screen row.
  #
  # Returns a {String}.
  lineForScreenRow: (row) -> @displayBuffer.lineForRow(row)

  # Public: Gets the lines for the given screen row boundaries.
  #
  # start - A {Number} indicating the beginning screen row.
  # end - A {Number} indicating the ending screen row.
  #
  # Returns an {Array} of {String}s.
  linesForScreenRows: (start, end) -> @displayBuffer.linesForRows(start, end)

  # Public: Gets the number of screen rows.
  #
  # Returns a {Number}.
  getScreenLineCount: -> @displayBuffer.getLineCount()

  # Public: Gets the length of the longest screen line.
  #
  # Returns a {Number}.
  maxScreenLineLength: -> @displayBuffer.maxLineLength()

  # Public: Gets the number of the last row in the buffer.
  #
  # Returns a {Number}.
  getLastScreenRow: -> @displayBuffer.getLastRow()

  # Public: Given a starting and ending row, this converts every row into a buffer position.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at (default: {.getLastScreenRow})
  #
  # Returns an {Array} of {Range}s.
  bufferRowsForScreenRows: (startRow, endRow) -> @displayBuffer.bufferRowsForScreenRows(startRow, endRow)

  # Public: Retrieves the grammar's token scopes for a buffer position.
  #
  # bufferPosition - A {Point} in the {Buffer}
  #
  # Returns an {Array} of {String}s.
  scopesForBufferPosition: (bufferPosition) -> @displayBuffer.scopesForBufferPosition(bufferPosition)

  # Public: Retrieves the grammar's token for a buffer position.
  #
  # bufferPosition - A {Point} in the {Buffer}
  #
  # Returns a {Token}.
  tokenForBufferPosition: (bufferPosition) -> @displayBuffer.tokenForBufferPosition(bufferPosition)

  # Public: Retrieves the grammar's token scopes for the line with the most recently added cursor.
  #
  # Returns an {Array} of {String}s.
  getCursorScopes: -> @getCursor().getScopes()

  # Internal:
  logScreenLines: (start, end) -> @displayBuffer.logLines(start, end)

  # Public: Determines whether the {Editor} will auto indent rows.
  #
  # Returns a {Boolean}.
  shouldAutoIndent: ->
    config.get("editor.autoIndent")

  # Public: Determines whether the {Editor} will auto indent pasted text.
  #
  # Returns a {Boolean}.
  shouldAutoIndentPastedText: ->
    config.get("editor.autoIndentOnPaste")

  # Public: Inserts text at the current cursor positions
  #
  # text - A {String} representing the text to insert.
  # options - A set of options equivalent to {Selection.insertText}
  insertText: (text, options={}) ->
    options.autoIndent ?= @shouldAutoIndent()
    @mutateSelectedText (selection) -> selection.insertText(text, options)

  # Public: Inserts a new line at the current cursor positions.
  insertNewline: ->
    @insertText('\n')

  # Public: Inserts a new line below the current cursor positions.
  insertNewlineBelow: ->
    @transact =>
      @moveCursorToEndOfLine()
      @insertNewline()

  # Public: Inserts a new line above the current cursor positions.
  insertNewlineAbove: ->
    @transact =>
      onFirstLine = @getCursorBufferPosition().row is 0
      @moveCursorToBeginningOfLine()
      @moveCursorLeft()
      @insertNewline()
      @moveCursorUp() if onFirstLine

  # Public: Indents the current line.
  #
  # options - A set of options equivalent to {Selection.indent}.
  indent: (options={})->
    options.autoIndent ?= @shouldAutoIndent()
    @mutateSelectedText (selection) -> selection.indent(options)

  # Public: Performs a backspace, removing the character found behind the cursor position.
  backspace: ->
    @mutateSelectedText (selection) -> selection.backspace()

  # Public: Performs a backspace to the beginning of the current word, removing characters found there.
  backspaceToBeginningOfWord: ->
    @mutateSelectedText (selection) -> selection.backspaceToBeginningOfWord()

  # Public: Performs a backspace to the beginning of the current line, removing characters found there.
  backspaceToBeginningOfLine: ->
    @mutateSelectedText (selection) -> selection.backspaceToBeginningOfLine()

  # Public: Performs a delete, removing the character found ahead of the cursor position.
  delete: ->
    @mutateSelectedText (selection) -> selection.delete()

  # Public: Performs a delete to the end of the current word, removing characters found there.
  deleteToEndOfWord: ->
    @mutateSelectedText (selection) -> selection.deleteToEndOfWord()

  # Public: Deletes the entire line.
  deleteLine: ->
    @mutateSelectedText (selection) -> selection.deleteLine()

  # Public: Indents the selected rows.
  indentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.indentSelectedRows()

  # Public: Outdents the selected rows.
  outdentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.outdentSelectedRows()

  # Public: Wraps the lines within a selection in comments.
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

  # Given a buffer range, this converts all `\t` characters to the appopriate {.getTabText} value.
  #
  # bufferRange - The {Range} to perform the replace in
  normalizeTabsInBufferRange: (bufferRange) ->
    return unless @softTabs
    @scanInBufferRange /\t/, bufferRange, ({replace}) => replace(@getTabText())

  # Public: Performs a cut to the end of the current line.
  #
  # Characters are removed, but the text remains in the clipboard.
  cutToEndOfLine: ->
    maintainPasteboard = false
    @mutateSelectedText (selection) ->
      selection.cutToEndOfLine(maintainPasteboard)
      maintainPasteboard = true

  # Public: Cuts the selected text.
  cutSelectedText: ->
    maintainPasteboard = false
    @mutateSelectedText (selection) ->
      selection.cut(maintainPasteboard)
      maintainPasteboard = true

  # Public: Copies the selected text.
  copySelectedText: ->
    maintainPasteboard = false
    for selection in @getSelections()
      selection.copy(maintainPasteboard)
      maintainPasteboard = true

  # Public: Pastes the text in the clipboard.
  #
  # options - A set of options equivalent to {Selection.insertText}.
  pasteText: (options={}) ->
    options.normalizeIndent ?= true
    options.autoIndent ?= @shouldAutoIndentPastedText()

    [text, metadata] = pasteboard.read()
    _.extend(options, metadata) if metadata

    @insertText(text, options)

  # Public: Undos the last {Buffer} change.
  undo: ->
    @buffer.undo(this)

  # Public: Redos the last {Buffer} change.
  redo: ->
    @buffer.redo(this)

  ###
  # Internal #
  ###

  transact: (fn) -> @buffer.transact(fn)

  commit: -> @buffer.commit()

  abort: -> @buffer.abort()

  ###
  # Public #
  ###

  # Public: Folds all the rows.
  foldAll: ->
    @languageMode.foldAll()

  # Public: Unfolds all the rows.
  unfoldAll: ->
    @languageMode.unfoldAll()

  # Public: Folds the current row.
  foldCurrentRow: ->
    bufferRow = @bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @foldBufferRow(bufferRow)

  # Public: Given a buffer row, this folds it.
  #
  # bufferRow - A {Number} indicating the buffer row
  foldBufferRow: (bufferRow) ->
    @languageMode.foldBufferRow(bufferRow)

  # Public: Unfolds the current row.
  unfoldCurrentRow: ->
    bufferRow = @bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @unfoldBufferRow(bufferRow)

  # Public: Given a buffer row, this unfolds it.
  #
  # bufferRow - A {Number} indicating the buffer row
  unfoldBufferRow: (bufferRow) ->
    @languageMode.unfoldBufferRow(bufferRow)

  # Public: Folds all selections.
  foldSelection: ->
    selection.fold() for selection in @getSelections()

  # Public: Creates a new fold between two row numbers.
  #
  # startRow - The row {Number} to start folding at
  # endRow - The row {Number} to end the fold
  #
  # Returns the new {Fold}.
  createFold: (startRow, endRow) ->
    @displayBuffer.createFold(startRow, endRow)

  # Public: Removes any {Fold}s found that contain the given buffer row.
  #
  # bufferRow - The buffer row {Number} to check against
  destroyFoldsContainingBufferRow: (bufferRow) ->
    @displayBuffer.destroyFoldsContainingBufferRow(bufferRow)

  # Public: Removes any {Fold}s found that intersect the given buffer row.
  #
  # bufferRow - The buffer row {Number} to check against
  destroyFoldsIntersectingBufferRange: (bufferRange) ->
    for row in [bufferRange.start.row..bufferRange.end.row]
      @destroyFoldsContainingBufferRow(row)

  # Public: Determines if the given row that the cursor is at is folded.
  #
  # Returns `true` if the row is folded, `false` otherwise.
  isFoldedAtCursorRow: ->
    @isFoldedAtScreenRow(@getCursorScreenRow())

  # Public: Determines if the given buffer row is folded.
  #
  # bufferRow - A {Number} indicating the buffer row.
  #
  # Returns `true` if the buffer row is folded, `false` otherwise.
  isFoldedAtBufferRow: (bufferRow) ->
    screenRow = @screenPositionForBufferPosition([bufferRow]).row
    @isFoldedAtScreenRow(screenRow)

  # Public: Determines if the given screen row is folded.
  #
  # screenRow - A {Number} indicating the screen row.
  #
  # Returns `true` if the screen row is folded, `false` otherwise.
  isFoldedAtScreenRow: (screenRow) ->
    @lineForScreenRow(screenRow)?.fold?

  # Public: Given a buffer row, this returns the largest fold that includes it.
  #
  # Largest is defined as the fold whose difference between its start and end points
  # are the greatest.
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns a {Fold}.
  largestFoldContainingBufferRow: (bufferRow) ->
    @displayBuffer.largestFoldContainingBufferRow(bufferRow)

  # Public: Given a screen row, this returns the largest fold that starts there.
  #
  # Largest is defined as the fold whose difference between its start and end points
  # are the greatest.
  #
  # screenRow - A {Number} indicating the screen row
  #
  # Returns a {Fold}.
  largestFoldStartingAtScreenRow: (screenRow) ->
    @displayBuffer.largestFoldStartingAtScreenRow(screenRow)

  # Public: Given a buffer row, this returns a suggested indentation level.
  #
  # The indentation level provided is based on the current language.
  #
  # bufferRow - A {Number} indicating the buffer row
  #
  # Returns a {Number}.
  suggestedIndentForBufferRow: (bufferRow) ->
    @languageMode.suggestedIndentForBufferRow(bufferRow)

  # Public: Indents all the rows between two buffer rows.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  autoIndentBufferRows: (startRow, endRow) ->
    @languageMode.autoIndentBufferRows(startRow, endRow)

  # Public: Given a buffer row, this indents it.
  #
  # bufferRow - The row {Number}
  autoIndentBufferRow: (bufferRow) ->
    @languageMode.autoIndentBufferRow(bufferRow)

  # Public: Given a buffer row, this increases the indentation.
  #
  # bufferRow - The row {Number}
  autoIncreaseIndentForBufferRow: (bufferRow) ->
    @languageMode.autoIncreaseIndentForBufferRow(bufferRow)

  # Public: Given a buffer row, this decreases the indentation.
  #
  # bufferRow - The row {Number}
  autoDecreaseIndentForRow: (bufferRow) ->
    @languageMode.autoDecreaseIndentForBufferRow(bufferRow)

  # Public: Wraps the lines between two rows in comments.
  #
  # If the language doesn't have comments, nothing happens.
  #
  # startRow - The row {Number} to start at
  # endRow - The row {Number} to end at
  #
  # Returns an {Array} of the commented {Ranges}.
  toggleLineCommentsForBufferRows: (start, end) ->
    @languageMode.toggleLineCommentsForBufferRows(start, end)

  # Public: Moves the selected line up one row.
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

  # Public: Moves the selected line down one row.
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

  # Public: Duplicates the current line.
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


  ###
  # Internal #
  ###

  mutateSelectedText: (fn) ->
    @transact => fn(selection) for selection in @getSelections()

  replaceSelectedText: (options={}, fn) ->
    {selectWordIfEmpty} = options
    @mutateSelectedText (selection) =>
      range = selection.getBufferRange()
      if selectWordIfEmpty and selection.isEmpty()
        selection.selectWord()
      text = selection.getText()
      selection.delete()
      selection.insertText(fn(text))
      selection.setBufferRange(range)

  pushOperation: (operation) ->
    @buffer.pushOperation(operation, this)

  ###
  # Public #
  ###

  # Returns a valid {DisplayBufferMarker} object for the given id if one exists.
  getMarker: (id) ->
    @displayBuffer.getMarker(id)

  # Public: Constructs a new marker at the given screen range.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {BufferMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markScreenRange: (args...) ->
    @displayBuffer.markScreenRange(args...)

  # Public: Constructs a new marker at the given buffer range.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {BufferMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markBufferRange: (args...) ->
    @displayBuffer.markBufferRange(args...)

  # Public: Constructs a new marker at the given screen position.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {BufferMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markScreenPosition: (args...) ->
    @displayBuffer.markScreenPosition(args...)

  # Public: Constructs a new marker at the given buffer position.
  #
  # range - The marker {Range} (representing the distance between the head and tail)
  # options - Options to pass to the {BufferMarker} constructor
  #
  # Returns a {Number} representing the new marker's ID.
  markBufferPosition: (args...) ->
    @displayBuffer.markBufferPosition(args...)

  # Public: Removes the marker with the given id.
  #
  # id - The {Number} of the ID to remove
  destroyMarker: (args...) ->
    @displayBuffer.destroyMarker(args...)

  # Public: Gets the number of markers in the buffer.
  #
  # Returns a {Number}.
  getMarkerCount: ->
    @buffer.getMarkerCount()

  # Public: Gets the screen range of the display marker.
  #
  # id - The {Number} of the ID to check
  #
  # Returns a {Range}.
  getMarkerScreenRange: (args...) ->
    @displayBuffer.getMarkerScreenRange(args...)

  # Public: Modifies the screen range of the display marker.
  #
  # id - The {Number} of the ID to change
  # screenRange - The new {Range} to use
  # options - A hash of options matching those found in {BufferMarker.setRange}
  setMarkerScreenRange: (args...) ->
    @displayBuffer.setMarkerScreenRange(args...)

  # Public: Returns `true` if there are multiple cursors in the edit session.
  #
  # Returns a {Boolean}.
  hasMultipleCursors: ->
    @getCursors().length > 1

  # Public: Retrieves  all the cursors.
  #
  # Returns an {Array} of {Cursor}s.
  getCursors: -> new Array(@cursors...)

  # Public: Retrieves a single cursor
  #
  # Returns a {Cursor}.
  getCursor: ->
    _.last(@cursors)

  # Public: Adds a cursor at the provided `screenPosition`.
  #
  # screenPosition - An {Array} of two numbers: the screen row, and the screen column.
  #
  # Returns the new {Cursor}.
  addCursorAtScreenPosition: (screenPosition) ->
    marker = @markScreenPosition(screenPosition, invalidationStrategy: 'never')
    @addSelection(marker).cursor

  # Public: Adds a cursor at the provided `bufferPosition`.
  #
  # bufferPosition - An {Array} of two numbers: the buffer row, and the buffer column.
  #
  # Returns the new {Cursor}.
  addCursorAtBufferPosition: (bufferPosition) ->
    marker = @markBufferPosition(bufferPosition, invalidationStrategy: 'never')
    @addSelection(marker).cursor

  # Public: Adds a cursor to the `EditSession`.
  #
  # marker - The marker where the cursor should be added
  #
  # Returns the new {Cursor}.
  addCursor: (marker) ->
    cursor = new Cursor(editSession: this, marker: marker)
    @cursors.push(cursor)
    @trigger 'cursor-added', cursor
    cursor

  # Public: Removes a cursor from the `EditSession`.
  #
  # cursor - The cursor to remove
  #
  # Returns the removed {Cursor}.
  removeCursor: (cursor) ->
    _.remove(@cursors, cursor)

  # Public: Creates a new selection at the given marker.
  #
  # marker - The marker to highlight
  # options - A hash of options that pertain to the {Selection} constructor.
  #
  # Returns the new {Selection}.
  addSelection: (marker, options={}) ->
    unless options.preserveFolds
      @destroyFoldsIntersectingBufferRange(marker.getBufferRange())
    cursor = @addCursor(marker)
    selection = new Selection(_.extend({editSession: this, marker, cursor}, options))
    @selections.push(selection)
    selectionBufferRange = selection.getBufferRange()
    @mergeIntersectingSelections() unless options.suppressMerge
    if selection.destroyed
      for selection in @getSelections()
        if selection.intersectsBufferRange(selectionBufferRange)
          return selection
    else
      @trigger 'selection-added', selection
      selection

  # Public: Given a buffer range, this adds a new selection for it.
  #
  # bufferRange - A {Range} in the buffer
  # options - A hash of options
  #
  # Returns the new {Selection}.
  addSelectionForBufferRange: (bufferRange, options={}) ->
    options = _.defaults({invalidationStrategy: 'never'}, options)
    marker = @markBufferRange(bufferRange, options)
    @addSelection(marker, options)

  # Public: Given a buffer range, this removes all previous selections and creates a new selection for it.
  #
  # bufferRange - A {Range} in the buffer
  # options - A hash of options
  setSelectedBufferRange: (bufferRange, options) ->
    @setSelectedBufferRanges([bufferRange], options)

  # Public: Given an array of buffer ranges, this removes all previous selections and creates new selections for them.
  #
  # bufferRanges - An {Array} of {Range}s in the buffer
  # options - A hash of options
  setSelectedBufferRanges: (bufferRanges, options={}) ->
    throw new Error("Passed an empty array to setSelectedBufferRanges") unless bufferRanges.length

    selections = @getSelections()
    selection.destroy() for selection in selections[bufferRanges.length...]

    for bufferRange, i in bufferRanges
      bufferRange = Range.fromObject(bufferRange)
      if selections[i]
        selections[i].setBufferRange(bufferRange, options)
      else
        @addSelectionForBufferRange(bufferRange, options)
    @mergeIntersectingSelections(options)

  # Public: Unselects a given selection.
  #
  # selection - The {Selection} to remove.
  removeSelection: (selection) ->
    _.remove(@selections, selection)

  # Public: Clears every selection. TODO
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

  # Public: Gets all the selections.
  #
  # Returns an {Array} of {Selection}s.
  getSelections: -> new Array(@selections...)

  # Public: Gets the selection at the specified index.
  #
  # index - The id {Number} of the selection
  #
  # Returns a {Selection}.
  getSelection: (index) ->
    index ?= @selections.length - 1
    @selections[index]

  # Public: Gets the last selection, _i.e._ the most recently added.
  #
  # Returns a {Selection}.
  getLastSelection: ->
    _.last(@selections)

  # Public: Gets all selections, ordered by their position in the buffer.
  #
  # Returns an {Array} of {Selection}s.
  getSelectionsOrderedByBufferPosition: ->
    @getSelections().sort (a, b) ->
      aRange = a.getBufferRange()
      bRange = b.getBufferRange()
      aRange.end.compare(bRange.end)

  # Public: Gets the very last selection, as it's ordered in the buffer.
  #
  # Returns a {Selection}.
  getLastSelectionInBuffer: ->
    _.last(@getSelectionsOrderedByBufferPosition())

  # Public: Determines if a given buffer range is included in a selection.
  #
  # bufferRange - The {Range} you're checking against
  #
  # Returns a {Boolean}.
  selectionIntersectsBufferRange: (bufferRange) ->
    _.any @getSelections(), (selection) ->
      selection.intersectsBufferRange(bufferRange)

  # Public: Moves every cursor to a given screen position.
  #
  # position - An {Array} of two numbers: the screen row, and the screen column.
  # options - An object with properties based on {Cursor.setScreenPosition}
  #
  setCursorScreenPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setScreenPosition(position, options)

  # Public: Gets the current screen position.
  #
  # Returns an {Array} of two numbers: the screen row, and the screen column.
  getCursorScreenPosition: ->
    @getCursor().getScreenPosition()

  # Public: Gets the current cursor's screen row.
  #
  # Returns the screen row.
  getCursorScreenRow: ->
    @getCursor().getScreenRow()

  # Public: Moves every cursor to a given buffer position.
  #
  # position - An {Array} of two numbers: the buffer row, and the buffer column.
  # options - An object with properties based on {Cursor.setBufferPosition}
  #
  setCursorBufferPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setBufferPosition(position, options)

  # Public: Gets the current buffer position of the cursor.
  #
  # Returns an {Array} of two numbers: the buffer row, and the buffer column.
  getCursorBufferPosition: ->
    @getCursor().getBufferPosition()

  # Public: Gets the screen range of the most recently added {Selection}.
  #
  # Returns a {Range}.
  getSelectedScreenRange: ->
    @getLastSelection().getScreenRange()

  # Public: Gets the buffer range of the most recently added {Selection}.
  #
  # Returns a {Range}.
  getSelectedBufferRange: ->
    @getLastSelection().getBufferRange()

  # Public: Gets the buffer ranges of all the {Selection}s.
  #
  # This is ordered by their buffer position.
  #
  # Returns an {Array} of {Range}s.
  getSelectedBufferRanges: ->
    selection.getBufferRange() for selection in @getSelectionsOrderedByBufferPosition()

  # Public: Gets the currently selected text.
  #
  # Returns a {String}.
  getSelectedText: ->
    @getLastSelection().getText()

  # Public: Given a buffer range, this retrieves the text in that range.
  #
  # range - The {Range} you're interested in
  #
  # Returns a {String} of the combined lines.
  getTextInBufferRange: (range) ->
    @buffer.getTextInRange(range)

  # Public: Retrieves the range for the current paragraph.
  #
  # A paragraph is defined as a block of text surrounded by empty lines.
  #
  # Returns a {Range}.
  getCurrentParagraphBufferRange: ->
    @getCursor().getCurrentParagraphBufferRange()

  # Public: Gets the word located under the cursor.
  #
  # options - An object with properties based on {Cursor.getBeginningOfCurrentWordBufferPosition}.
  #
  # Returns a {String}.
  getWordUnderCursor: (options) ->
    @getTextInBufferRange(@getCursor().getCurrentWordBufferRange(options))

  # Public: Moves every cursor up one row.
  moveCursorUp: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveUp(lineCount)

  # Public: Moves every cursor down one row.
  moveCursorDown: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveDown(lineCount)

  # Public: Moves every cursor left one column.
  moveCursorLeft: ->
    @moveCursors (cursor) -> cursor.moveLeft()

  # Public: Moves every cursor right one column.
  moveCursorRight: ->
    @moveCursors (cursor) -> cursor.moveRight()

  # Public: Moves every cursor to the top of the buffer.
  moveCursorToTop: ->
    @moveCursors (cursor) -> cursor.moveToTop()

  # Public: Moves every cursor to the bottom of the buffer.
  moveCursorToBottom: ->
    @moveCursors (cursor) -> cursor.moveToBottom()

  # Public: Moves every cursor to the beginning of the line.
  moveCursorToBeginningOfLine: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfLine()

  # Public: Moves every cursor to the first non-whitespace character of the line.
  moveCursorToFirstCharacterOfLine: ->
    @moveCursors (cursor) -> cursor.moveToFirstCharacterOfLine()

  # Public: Moves every cursor to the end of the line.
  moveCursorToEndOfLine: ->
    @moveCursors (cursor) -> cursor.moveToEndOfLine()

  # Public: Moves every cursor to the beginning of the current word.
  moveCursorToBeginningOfWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfWord()

  # Public: Moves every cursor to the end of the current word.
  moveCursorToEndOfWord: ->
    @moveCursors (cursor) -> cursor.moveToEndOfWord()

  # Public: Moves every cursor to the beginning of the next word.
  moveCursorToBeginningOfNextWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfNextWord()

  # Internal:
  moveCursors: (fn) ->
    fn(cursor) for cursor in @getCursors()
    @mergeCursors()

  # Public: Selects the text from the current cursor position to a given screen position.
  #
  # position - An instance of {Point}, with a given `row` and `column`.
  selectToScreenPosition: (position) ->
    lastSelection = @getLastSelection()
    lastSelection.selectToScreenPosition(position)
    @mergeIntersectingSelections(reverse: lastSelection.isReversed())

  # Public: Selects the text one position right of the cursor.
  selectRight: ->
    @expandSelectionsForward (selection) => selection.selectRight()

  # Public: Selects the text one position left of the cursor.
  selectLeft: ->
    @expandSelectionsBackward (selection) => selection.selectLeft()

  # Public: Selects all the text one position above the cursor.
  selectUp: ->
    @expandSelectionsBackward (selection) => selection.selectUp()

  # Public: Selects all the text one position below the cursor.
  selectDown: ->
    @expandSelectionsForward (selection) => selection.selectDown()

  # Public: Selects all the text from the current cursor position to the top of the buffer.
  selectToTop: ->
    @expandSelectionsBackward (selection) => selection.selectToTop()

  # Public: Selects all the text in the buffer.
  selectAll: ->
    @expandSelectionsForward (selection) => selection.selectAll()

  # Public: Selects all the text from the current cursor position to the bottom of the buffer.
  selectToBottom: ->
    @expandSelectionsForward (selection) => selection.selectToBottom()

  # Public: Selects all the text from the current cursor position to the beginning of the line.
  selectToBeginningOfLine: ->
    @expandSelectionsBackward (selection) => selection.selectToBeginningOfLine()

  # Public: Selects all the text from the current cursor position to the end of the line.
  selectToEndOfLine: ->
    @expandSelectionsForward (selection) => selection.selectToEndOfLine()

  # Public: Selects the current line.
  selectLine: ->
    @expandSelectionsForward (selection) => selection.selectLine()

  # Public: Moves the current selection down one row.
  addSelectionBelow: ->
    @expandSelectionsForward (selection) => selection.addSelectionBelow()

  # Public: Moves the current selection up one row.
  addSelectionAbove: ->
    @expandSelectionsBackward (selection) => selection.addSelectionAbove()

  # Public: Transposes the current text selections.
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

  # Public: Turns the current selection into upper case.
  upperCase: ->
    @replaceSelectedText selectWordIfEmpty:true, (text) => text.toUpperCase()

  # Public: Turns the current selection into lower case.
  lowerCase: ->
    @replaceSelectedText selectWordIfEmpty:true, (text) => text.toLowerCase()

  # Public: Joins the current line with the one below it.
  #
  # Multiple cursors are considered equally. If there's a selection in the editor,
  # all the lines are joined together.
  joinLine: ->
    @mutateSelectedText (selection) -> selection.joinLine()

  expandLastSelectionOverLine: ->
    @getLastSelection().expandOverLine()

  # Public: Selects all the text from the current cursor position to the beginning of the word.
  selectToBeginningOfWord: ->
    @expandSelectionsBackward (selection) => selection.selectToBeginningOfWord()

  # Public: Selects all the text from the current cursor position to the end of the word.
  selectToEndOfWord: ->
    @expandSelectionsForward (selection) => selection.selectToEndOfWord()

  # Public: Selects all the text from the current cursor position to the beginning of the next word.
  selectToBeginningOfNextWord: ->
    @expandSelectionsForward (selection) => selection.selectToBeginningOfNextWord()

  # Public: Selects the current word.
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

  # Public: Given a buffer position, this finds all markers that contain the position.
  #
  # bufferPosition - A {Point} to check
  #
  # Returns an {Array} of {Numbers}, representing marker IDs containing `bufferPosition`.
  markersForBufferPosition: (bufferPosition) ->
    @buffer.markersForPosition(bufferPosition)

  mergeCursors: ->
    positions = []
    for cursor in @getCursors()
      position = cursor.getBufferPosition().toString()
      if position in positions
        cursor.destroy()
      else
        positions.push(position)

  expandSelectionsForward: (fn) ->
    fn(selection) for selection in @getSelections()
    @mergeIntersectingSelections()

  expandSelectionsBackward: (fn) ->
    fn(selection) for selection in @getSelections()
    @mergeIntersectingSelections(reverse: true)

  finalizeSelections: ->
    selection.finalize() for selection in @getSelections()

  mergeIntersectingSelections: (options) ->
    for selection in @getSelections()
      otherSelections = @getSelections()
      _.remove(otherSelections, selection)
      for otherSelection in otherSelections
        if selection.intersectsWith(otherSelection)
          selection.merge(otherSelection, options)
          @mergeIntersectingSelections(options)
          return

  # Internal:
  inspect: ->
    JSON.stringify @serialize()

  preserveCursorPositionOnBufferReload: ->
    cursorPosition = null
    @subscribe @buffer, "will-reload", =>
      cursorPosition = @getCursorBufferPosition()
    @subscribe @buffer, "reloaded", =>
      @setCursorBufferPosition(cursorPosition) if cursorPosition
      cursorPosition = null

  # Public: Retrieves the current {EditSession}'s grammar.
  #
  # Returns a {String} indicating the language's grammar rules.
  getGrammar: ->
    @displayBuffer.getGrammar()

  # Public: Sets the current {EditSession}'s grammar.
  #
  # grammar - A {String} indicating the language's grammar rules.
  setGrammar: (grammar) ->
    @displayBuffer.setGrammar(grammar)

  # Public: Reloads the current grammar.
  reloadGrammar: ->
    @displayBuffer.reloadGrammar()

  # Internal:
  handleGrammarChange: ->
    @unfoldAll()
    @trigger 'grammar-changed'

  # Internal:
  getDebugSnapshot: ->
    [
      @displayBuffer.getDebugSnapshot()
      @displayBuffer.tokenizedBuffer.getDebugSnapshot()
    ].join('\n\n')

_.extend(EditSession.prototype, EventEmitter)
_.extend(EditSession.prototype, Subscriber)
