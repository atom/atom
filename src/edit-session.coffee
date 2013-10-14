_ = require './underscore-extensions'
fsUtils = require './fs-utils'
path = require 'path'
telepath = require 'telepath'
guid = require 'guid'
{Point, Range} = telepath
LanguageMode = require './language-mode'
DisplayBuffer = require './display-buffer'
Cursor = require './cursor'
Selection = require './selection'
{EventEmitter, Subscriber} = require 'emissary'
TextMateScopeSelector = require('first-mate').ScopeSelector

# Public: The core model of Atom.
#
# An {EditSession} represents a unique view of each document, with it's own
# {Cursor}s and scroll position.
#
# For instance if a user creates a split, Atom creates a second {EditSession}
# but both {EditSession}s interact with the same buffer underlying buffer. So
# if you type in either buffer it immediately appears in both but if you scroll
# in one it doesn't scroll the other.
#
# Almost all extension will interact primiarily with this class as it provides
# access to objects you'll most commonly interact with. To access it you'll
# want to register a callback on {RootView} which will be fired once for every
# existing {EditSession} as well as any future {EditSession}s.
#
# ## Example
# ```coffeescript
# global.rootView.eachEditSession (editSession) ->
#   editSession.insertText('Hello World')
# ```
#
# ## Collaboration builtin
#
# FIXME: Describe how there are both local and remote cursors and selections and
# why that is.
module.exports =
class EditSession
  _.extend @prototype, EventEmitter
  _.extend @prototype, Subscriber

  @acceptsDocuments: true

  registerDeserializer(this)

  @version: 5

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

  # Private:
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
      {buffer, displayBuffer, tabLength, softTabs, softWrap, suppressCursorCreation, initialLine} = optionsOrState
      @id = guid.create().toString()
      displayBuffer ?= new DisplayBuffer({buffer, tabLength, softWrap})
      @state = site.createDocument
        deserializer: @constructor.name
        version: @constructor.version
        id: @id
        displayBuffer: displayBuffer.getState()
        softTabs: buffer.usesSoftTabs() ? softTabs ? config.get('editor.softTabs') ? true
        scrollTop: 0
        scrollLeft: 0
      @setBuffer(buffer)
      @setDisplayBuffer(displayBuffer)

    if @getCursors().length is 0 and not suppressCursorCreation
      if initialLine
        position = [initialLine, 0]
      else
        position = _.last(@getRemoteCursors())?.getBufferPosition() ? [0, 0]
      @addCursorAtBufferPosition(position)

    @languageMode = new LanguageMode(this, @buffer.getExtension())
    @subscribe @state, 'changed', ({key, newValue}) =>
      switch key
        when 'scrollTop'
          @emit 'scroll-top-changed', newValue
        when 'scrollLeft'
          @emit 'scroll-left-changed', newValue

    project.addEditSession(this) if registerEditSession

  # Private:
  setBuffer: (@buffer) ->
    @buffer.retain()
    @subscribe @buffer, "path-changed", =>
      project.setPath(path.dirname(@getPath())) unless project.getPath()?
      @emit "title-changed"
      @emit "path-changed"
    @subscribe @buffer, "contents-modified", => @emit "contents-modified"
    @subscribe @buffer, "contents-conflicted", => @emit "contents-conflicted"
    @subscribe @buffer, "modified-status-changed", => @emit "modified-status-changed"
    @preserveCursorPositionOnBufferReload()

  # Private:
  setDisplayBuffer: (@displayBuffer) ->
    @subscribe @displayBuffer, 'marker-created', @handleMarkerCreated
    @subscribe @displayBuffer, "changed", (e) => @emit 'screen-lines-changed', e
    @subscribe @displayBuffer, "markers-updated", => @mergeIntersectingSelections()
    @subscribe @displayBuffer, 'grammar-changed', => @handleGrammarChange()
    @subscribe @displayBuffer, 'soft-wrap-changed', (args...) => @emit 'soft-wrap-changed', args...

  # Private:
  getViewClass: ->
    require './editor'

  # Private:
  destroy: ->
    return if @destroyed
    @destroyed = true
    @unsubscribe()
    @buffer.release()
    selection.destroy() for selection in @getSelections()
    @displayBuffer.destroy()
    @languageMode.destroy()
    project?.removeEditSession(this)
    @emit 'destroyed'
    @off()

  # Private:
  serialize: -> @state.clone()

  # Private:
  getState: -> @state

  # Private: Creates an {EditSession} with the same initial state
  copy: ->
    tabLength = @getTabLength()
    displayBuffer = @displayBuffer.copy()
    softTabs = @getSoftTabs()
    newEditSession = new EditSession({@buffer, displayBuffer, tabLength, softTabs, suppressCursorCreation: true})
    newEditSession.setScrollTop(@getScrollTop())
    newEditSession.setScrollLeft(@getScrollLeft())
    for marker in @findMarkers(editSessionId: @id)
      marker.copy(editSessionId: newEditSession.id, preserveFolds: true)
    newEditSession

  # Public: Retrieves the filename of the open file.
  #
  # This is `'untitled'` if the file is new and not saved to the disk.
  #
  # Returns a {String}.
  getTitle: ->
    if sessionPath = @getPath()
      path.basename(sessionPath)
    else
      'untitled'

  # Public: Retrieves the filename and path of the open file.
  #
  # It has the follows the following format, `<filename> - <directory>`. If the
  # file is brand new, the title is `untitled`.
  #
  # Returns a {String}.
  getLongTitle: ->
    if sessionPath = @getPath()
      fileName = path.basename(sessionPath)
      directory = path.basename(path.dirname(sessionPath))
      "#{fileName} - #{directory}"
    else
      'untitled'

  # Public: Compares two `EditSession`s to determine equality.
  #
  # Equality is based on the condition that:
  #
  # * the two {TextBuffer}s are the same
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

  # Public: Controls visiblity based on the given Boolean.
  setVisible: (visible) -> @displayBuffer.setVisible(visible)

  # Public: FIXME: I don't understand this.
  setScrollTop: (scrollTop) -> @state.set('scrollTop', scrollTop)

  # Public: Returns the current `scrollTop` value
  getScrollTop: -> @state.get('scrollTop') ? 0

  # Public: FIXME: I don't understand this.
  setScrollLeft: (scrollLeft) -> @state.set('scrollLeft', scrollLeft)

  # Public: Returns the current `scrollLeft` value
  getScrollLeft: -> @state.get('scrollLeft')

  # Set the number of characters that can be displayed horizontally in the
  # editor that contains this edit session.
  #
  # editorWidthInChars - A {Number} of characters
  setEditorWidthInChars: (editorWidthInChars) ->
    @displayBuffer.setEditorWidthInChars(editorWidthInChars)

  # Public: Sets the column at which columsn will soft wrap
  getSoftWrapColumn: -> @displayBuffer.getSoftWrapColumn()

  # Public: Returns whether soft tabs are enabled or not.
  getSoftTabs: -> @state.get('softTabs')

  # Public: Controls whether soft tabs are enabled or not.
  setSoftTabs: (softTabs) ->
    @state.set('softTabs', softTabs)

  # Public: Returns whether soft wrap is enabled or not.
  getSoftWrap: -> @displayBuffer.getSoftWrap()

  # Public: Controls whether soft tabs are enabled or not.
  setSoftWrap: (softWrap) -> @displayBuffer.setSoftWrap(softWrap)

  # Public: Returns that String used to indicate a tab.
  #
  # If soft tabs are enabled, this is a space (`" "`) times the {.getTabLength} value.
  # Otherwise, it's a tab (`\t`).
  getTabText: -> @buildIndentString(1)

  # Public: Returns the current tab length.
  getTabLength: -> @displayBuffer.getTabLength()

  # Public: Sets the current tab length.
  setTabLength: (tabLength) -> @displayBuffer.setTabLength(tabLength)

  # Public: Given a position, this clips it to a real position.
  #
  # For example, if `position`'s row exceeds the row count of the buffer,
  # or if its column goes beyond a line's length, this "sanitizes" the value
  # to a real position.
  #
  # * position:
  #   The {Point} to clip
  #
  # Returns the new, clipped {Point}. Note that this could be the same as
  #   `position` if no clipping was performed.
  clipBufferPosition: (bufferPosition) -> @buffer.clipPosition(bufferPosition)

  # Public: Given a range, this clips it to a real range.
  #
  # For example, if `range`'s row exceeds the row count of the buffer,
  # or if its column goes beyond a line's length, this "sanitizes" the value
  # to a real range.
  #
  # * range:
  #   The {Range} to clip
  #
  # Returns the new, clipped {Range}. Note that this could be the same as
  #   `range` if no clipping was performed.
  clipBufferRange: (range) -> @buffer.clipRange(range)

  # Public: Returns the indentation level of the given a buffer row
  #
  # * bufferRow:
  #   A Number indicating the buffer row.
  indentationForBufferRow: (bufferRow) ->
    @indentLevelForLine(@lineForBufferRow(bufferRow))

  # Public: Sets the indentation level for the given buffer row.
  #
  # * bufferRow:
  #   A {Number} indicating the buffer row.
  # * newLevel:
  #   A {Number} indicating the new indentation level.
  setIndentationForBufferRow: (bufferRow, newLevel) ->
    currentLevel = @indentationForBufferRow(bufferRow)
    currentIndentString = @buildIndentString(currentLevel)
    newIndentString = @buildIndentString(newLevel)
    @buffer.change([[bufferRow, 0], [bufferRow, currentIndentString.length]], newIndentString)

  # Public: Returns the indentation level of the given line of text.
  #
  # * line:
  #   A {String} in the current buffer.
  #
  # Returns a {Number} or 0 if the text isn't found within the buffer.
  indentLevelForLine: (line) ->
    if match = line.match(/^[\t ]+/)
      leadingWhitespace = match[0]
      tabCount = leadingWhitespace.match(/\t/g)?.length ? 0
      spaceCount = leadingWhitespace.match(/[ ]/g)?.length ? 0
      tabCount + (spaceCount / @getTabLength())
    else
      0

  # Private: Constructs the string used for tabs.
  buildIndentString: (number) ->
    if @getSoftTabs()
      _.multiplyString(" ", number * @getTabLength())
    else
      _.multiplyString("\t", Math.floor(number))

  # {Delegates to: TextBuffer.save}
  save: -> @buffer.save()

  # {Delegates to: TextBuffer.saveAs}
  saveAs: (path) -> @buffer.saveAs(path)

  # {Delegates to: TextBuffer.getExtension}
  getFileExtension: -> @buffer.getExtension()

  # {Delegates to: TextBuffer.getPath}
  getPath: -> @buffer.getPath()

  # {Delegates to: TextBuffer.getRelativePath}
  getRelativePath: -> @buffer.getRelativePath()

  # {Delegates to: TextBuffer.getText}
  getText: -> @buffer.getText()

  # {Delegates to: TextBuffer.setText}
  setText: (text) -> @buffer.setText(text)

  # Private: Retrieves the current {TextBuffer}.
  getBuffer: -> @buffer

  # Public: Retrieves the current buffer's URI.
  getUri: -> @buffer.getUri()

  # {Delegates to: TextBuffer.isRowBlank}
  isBufferRowBlank: (bufferRow) -> @buffer.isRowBlank(bufferRow)

  # Public: Determine if the given row is entirely a comment
  isBufferRowCommented: (bufferRow) ->
    if match = @lineForBufferRow(bufferRow).match(/\S/)
      scopes = @tokenForBufferPosition([bufferRow, match.index]).scopes
      new TextMateScopeSelector('comment.*').matches(scopes)

  # {Delegates to: TextBuffer.nextNonBlankRow}
  nextNonBlankBufferRow: (bufferRow) -> @buffer.nextNonBlankRow(bufferRow)

  # {Delegates to: TextBuffer.getEofPosition}
  getEofBufferPosition: -> @buffer.getEofPosition()

  # {Delegates to: TextBuffer.getLastRow}
  getLastBufferRow: -> @buffer.getLastRow()

  # {Delegates to: TextBuffer.rangeForRow}
  bufferRangeForBufferRow: (row, options) -> @buffer.rangeForRow(row, options)

  # {Delegates to: TextBuffer.lineForRow}
  lineForBufferRow: (row) -> @buffer.lineForRow(row)

  # {Delegates to: TextBuffer.lineLengthForRow}
  lineLengthForBufferRow: (row) -> @buffer.lineLengthForRow(row)

  # {Delegates to: TextBuffer.scan}
  scan: (args...) -> @buffer.scan(args...)

  # {Delegates to: TextBuffer.scanInRange}
  scanInBufferRange: (args...) -> @buffer.scanInRange(args...)

  # {Delegates to: TextBuffer.backwardsScanInRange}
  backwardsScanInBufferRange: (args...) -> @buffer.backwardsScanInRange(args...)

  # {Delegates to: TextBuffer.isModified}
  isModified: -> @buffer.isModified()

  # Public: Determines if the user should be prompted to save before closing.
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

  # Public: ?
  bufferRangeForScopeAtCursor: (selector) ->
    @displayBuffer.bufferRangeForScopeAtPosition(selector, @getCursorBufferPosition())

  # {Delegates to: DisplayBuffer.tokenForBufferPosition}
  tokenForBufferPosition: (bufferPosition) -> @displayBuffer.tokenForBufferPosition(bufferPosition)

  # Public: Retrieves the grammar's token scopes for the line with the most
  # recently added cursor.
  #
  # Returns an {Array} of {String}s.
  getCursorScopes: -> @getCursor().getScopes()

  # Public: Inserts text at the current cursor positions
  #
  # * text:
  #   A String representing the text to insert.
  # * options:
  #   + A set of options equivalent to {Selection.insertText}
  insertText: (text, options={}) ->
    options.autoIndentNewline ?= @shouldAutoIndent()
    options.autoDecreaseIndent ?= @shouldAutoIndent()
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
  # * options
  #    + A set of options equivalent to {Selection.indent}.
  indent: (options={})->
    options.autoIndent ?= @shouldAutoIndent()
    @mutateSelectedText (selection) -> selection.indent(options)

  # Public: Removes the character found behind the current cursor position.
  #
  # FIXME: Does this remove content from all cursors or the last one?
  backspace: ->
    @mutateSelectedText (selection) -> selection.backspace()

  # Public: Removes all characters from the current cursor position until the
  # beginging of the current word.
  backspaceToBeginningOfWord: ->
    @mutateSelectedText (selection) -> selection.backspaceToBeginningOfWord()

  # Public: Removes all characters from the current cursor position to the start
  # of the line.
  backspaceToBeginningOfLine: ->
    @mutateSelectedText (selection) -> selection.backspaceToBeginningOfLine()

  # Public: Removes the current selection or the next character after the
  # cursor.
  delete: ->
    @mutateSelectedText (selection) -> selection.delete()

  # Public: Removes all characters from the cursor until the end of the current
  # word.
  deleteToEndOfWord: ->
    @mutateSelectedText (selection) -> selection.deleteToEndOfWord()

  # Public: Deletes the entire line.
  deleteLine: ->
    @mutateSelectedText (selection) -> selection.deleteLine()

  # Public: Indents the currently selected rows.
  #
  # FIXME: what does this do if no selection?
  indentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.indentSelectedRows()

  # Public: Outdents the selected rows.
  #
  # FIXME: what does this do if no selection?
  outdentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.outdentSelectedRows()

  # Public: Wraps the lines within a selection in comments.
  #
  # If the language doesn't have comments, nothing happens.
  #
  # Returns an {Array} of the commented {Ranges}.
  toggleLineCommentsInSelection: ->
    @mutateSelectedText (selection) -> selection.toggleLineComments()

  # Public: Indents selected lines based on grammar's suggested indent levels.
  autoIndentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.autoIndentSelectedRows()

  # Public: Converts all indents to the current {.getTabText} given a {Range}.
  normalizeTabsInBufferRange: (bufferRange) ->
    return unless @getSoftTabs()
    @scanInBufferRange /\t/, bufferRange, ({replace}) => replace(@getTabText())

  # Public: Copies and removes all characters from cursor to the end of the
  # line.
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
  # * options:
  #    + A set of options equivalent to {Selection.insertText}.
  pasteText: (options={}) ->
    [text, metadata] = pasteboard.read()

    if config.get('editor.normalizeIndentOnPaste') and metadata
      options.indentBasis ?= metadata.indentBasis

    @insertText(text, options)

  # Public: Undoes the last change.
  undo: ->
    @buffer.undo(this)

  # Pulic: Redoes the last change.
  redo: ->
    @buffer.redo(this)

  # Public: Folds all the rows.
  foldAll: ->
    @languageMode.foldAll()

  # Public: Unfolds all the rows.
  unfoldAll: ->
    @languageMode.unfoldAll()

  # Public: Creates a fold for each section at the given indent level.
  foldAllAtIndentLevel: (indentLevel) ->
    @languageMode.foldAllAtIndentLevel(indentLevel)

  # Public: Folds the current row.
  foldCurrentRow: ->
    bufferRow = @bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @foldBufferRow(bufferRow)

  # Public: Folds a give buffer row.
  foldBufferRow: (bufferRow) ->
    @languageMode.foldBufferRow(bufferRow)

  # Public: Unfolds the current row.
  unfoldCurrentRow: ->
    bufferRow = @bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @unfoldBufferRow(bufferRow)

  # Public: Unfolds a given a buffer row.
  unfoldBufferRow: (bufferRow) ->
    @languageMode.unfoldBufferRow(bufferRow)

  # Public: Folds all selections.
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

  # Public: Removes any {Fold}s found that intersect the given buffer row.
  destroyFoldsIntersectingBufferRange: (bufferRange) ->
    for row in [bufferRange.start.row..bufferRange.end.row]
      @destroyFoldsContainingBufferRow(row)

  # Public: Returns whether the current row is folded.
  isFoldedAtCursorRow: ->
    @isFoldedAtScreenRow(@getCursorScreenRow())

  # Public: Returns whether a given buffer row if folded
  isFoldedAtBufferRow: (bufferRow) ->
    @displayBuffer.isFoldedAtBufferRow(bufferRow)

  # Public: Returns whether a given screen row if folded
  isFoldedAtScreenRow: (screenRow) ->
    @displayBuffer.isFoldedAtScreenRow(screenRow)

  # {Delegates to: DisplayBuffer.largestFoldContainingBufferRow}
  largestFoldContainingBufferRow: (bufferRow) ->
    @displayBuffer.largestFoldContainingBufferRow(bufferRow)

  # {Delegates to: DisplayBuffer.largestFoldStartingAtScreenRow}
  largestFoldStartingAtScreenRow: (screenRow) ->
    @displayBuffer.largestFoldStartingAtScreenRow(screenRow)

  # Public: Suggests the indent for the given buffer row.
  suggestedIndentForBufferRow: (bufferRow) ->
    @languageMode.suggestedIndentForBufferRow(bufferRow)

  # Public: Indents all the rows between two buffer rows.
  #
  # * startRow: The row {Number} to start at (inclusive)
  # * endRow: The row {Number} to end at (inclusive)
  autoIndentBufferRows: (startRow, endRow) ->
    @languageMode.autoIndentBufferRows(startRow, endRow)

  # Public: Indents the given buffer row to it's suggested level.
  autoIndentBufferRow: (bufferRow) ->
    @languageMode.autoIndentBufferRow(bufferRow)

  # Public:
  #
  # FIXME: What does this do?
  autoDecreaseIndentForBufferRow: (bufferRow) ->
    @languageMode.autoDecreaseIndentForBufferRow(bufferRow)

  # Public: Wraps the lines between two rows in comments.
  #
  # If the language doesn't have comments, nothing happens.
  #
  # startRow - The row {Number} to start at (inclusive)
  # endRow - The row {Number} to end at (inclusive)
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
  # If more than one cursor is present, only the most recently added one is
  # duplicated.
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

  # Private:
  mutateSelectedText: (fn) ->
    @transact => fn(selection) for selection in @getSelections()

  # Private:
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

  # Public: Returns a valid {DisplayBufferMarker} object for the given id.
  getMarker: (id) ->
    @displayBuffer.getMarker(id)

  # Public: Returns all {DisplayBufferMarker}s.
  getMarkers: ->
    @displayBuffer.getMarkers()

  # Public: Returns all {DisplayBufferMarker}s that match all given attributes.
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

  # {Delegates to: DisplayBuffer.getMarkerCount}
  getMarkerCount: ->
    @buffer.getMarkerCount()

  # Public: Determines if there are multiple cursors.
  hasMultipleCursors: ->
    @getCursors().length > 1

  # Public: Returns an Array of all {Cursor}s, including cursors representing
  # remote users.
  getAllCursors: ->
    @getCursors().concat(@getRemoteCursors())

  # Public: Returns an Array of all local {Cursor}s.
  getCursors: -> new Array(@cursors...)

  # Public: Returns the most recently added {Cursor}.
  getCursor: ->
    _.last(@cursors)

  # Public: Returns an Array of all remove {Cursor}s.
  getRemoteCursors: -> new Array(@remoteCursors...)

  # Public: Adds and returns a cursor at the given screen position.
  addCursorAtScreenPosition: (screenPosition) ->
    @markScreenPosition(screenPosition, @getSelectionMarkerAttributes())
    @getLastSelection().cursor

  # Public: Adds and returns a cursor at the given buffer position.
  addCursorAtBufferPosition: (bufferPosition) ->
    @markBufferPosition(bufferPosition, @getSelectionMarkerAttributes())
    @getLastSelection().cursor

  # Public: Adds and returns a cursor at the given {DisplayBufferMarker}
  # position.
  addCursor: (marker) ->
    cursor = new Cursor(editSession: this, marker: marker)
    if marker.isLocal()
      @cursors.push(cursor)
    else
      @remoteCursors.push(cursor)
    @emit 'cursor-added', cursor
    cursor

  # Public: Removes and returns a cursor from the `EditSession`.
  removeCursor: (cursor) ->
    _.remove(@cursors, cursor)

  # Public: Creates a new selection at the given marker.
  #
  # * marker:
  #   The {DisplayBufferMarker} to highlight
  # * options:
  #   + A hash of options that pertain to the {Selection} constructor.
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
      @emit 'selection-added', selection
      selection

  # Public: Given a buffer range, this adds a new selection for it.
  #
  # * bufferRange:
  #   A {Range} in the buffer
  # * options:
  #    + A hash of options for {.markBufferRange}
  #
  # Returns the new {Selection}.
  addSelectionForBufferRange: (bufferRange, options={}) ->
    @markBufferRange(bufferRange, _.defaults(@getSelectionMarkerAttributes(), options))
    @getLastSelection()

  # Public: Given a buffer range, this removes all previous selections and
  # creates a new selection for it.
  #
  # * bufferRange:
  #   A {Range} in the buffer
  # * options:
  #    + A hash of options for {.setSelectedBufferRanges}
  setSelectedBufferRange: (bufferRange, options) ->
    @setSelectedBufferRanges([bufferRange], options)

  # Public: Given an array of buffer ranges, this removes all previous
  # selections and creates new selections for them.
  #
  # * bufferRange:
  #   A {Range} in the buffer
  # * options:
  #    + A hash of options for {.setSelectedBufferRanges}
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

  # Public: Unselects a given selection.
  #
  # * selection - The {Selection} to remove.
  removeSelection: (selection) ->
    if selection.isLocal()
      _.remove(@selections, selection)
    else
      _.remove(@remoteSelections, selection)

  # Public: Clears every selection.
  #
  # TODO: Is this still to be done?
  clearSelections: ->
    @consolidateSelections()
    @getSelection().clear()

  # Public:
  #
  # FIXME: What does this do?
  consolidateSelections: ->
    selections = @getSelections()
    if selections.length > 1
      selection.destroy() for selection in selections[0...-1]
      true
    else
      false

  # Public: Returns all selections, including remote selections.
  getAllSelections: ->
    @getSelections().concat(@getRemoteSelections())

  # Public: Gets all local selections.
  #
  # Returns an {Array} of {Selection}s.
  getSelections: -> new Array(@selections...)

  # Public: Returns the selection at the specified index.
  getSelection: (index) ->
    index ?= @selections.length - 1
    @selections[index]

  # Public: Returns the most recently added {Selection}
  getLastSelection: ->
    _.last(@selections)

  # Public: Returns all remote selections.
  getRemoteSelections: -> new Array(@remoteSelections...)

  # Public: Gets all local selections, ordered by their position in the buffer.
  #
  # Returns an {Array} of {Selection}s.
  getSelectionsOrderedByBufferPosition: ->
    @getSelections().sort (a, b) -> a.compare(b)

  # Public: Gets all remote selections, ordered by their position in the buffer.
  #
  # Returns an {Array} of {Selection}s.
  getRemoteSelectionsOrderedByBufferPosition: ->
    @getRemoteSelections().sort (a, b) -> a.compare(b)

  # Public: Gets the very last local selection in the buffer.
  #
  # Returns a {Selection}.
  getLastSelectionInBuffer: ->
    _.last(@getSelectionsOrderedByBufferPosition())

  # Public: Determines if a given buffer range is included in a {Selection}.
  #
  # * bufferRange:
  #   The {Range} you're checking against
  #
  # Returns a {Boolean}.
  selectionIntersectsBufferRange: (bufferRange) ->
    _.any @getSelections(), (selection) ->
      selection.intersectsBufferRange(bufferRange)

  # Public: Moves every local cursor to a given screen position.
  #
  # * position:
  #   An {Array} of two numbers: the screen row, and the screen column.
  # * options:
  #   An object with properties based on {Cursor.setScreenPosition}
  setCursorScreenPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setScreenPosition(position, options)

  # Public: Gets the current screen position of the most recently added
  # local {Cursor}.
  #
  # Returns an {Array} of two numbers: the screen row, and the screen column.
  getCursorScreenPosition: ->
    @getCursor().getScreenPosition()

  # Public: Gets the screen row of the most recently added local {Cursor}.
  #
  # Returns the screen row {Number}.
  getCursorScreenRow: ->
    @getCursor().getScreenRow()

  # Public: Moves every cursor to a given buffer position.
  #
  # * position:
  #   An {Array} of two numbers: the buffer row, and the buffer column.
  # * options:
  #    + An object with properties based on {Cursor.setBufferPosition}
  setCursorBufferPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setBufferPosition(position, options)

  # Public: Gets the current buffer position of the most recently added {Cursor}.
  #
  # Returns an {Array} of two numbers: the buffer row, and the buffer column.
  getCursorBufferPosition: ->
    @getCursor().getBufferPosition()

  # Public: Returns the screen {Range} of the most recently added local
  # {Selection}.
  getSelectedScreenRange: ->
    @getLastSelection().getScreenRange()

  # Public: Returns the buffer {Range} of the most recently added local
  # {Selection}.
  getSelectedBufferRange: ->
    @getLastSelection().getBufferRange()

  # Public: Gets an Array of buffer {Range}s of all the local {Selection}s.
  #
  # Sorted by their position in the file itself.
  getSelectedBufferRanges: ->
    selection.getBufferRange() for selection in @getSelectionsOrderedByBufferPosition()

  # Public: Gets an Array of buffer {Range}s of all the remote {Selection}s.
  #
  # Sorted by their position in the file itself.
  getRemoteSelectedBufferRanges: ->
    selection.getBufferRange() for selection in @getRemoteSelectionsOrderedByBufferPosition()

  # Public: Returns the selected text of the most recently added local {Selection}.
  getSelectedText: ->
    @getLastSelection().getText()

  # Public: Returns the text within a given a buffer {Range}
  getTextInBufferRange: (range) ->
    @buffer.getTextInRange(range)

  setTextInBufferRange: (range, text) -> @getBuffer().change(range, text)

  # Public: Returns the text of the most recent local cursor's surrounding
  # paragraph.
  getCurrentParagraphBufferRange: ->
    @getCursor().getCurrentParagraphBufferRange()

  # Public: Returns the word under the most recently added local {Cursor}.
  #
  # * options:
  #    + An object with properties based on
  #      {Cursor.getBeginningOfCurrentWordBufferPosition}.
  getWordUnderCursor: (options) ->
    @getTextInBufferRange(@getCursor().getCurrentWordBufferRange(options))

  # Public: Moves every local cursor up one row.
  moveCursorUp: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveUp(lineCount, moveToEndOfSelection: true)

  # Public: Moves every local cursor down one row.
  moveCursorDown: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveDown(lineCount, moveToEndOfSelection: true)

  # Public: Moves every local cursor left one column.
  moveCursorLeft: ->
    @moveCursors (cursor) -> cursor.moveLeft(moveToEndOfSelection: true)

  # Public: Moves every local cursor right one column.
  moveCursorRight: ->
    @moveCursors (cursor) -> cursor.moveRight(moveToEndOfSelection: true)

  # Public: Moves every local cursor to the top of the buffer.
  moveCursorToTop: ->
    @moveCursors (cursor) -> cursor.moveToTop()

  # Public: Moves every local cursor to the bottom of the buffer.
  moveCursorToBottom: ->
    @moveCursors (cursor) -> cursor.moveToBottom()

  # Public: Moves every local cursor to the beginning of the line.
  moveCursorToBeginningOfLine: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfLine()

  # Public: Moves every local cursor to the first non-whitespace character of the line.
  moveCursorToFirstCharacterOfLine: ->
    @moveCursors (cursor) -> cursor.moveToFirstCharacterOfLine()

  # Public: Moves every local cursor to the end of the line.
  moveCursorToEndOfLine: ->
    @moveCursors (cursor) -> cursor.moveToEndOfLine()

  # Public: Moves every local cursor to the beginning of the current word.
  moveCursorToBeginningOfWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfWord()

  # Public: Moves every local cursor to the end of the current word.
  moveCursorToEndOfWord: ->
    @moveCursors (cursor) -> cursor.moveToEndOfWord()

  # Public: Moves every local cursor to the beginning of the next word.
  moveCursorToBeginningOfNextWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfNextWord()

  # Public: Moves every local cursor to the previous word boundary.
  moveCursorToPreviousWordBoundary: ->
    @moveCursors (cursor) -> cursor.moveToPreviousWordBoundary()

  # Public: Moves every local cursor to the next word boundary.
  moveCursorToNextWordBoundary: ->
    @moveCursors (cursor) -> cursor.moveToNextWordBoundary()

  # Internal: Executes given function on all local cursors.
  moveCursors: (fn) ->
    fn(cursor) for cursor in @getCursors()
    @mergeCursors()

  # Public: Selects the text from the current cursor position to a given screen
  # position.
  #
  # * position:
  #   An instance of {Point}, with a given `row` and `column`.
  selectToScreenPosition: (position) ->
    lastSelection = @getLastSelection()
    lastSelection.selectToScreenPosition(position)
    @mergeIntersectingSelections(isReversed: lastSelection.isReversed())

  # Public: Selects the text one position right of all local cursors.
  selectRight: ->
    @expandSelectionsForward (selection) => selection.selectRight()

  # Public: Selects the text one position left of all local cursors.
  selectLeft: ->
    @expandSelectionsBackward (selection) => selection.selectLeft()

  # Public: Selects all the text one position above all local cursors.
  selectUp: ->
    @expandSelectionsBackward (selection) => selection.selectUp()

  # Public: Selects all the text one position below all local cursors.
  selectDown: ->
    @expandSelectionsForward (selection) => selection.selectDown()

  # Public: Selects all the text from all local cursors to the top of the
  # buffer.
  selectToTop: ->
    @expandSelectionsBackward (selection) => selection.selectToTop()

  # Public: Selects all the text in the buffer.
  selectAll: ->
    @expandSelectionsForward (selection) => selection.selectAll()

  # Public: Selects all the text from all local cursors to the bottom of the
  # buffer.
  selectToBottom: ->
    @expandSelectionsForward (selection) => selection.selectToBottom()

  # Public: Selects all the text from all local cursors to the beginning of each
  # of their lines.
  selectToBeginningOfLine: ->
    @expandSelectionsBackward (selection) => selection.selectToBeginningOfLine()

  # Public: Selects to the first non-whitespace character of the line of all
  # local cursors.
  selectToFirstCharacterOfLine: ->
    @expandSelectionsBackward (selection) => selection.selectToFirstCharacterOfLine()

  # Public: Selects all the text from each local cursor to the end of their
  # lines.
  selectToEndOfLine: ->
    @expandSelectionsForward (selection) => selection.selectToEndOfLine()

  # Public: Selects all text from each local cursor to their previous word
  # boundary.
  selectToPreviousWordBoundary: ->
    @expandSelectionsBackward (selection) => selection.selectToPreviousWordBoundary()

  # Public: Selects all text from each local cursor to their next word
  # boundary.
  selectToNextWordBoundary: ->
    @expandSelectionsForward (selection) => selection.selectToNextWordBoundary()

  # Public: Selects the current line from each local cursor.
  selectLine: ->
    @expandSelectionsForward (selection) => selection.selectLine()

  # Public: Moves each local selection down one row.
  addSelectionBelow: ->
    @expandSelectionsForward (selection) => selection.addSelectionBelow()

  # Public: Moves each local selection up one row.
  addSelectionAbove: ->
    @expandSelectionsBackward (selection) => selection.addSelectionAbove()

  # Public: Transposes the current text selections.
  #
  # FIXME: I have no idea what this function does.
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

  # Public: Uppercases all locally selected text.
  upperCase: ->
    @replaceSelectedText selectWordIfEmpty:true, (text) => text.toUpperCase()

  # Public: Lowercases all locally selected text.
  lowerCase: ->
    @replaceSelectedText selectWordIfEmpty:true, (text) => text.toLowerCase()

  # Public: Joins the current line with the one below it.
  #
  # FIXME: Needs more clarity.
  #
  # Multiple cursors are considered equally. If there's a selection in the editor,
  # all the lines are joined together.
  joinLine: ->
    @mutateSelectedText (selection) -> selection.joinLine()

  # {Delegates to: Selection.expandOverLine}
  expandLastSelectionOverLine: ->
    @getLastSelection().expandOverLine()

  # Public: Selects all the text from all local cursors to the beginning of
  # their current words.
  selectToBeginningOfWord: ->
    @expandSelectionsBackward (selection) => selection.selectToBeginningOfWord()

  # Public: Selects all the text from all local cursors to the end of
  # their current words.
  selectToEndOfWord: ->
    @expandSelectionsForward (selection) => selection.selectToEndOfWord()

  # Public: Selects all the text from all local cursors to the beginning of
  # the next word.
  selectToBeginningOfNextWord: ->
    @expandSelectionsForward (selection) => selection.selectToBeginningOfNextWord()

  # Public: Selects the current word of each local cursor.
  selectWord: ->
    @expandSelectionsForward (selection) => selection.selectWord()

  # {Delegates to: Selection.expandOverWord}
  expandLastSelectionOverWord: ->
    @getLastSelection().expandOverWord()

  # Public: Selects the range associated with the given marker if it is valid.
  #
  # Returns the selected {Range} or a falsy value if the marker is invalid.
  selectMarker: (marker) ->
    if marker.isValid()
      range = marker.getBufferRange()
      @setSelectedBufferRange(range)
      range

  # Public:
  #
  # FIXME: Not sure how to describe what this does.
  mergeCursors: ->
    positions = []
    for cursor in @getCursors()
      position = cursor.getBufferPosition().toString()
      if position in positions
        cursor.destroy()
      else
        positions.push(position)

  # Public:
  #
  # FIXME: Not sure how to describe what this does.
  expandSelectionsForward: (fn) ->
    @mergeIntersectingSelections =>
      fn(selection) for selection in @getSelections()

  # Public:
  #
  # FIXME: Not sure how to describe what this does.
  expandSelectionsBackward: (fn) ->
    @mergeIntersectingSelections isReversed: true, =>
      fn(selection) for selection in @getSelections()

  # Public:
  #
  # FIXME: No idea what this does.
  finalizeSelections: ->
    selection.finalize() for selection in @getSelections()

  # Private: Merges intersecting selections. If passed a function, it executes
  # the function with merging suppressed, then merges intersecting selections
  # afterward.
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

  # Private:
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

  # Private:
  shouldAutoIndent: ->
    config.get("editor.autoIndent")

  # Public: Performs all editor actions from the given function within a single
  # undo step.
  #
  # Useful for implementing complex operations while still ensuring that the
  # undo stack remains relevant.
  transact: (fn) -> @buffer.transact(fn)

  # Private:
  beginTransaction: -> @buffer.beginTransaction()

  # Private:
  commitTransaction: -> @buffer.commitTransaction()

  # Private:
  abortTransaction: -> @buffer.abortTransaction()

  # Private:
  inspect: ->
    JSON.stringify @state.toObject()

  # Private:
  logScreenLines: (start, end) -> @displayBuffer.logLines(start, end)

  # Private:
  handleGrammarChange: ->
    @unfoldAll()
    @emit 'grammar-changed'

  # Private:
  handleMarkerCreated: (marker) =>
    if marker.matchesAttributes(@getSelectionMarkerAttributes())
      @addSelection(marker)

  # Private:
  getSelectionMarkerAttributes: ->
    type: 'selection', editSessionId: @id, invalidation: 'never'

  # Private:
  getDebugSnapshot: ->
    [
      @displayBuffer.getDebugSnapshot()
      @displayBuffer.tokenizedBuffer.getDebugSnapshot()
    ].join('\n\n')
