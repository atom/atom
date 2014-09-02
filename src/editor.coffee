_ = require 'underscore-plus'
path = require 'path'
Serializable = require 'serializable'
Delegator = require 'delegato'
{deprecate} = require 'grim'
{Model} = require 'theorist'
{Point, Range} = require 'text-buffer'
LanguageMode = require './language-mode'
DisplayBuffer = require './display-buffer'
Cursor = require './cursor'
Selection = require './selection'
TextMateScopeSelector = require('first-mate').ScopeSelector

# Public: This class represents all essential editing state for a single
# {TextBuffer}, including cursor and selection positions, folds, and soft wraps.
# If you're manipulating the state of an editor, use this class. If you're
# interested in the visual appearance of editors, use {EditorView} instead.
#
# A single {TextBuffer} can belong to multiple editors. For example, if the
# same file is open in two different panes, Atom creates a separate editor for
# each pane. If the buffer is manipulated the changes are reflected in both
# editors, but each maintains its own cursor position, folded lines, etc.
#
# ## Accessing Editor Instances
#
# The easiest way to get hold of `Editor` objects is by registering a callback
# with `::eachEditor` on the `atom.workspace` global. Your callback will then
# be called with all current editor instances and also when any editor is
# created in the future.
#
# ```coffee
# atom.workspace.eachEditor (editor) ->
#   editor.insertText('Hello World')
# ```
#
# ## Buffer vs. Screen Coordinates
#
# Because editors support folds and soft-wrapping, the lines on screen don't
# always match the lines in the buffer. For example, a long line that soft wraps
# twice renders as three lines on screen, but only represents one line in the
# buffer. Similarly, if rows 5-10 are folded, then row 6 on screen corresponds
# to row 11 in the buffer.
#
# Your choice of coordinates systems will depend on what you're trying to
# achieve. For example, if you're writing a command that jumps the cursor up or
# down by 10 lines, you'll want to use screen coordinates because the user
# probably wants to skip lines *on screen*. However, if you're writing a package
# that jumps between method definitions, you'll want to work in buffer
# coordinates.
#
# **When in doubt, just default to buffer coordinates**, then experiment with
# soft wraps and folds to ensure your code interacts with them correctly.
#
# ## Events
#
# ### path-changed
#
# Essential: Emit when the buffer's path, and therefore title, has changed.
#
# ### title-changed
#
# Essential: Emit when the buffer's path, and therefore title, has changed.
#
# ### modified-status-changed
#
# Extended: Emit when the result of {::isModified} changes.
#
# ### soft-wrap-changed
#
# Extended: Emit when soft wrap was enabled or disabled.
#
# * `softWrap` {Boolean} indicating whether soft wrap is enabled or disabled.
#
# ### grammar-changed
#
# Extended: Emit when the grammar that interprets and colorizes the text has
# been changed.
#
#
#
# ### contents-modified
#
# Essential: Emit when the buffer's contents change. It is emit asynchronously
# 300ms after the last buffer change. This is a good place to handle changes to
# the buffer without compromising typing performance.
#
# ### contents-conflicted
#
# Extended: Emitted when the buffer's underlying file changes on disk at a
# moment when the result of {::isModified} is true.
#
# ### will-insert-text
#
# Extended: Emit before the text has been inserted.
#
# * `event` event {Object}
#   * `text` {String} text to be inserted
#   * `cancel` {Function} Call to prevent the text from being inserted
#
# ### did-insert-text
#
# Extended: Emit after the text has been inserted.
#
# * `event` event {Object}
#   * `text` {String} text to be inserted
#
#
#
# ### cursor-moved
#
# Essential: Emit when a cursor has been moved. If there are multiple cursors,
# it will be emit for each cursor.
#
# * `event` {Object}
#   * `oldBufferPosition` {Point}
#   * `oldScreenPosition` {Point}
#   * `newBufferPosition` {Point}
#   * `newScreenPosition` {Point}
#   * `textChanged` {Boolean}
#
# ### cursor-added
#
# Extended: Emit when a cursor has been added.
#
# * `cursor` {Cursor} that was added
#
# ### cursor-removed
#
# Extended: Emit when a cursor has been removed.
#
# * `cursor` {Cursor} that was removed
#
#
#
# ### selection-screen-range-changed
#
# Essential: Emit when a selection's screen range changes.
#
# * `selection`: {Selection} object that has a changed range
#
# ### selection-added
#
# Extended: Emit when a selection's was added.
#
# * `selection`: {Selection} object that was added
#
# ### selection-removed
#
# Extended: Emit when a selection's was removed.
#
# * `selection`: {Selection} object that was removed
#
#
#
# ### decoration-added
#
# Extended: Emit when a {Decoration} is added to the editor.
#
# * `decoration` {Decoration} that was added
#
# ### decoration-removed
#
# Extended: Emit when a {Decoration} is removed from the editor.
#
# * `decoration` {Decoration} that was removed
#
# ### decoration-changed
#
# Extended: Emit when a {Decoration}'s underlying marker changes. Say the user
# inserts newlines above a decoration. That action will move the marker down,
# and fire this event.
#
# * `decoration` {Decoration} that was added
#
# ### decoration-updated
#
# Extended: Emit when a {Decoration} is updated via the {Decoration::update} method.
#
# * `decoration` {Decoration} that was updated
#
module.exports =
class Editor extends Model
  Serializable.includeInto(this)
  atom.deserializers.add(this)
  Delegator.includeInto(this)

  deserializing: false
  callDisplayBufferCreatedHook: false
  registerEditor: false
  buffer: null
  languageMode: null
  cursors: null
  selections: null
  suppressSelectionMerging: false
  updateBatchDepth: 0
  selectionFlashDuration: 500

  @delegatesMethods 'suggestedIndentForBufferRow', 'autoIndentBufferRow', 'autoIndentBufferRows',
    'autoDecreaseIndentForBufferRow', 'toggleLineCommentForBufferRow', 'toggleLineCommentsForBufferRows',
    toProperty: 'languageMode'

  @delegatesProperties '$lineHeightInPixels', '$defaultCharWidth', '$height', '$width',
    '$verticalScrollbarWidth', '$horizontalScrollbarHeight', '$scrollTop', '$scrollLeft',
    'manageScrollPosition', toProperty: 'displayBuffer'

  constructor: ({@softTabs, initialLine, initialColumn, tabLength, softWrap, @displayBuffer, buffer, registerEditor, suppressCursorCreation, @mini}) ->
    super

    @cursors = []
    @selections = []

    if @shouldShowInvisibles()
      invisibles = atom.config.get('editor.invisibles')

    @displayBuffer?.setInvisibles(invisibles)
    @displayBuffer ?= new DisplayBuffer({buffer, tabLength, softWrap, invisibles})
    @buffer = @displayBuffer.buffer
    @softTabs = @usesSoftTabs() ? @softTabs ? atom.config.get('editor.softTabs') ? true

    for marker in @findMarkers(@getSelectionMarkerAttributes())
      marker.setAttributes(preserveFolds: true)
      @addSelection(marker)

    @subscribeToBuffer()
    @subscribeToDisplayBuffer()

    if @getCursors().length is 0 and not suppressCursorCreation
      initialLine = Math.max(parseInt(initialLine) or 0, 0)
      initialColumn = Math.max(parseInt(initialColumn) or 0, 0)
      @addCursorAtBufferPosition([initialLine, initialColumn])

    @languageMode = new LanguageMode(this)

    @subscribe @$scrollTop, (scrollTop) => @emit 'scroll-top-changed', scrollTop
    @subscribe @$scrollLeft, (scrollLeft) => @emit 'scroll-left-changed', scrollLeft

    @subscribe atom.config.observe 'editor.showInvisibles', callNow: false, (show) => @updateInvisibles()
    @subscribe atom.config.observe 'editor.invisibles', callNow: false, => @updateInvisibles()

    atom.workspace?.editorAdded(this) if registerEditor

  serializeParams: ->
    id: @id
    softTabs: @softTabs
    scrollTop: @scrollTop
    scrollLeft: @scrollLeft
    displayBuffer: @displayBuffer.serialize()

  deserializeParams: (params) ->
    params.displayBuffer = DisplayBuffer.deserialize(params.displayBuffer)
    params.registerEditor = true
    params

  subscribeToBuffer: ->
    @buffer.retain()
    @subscribe @buffer, "path-changed", =>
      unless atom.project.getPath()?
        atom.project.setPath(path.dirname(@getPath()))
      @emit "title-changed"
      @emit "path-changed"
    @subscribe @buffer, "contents-modified", => @emit "contents-modified"
    @subscribe @buffer, "contents-conflicted", => @emit "contents-conflicted"
    @subscribe @buffer, "modified-status-changed", => @emit "modified-status-changed"
    @subscribe @buffer, "destroyed", => @destroy()
    @preserveCursorPositionOnBufferReload()

  subscribeToDisplayBuffer: ->
    @subscribe @displayBuffer, 'marker-created', @handleMarkerCreated
    @subscribe @displayBuffer, "changed", (e) => @emit 'screen-lines-changed', e
    @subscribe @displayBuffer, "markers-updated", => @mergeIntersectingSelections()
    @subscribe @displayBuffer, 'grammar-changed', => @handleGrammarChange()
    @subscribe @displayBuffer, 'tokenized', => @handleTokenization()
    @subscribe @displayBuffer, 'soft-wrap-changed', (args...) => @emit 'soft-wrap-changed', args...
    @subscribe @displayBuffer, "decoration-added", (args...) => @emit 'decoration-added', args...
    @subscribe @displayBuffer, "decoration-removed", (args...) => @emit 'decoration-removed', args...
    @subscribe @displayBuffer, "decoration-changed", (args...) => @emit 'decoration-changed', args...
    @subscribe @displayBuffer, "decoration-updated", (args...) => @emit 'decoration-updated', args...
    @subscribe @displayBuffer, "character-widths-changed", (changeCount) => @emit 'character-widths-changed', changeCount

  getViewClass: ->
    require './editor-view'

  destroyed: ->
    @unsubscribe()
    selection.destroy() for selection in @getSelections()
    @buffer.release()
    @displayBuffer.destroy()
    @languageMode.destroy()

  # Retrieves the current {TextBuffer}.
  getBuffer: -> @buffer

  # Retrieves the current buffer's URI.
  getUri: -> @buffer.getUri()

  # Create an {Editor} with its initial state based on this object
  copy: ->
    tabLength = @getTabLength()
    displayBuffer = @displayBuffer.copy()
    softTabs = @getSoftTabs()
    newEditor = new Editor({@buffer, displayBuffer, tabLength, softTabs, suppressCursorCreation: true, registerEditor: true})
    for marker in @findMarkers(editorId: @id)
      marker.copy(editorId: newEditor.id, preserveFolds: true)
    newEditor

  # Controls visibility based on the given {Boolean}.
  setVisible: (visible) -> @displayBuffer.setVisible(visible)

  setMini: (mini) ->
    if mini isnt @mini
      @mini = mini
      @updateInvisibles()

  # Set the number of characters that can be displayed horizontally in the
  # editor.
  #
  # * `editorWidthInChars` A {Number} representing the width of the {EditorView}
  # in characters.
  setEditorWidthInChars: (editorWidthInChars) ->
    @displayBuffer.setEditorWidthInChars(editorWidthInChars)

  ###
  Section: File Details
  ###

  # Public: Get the title the editor's title for display in other parts of the
  # UI such as the tabs.
  #
  # If the editor's buffer is saved, its title is the file name. If it is
  # unsaved, its title is "untitled".
  #
  # Returns a {String}.
  getTitle: ->
    if sessionPath = @getPath()
      path.basename(sessionPath)
    else
      'untitled'

  # Public: Get the editor's long title for display in other parts of the UI
  # such as the window title.
  #
  # If the editor's buffer is saved, its long title is formatted as
  # "<filename> - <directory>". If it is unsaved, its title is "untitled"
  #
  # Returns a {String}.
  getLongTitle: ->
    if sessionPath = @getPath()
      fileName = path.basename(sessionPath)
      directory = atom.project.relativize(path.dirname(sessionPath))
      directory = if directory.length > 0 then directory else path.basename(path.dirname(sessionPath))
      "#{fileName} - #{directory}"
    else
      'untitled'

  # Public: Returns the {String} path of this editor's text buffer.
  getPath: -> @buffer.getPath()

  # Public: Saves the editor's text buffer.
  #
  # See {TextBuffer::save} for more details.
  save: -> @buffer.save()

  # Public: Saves the editor's text buffer as the given path.
  #
  # See {TextBuffer::saveAs} for more details.
  #
  # * `filePath` A {String} path.
  saveAs: (filePath) -> @buffer.saveAs(filePath)

  # Public: Determine whether the user should be prompted to save before closing
  # this editor.
  shouldPromptToSave: -> @isModified() and not @buffer.hasMultipleEditors()

  # Public: Returns {Boolean} `true` if this editor has been modified.
  isModified: -> @buffer.isModified()

  isEmpty: -> @buffer.isEmpty()

  # Copies the current file path to the native clipboard.
  copyPathToClipboard: ->
    if filePath = @getPath()
      atom.clipboard.write(filePath)

  ###
  Section: Reading Text
  ###

  # Public: Returns a {String} representing the entire contents of the editor.
  getText: -> @buffer.getText()

  # Public: Get the text in the given {Range} in buffer coordinates.
  #
  # * `range` A {Range} or range-compatible {Array}.
  #
  # Returns a {String}.
  getTextInBufferRange: (range) ->
    @buffer.getTextInRange(range)

  # Public: Returns a {Number} representing the number of lines in the editor.
  getLineCount: -> @buffer.getLineCount()

  # {Delegates to: DisplayBuffer.getLineCount}
  getScreenLineCount: -> @displayBuffer.getLineCount()

  # Public: Returns a {Number} representing the last zero-indexed buffer row
  # number of the editor.
  getLastBufferRow: -> @buffer.getLastRow()

  # {Delegates to: DisplayBuffer.getLastRow}
  getLastScreenRow: -> @displayBuffer.getLastRow()

  # Public: Returns a {String} representing the contents of the line at the
  # given buffer row.
  #
  # * `row` A {Number} representing a zero-indexed buffer row.
  lineForBufferRow: (row) -> @buffer.lineForRow(row)

  # {Delegates to: DisplayBuffer.lineForRow}
  lineForScreenRow: (row) -> @displayBuffer.lineForRow(row)

  # {Delegates to: DisplayBuffer.linesForRows}
  linesForScreenRows: (start, end) -> @displayBuffer.linesForRows(start, end)

  # Public: Returns a {Number} representing the line length for the given
  # buffer row, exclusive of its line-ending character(s).
  #
  # * `row` A {Number} indicating the buffer row.
  lineLengthForBufferRow: (row) -> @buffer.lineLengthForRow(row)

  bufferRowForScreenRow: (row) -> @displayBuffer.bufferRowForScreenRow(row)

  # {Delegates to: DisplayBuffer.bufferRowsForScreenRows}
  bufferRowsForScreenRows: (startRow, endRow) -> @displayBuffer.bufferRowsForScreenRows(startRow, endRow)

  # {Delegates to: DisplayBuffer.getMaxLineLength}
  getMaxScreenLineLength: -> @displayBuffer.getMaxLineLength()

  # Returns the range for the given buffer row.
  #
  # * `row` A row {Number}.
  # * `options` (optional) An options hash with an `includeNewline` key.
  #
  # Returns a {Range}.
  bufferRangeForBufferRow: (row, {includeNewline}={}) -> @buffer.rangeForRow(row, includeNewline)

  # Get the text in the given {Range}.
  #
  # Returns a {String}.
  getTextInRange: (range) -> @buffer.getTextInRange(range)

  # {Delegates to: TextBuffer.isRowBlank}
  isBufferRowBlank: (bufferRow) -> @buffer.isRowBlank(bufferRow)

  # {Delegates to: TextBuffer.nextNonBlankRow}
  nextNonBlankBufferRow: (bufferRow) -> @buffer.nextNonBlankRow(bufferRow)

  # {Delegates to: TextBuffer.getEndPosition}
  getEofBufferPosition: -> @buffer.getEndPosition()

  # Public: Get the {Range} of the paragraph surrounding the most recently added
  # cursor.
  #
  # Returns a {Range}.
  getCurrentParagraphBufferRange: ->
    @getCursor().getCurrentParagraphBufferRange()


  ###
  Section: Mutating Text
  ###

  # Public: Replaces the entire contents of the buffer with the given {String}.
  setText: (text) -> @buffer.setText(text)

  # Public: Set the text in the given {Range} in buffer coordinates.
  #
  # * `range` A {Range} or range-compatible {Array}.
  # * `text` A {String}
  #
  # Returns the {Range} of the newly-inserted text.
  setTextInBufferRange: (range, text, normalizeLineEndings) -> @getBuffer().setTextInRange(range, text, normalizeLineEndings)

  # Public: Mutate the text of all the selections in a single transaction.
  #
  # All the changes made inside the given {Function} can be reverted with a
  # single call to {::undo}.
  #
  # * `fn` A {Function} that will be called once for each {Selection}. The first
  #      argument will be a {Selection} and the second argument will be the
  #      {Number} index of that selection.
  mutateSelectedText: (fn) ->
    @transact => fn(selection, index) for selection, index in @getSelections()

  # Move lines intersection the most recent selection up by one row in screen
  # coordinates.
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

      # Move line around the fold that is directly above the selection
      precedingScreenRow = @screenPositionForBufferPosition([selection.start.row]).translate([-1])
      precedingBufferRow = @bufferPositionForScreenPosition(precedingScreenRow).row
      if fold = @largestFoldContainingBufferRow(precedingBufferRow)
        insertDelta = fold.getBufferRange().getRowCount()
      else
        insertDelta = 1

      for row in rows
        if fold = @displayBuffer.largestFoldStartingAtBufferRow(row)
          bufferRange = fold.getBufferRange()
          startRow = bufferRange.start.row
          endRow = bufferRange.end.row
          foldedRows.push(startRow - insertDelta)
        else
          startRow = row
          endRow = row

        insertPosition = Point.fromObject([startRow - insertDelta])
        endPosition = Point.min([endRow + 1], @buffer.getEndPosition())
        lines = @buffer.getTextInRange([[startRow], endPosition])
        if endPosition.row is lastRow and endPosition.column > 0 and not @buffer.lineEndingForRow(endPosition.row)
          lines = "#{lines}\n"

        @buffer.deleteRows(startRow, endRow)

        # Make sure the inserted text doesn't go into an existing fold
        if fold = @displayBuffer.largestFoldStartingAtBufferRow(insertPosition.row)
          @unfoldBufferRow(insertPosition.row)
          foldedRows.push(insertPosition.row + endRow - startRow + fold.getBufferRange().getRowCount())

        @buffer.insert(insertPosition, lines)

      # Restore folds that existed before the lines were moved
      for foldedRow in foldedRows when 0 <= foldedRow <= @getLastBufferRow()
        @foldBufferRow(foldedRow)

      @setSelectedBufferRange(selection.translate([-insertDelta]), preserveFolds: true, autoscroll: true)

  # Move lines intersecting the most recent selection down by one row in screen
  # coordinates.
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

      # Move line around the fold that is directly below the selection
      followingScreenRow = @screenPositionForBufferPosition([selection.end.row]).translate([1])
      followingBufferRow = @bufferPositionForScreenPosition(followingScreenRow).row
      if fold = @largestFoldContainingBufferRow(followingBufferRow)
        insertDelta = fold.getBufferRange().getRowCount()
      else
        insertDelta = 1

      for row in rows
        if fold = @displayBuffer.largestFoldStartingAtBufferRow(row)
          bufferRange = fold.getBufferRange()
          startRow = bufferRange.start.row
          endRow = bufferRange.end.row
          foldedRows.push(endRow + insertDelta)
        else
          startRow = row
          endRow = row

        if endRow + 1 is lastRow
          endPosition = [endRow, @buffer.lineLengthForRow(endRow)]
        else
          endPosition = [endRow + 1]
        lines = @buffer.getTextInRange([[startRow], endPosition])
        @buffer.deleteRows(startRow, endRow)

        insertPosition = Point.min([startRow + insertDelta], @buffer.getEndPosition())
        if insertPosition.row is @buffer.getLastRow() and insertPosition.column > 0
          lines = "\n#{lines}"

        # Make sure the inserted text doesn't go into an existing fold
        if fold = @displayBuffer.largestFoldStartingAtBufferRow(insertPosition.row)
          @unfoldBufferRow(insertPosition.row)
          foldedRows.push(insertPosition.row + fold.getBufferRange().getRowCount())

        @buffer.insert(insertPosition, lines)

      # Restore folds that existed before the lines were moved
      for foldedRow in foldedRows when 0 <= foldedRow <= @getLastBufferRow()
        @foldBufferRow(foldedRow)

      @setSelectedBufferRange(selection.translate([insertDelta]), preserveFolds: true, autoscroll: true)

  # Duplicate the most recent cursor's current line.
  duplicateLines: ->
    @transact =>
      for selection in @getSelectionsOrderedByBufferPosition().reverse()
        selectedBufferRange = selection.getBufferRange()
        if selection.isEmpty()
          {start} = selection.getScreenRange()
          selection.selectToScreenPosition([start.row + 1, 0])

        [startRow, endRow] = selection.getBufferRowRange()
        endRow++

        foldedRowRanges =
          @outermostFoldsInBufferRowRange(startRow, endRow)
            .map (fold) -> fold.getBufferRowRange()

        rangeToDuplicate = [[startRow, 0], [endRow, 0]]
        textToDuplicate = @getTextInBufferRange(rangeToDuplicate)
        textToDuplicate = '\n' + textToDuplicate if endRow > @getLastBufferRow()
        @buffer.insert([endRow, 0], textToDuplicate)

        delta = endRow - startRow
        selection.setBufferRange(selectedBufferRange.translate([delta, 0]))
        for [foldStartRow, foldEndRow] in foldedRowRanges
          @createFold(foldStartRow + delta, foldEndRow + delta)

  # Deprecated: Use {::duplicateLines} instead.
  duplicateLine: ->
    deprecate("Use Editor::duplicateLines() instead")
    @duplicateLines()

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

  # Public: Split multi-line selections into one selection per line.
  #
  # Operates on all selections. This method breaks apart all multi-line
  # selections to create multiple single-line selections that cumulatively cover
  # the same original area.
  splitSelectionsIntoLines: ->
    for selection in @getSelections()
      range = selection.getBufferRange()
      continue if range.isSingleLine()

      selection.destroy()
      {start, end} = range
      @addSelectionForBufferRange([start, [start.row, Infinity]])
      {row} = start
      while ++row < end.row
        @addSelectionForBufferRange([[row, 0], [row, Infinity]])
      @addSelectionForBufferRange([[end.row, 0], [end.row, end.column]]) unless end.column is 0

  # Public: For each selection, transpose the selected text.
  #
  # If the selection is empty, the characters preceding and following the cursor
  # are swapped. Otherwise, the selected characters are reversed.
  transpose: ->
    @mutateSelectedText (selection) ->
      if selection.isEmpty()
        selection.selectRight()
        text = selection.getText()
        selection.delete()
        selection.cursor.moveLeft()
        selection.insertText text
      else
        selection.insertText selection.getText().split('').reverse().join('')

  # Public: Convert the selected text to upper case.
  #
  # For each selection, if the selection is empty, converts the containing word
  # to upper case. Otherwise convert the selected text to upper case.
  upperCase: ->
    @replaceSelectedText selectWordIfEmpty:true, (text) -> text.toUpperCase()

  # Public: Convert the selected text to lower case.
  #
  # For each selection, if the selection is empty, converts the containing word
  # to upper case. Otherwise convert the selected text to upper case.
  lowerCase: ->
    @replaceSelectedText selectWordIfEmpty:true, (text) -> text.toLowerCase()

  # Convert multiple lines to a single line.
  #
  # Operates on all selections. If the selection is empty, joins the current
  # line with the next line. Otherwise it joins all lines that intersect the
  # selection.
  #
  # Joining a line means that multiple lines are converted to a single line with
  # the contents of each of the original non-empty lines separated by a space.
  joinLines: ->
    @mutateSelectedText (selection) -> selection.joinLines()

  ###
  Section: Adding Text
  ###

  # Public: For each selection, replace the selected text with the given text.
  #
  # * `text` A {String} representing the text to insert.
  # * `options` (optional) See {Selection::insertText}.
  #
  # Returns a {Range} when the text has been inserted
  # Returns a {Bool} false when the text has not been inserted
  insertText: (text, options={}) ->
    willInsert = true
    cancel = -> willInsert = false
    @emit('will-insert-text', {cancel, text})

    if willInsert
      options.autoIndentNewline ?= @shouldAutoIndent()
      options.autoDecreaseIndent ?= @shouldAutoIndent()
      @mutateSelectedText (selection) =>
        range = selection.insertText(text, options)
        @emit('did-insert-text', {text, range})
        range
    else
      false

  # Public: For each selection, replace the selected text with a newline.
  insertNewline: ->
    @insertText('\n')

  # Public: For each cursor, insert a newline at beginning the following line.
  insertNewlineBelow: ->
    @transact =>
      @moveCursorToEndOfLine()
      @insertNewline()

  # Public: For each cursor, insert a newline at the end of the preceding line.
  insertNewlineAbove: ->
    @transact =>
      bufferRow = @getCursorBufferPosition().row
      indentLevel = @indentationForBufferRow(bufferRow)
      onFirstLine = bufferRow is 0

      @moveCursorToBeginningOfLine()
      @moveCursorLeft()
      @insertNewline()

      if @shouldAutoIndent() and @indentationForBufferRow(bufferRow) < indentLevel
        @setIndentationForBufferRow(bufferRow, indentLevel)

      if onFirstLine
        @moveCursorUp()
        @moveCursorToEndOfLine()

  ###
  Section: Removing Text
  ###

  # Public: For each selection, if the selection is empty, delete the character
  # preceding the cursor. Otherwise delete the selected text.
  backspace: ->
    @mutateSelectedText (selection) -> selection.backspace()

  # Deprecated: Use {::deleteToBeginningOfWord} instead.
  backspaceToBeginningOfWord: ->
    deprecate("Use Editor::deleteToBeginningOfWord() instead")
    @deleteToBeginningOfWord()

  # Deprecated: Use {::deleteToBeginningOfLine} instead.
  backspaceToBeginningOfLine: ->
    deprecate("Use Editor::deleteToBeginningOfLine() instead")
    @deleteToBeginningOfLine()

  # Public: For each selection, if the selection is empty, delete all characters
  # of the containing word that precede the cursor. Otherwise delete the
  # selected text.
  deleteToBeginningOfWord: ->
    @mutateSelectedText (selection) -> selection.deleteToBeginningOfWord()

  # Public: For each selection, if the selection is empty, delete all characters
  # of the containing line that precede the cursor. Otherwise delete the
  # selected text.
  deleteToBeginningOfLine: ->
    @mutateSelectedText (selection) -> selection.deleteToBeginningOfLine()

  # Public: For each selection, if the selection is empty, delete the character
  # preceding the cursor. Otherwise delete the selected text.
  delete: ->
    @mutateSelectedText (selection) -> selection.delete()

  # Public: For each selection, if the selection is not empty, deletes the
  # selection; otherwise, deletes all characters of the containing line
  # following the cursor. If the cursor is already at the end of the line,
  # deletes the following newline.
  deleteToEndOfLine: ->
    @mutateSelectedText (selection) -> selection.deleteToEndOfLine()

  # Public: For each selection, if the selection is empty, delete all characters
  # of the containing word following the cursor. Otherwise delete the selected
  # text.
  deleteToEndOfWord: ->
    @mutateSelectedText (selection) -> selection.deleteToEndOfWord()

  # Public: Delete all lines intersecting selections.
  deleteLine: ->
    @mutateSelectedText (selection) -> selection.deleteLine()

  ###
  Section: Searching Text
  ###

  # {Delegates to: TextBuffer.scan}
  scan: (args...) -> @buffer.scan(args...)

  # {Delegates to: TextBuffer.scanInRange}
  scanInBufferRange: (args...) -> @buffer.scanInRange(args...)

  # {Delegates to: TextBuffer.backwardsScanInRange}
  backwardsScanInBufferRange: (args...) -> @buffer.backwardsScanInRange(args...)


  ###
  Section: Tab Behavior
  ###

  # Public: Determine if the buffer uses hard or soft tabs.
  #
  # Returns `true` if the first non-comment line with leading whitespace starts
  # with a space character. Returns `false` if it starts with a hard tab (`\t`).
  #
  # Returns a {Boolean} or undefined if no non-comment lines had leading
  # whitespace.
  usesSoftTabs: ->
    for bufferRow in [0..@buffer.getLastRow()]
      continue if @displayBuffer.tokenizedBuffer.lineForScreenRow(bufferRow).isComment()

      line = @buffer.lineForRow(bufferRow)
      return true  if line[0] is ' '
      return false if line[0] is '\t'

    undefined

  # Public: Returns a {Boolean} indicating whether softTabs are enabled for this
  # editor.
  getSoftTabs: -> @softTabs

  # Public: Enable or disable soft tabs for this editor.
  #
  # * `softTabs` A {Boolean}
  setSoftTabs: (@softTabs) -> @softTabs

  # Public: Toggle soft tabs for this editor
  toggleSoftTabs: -> @setSoftTabs(not @getSoftTabs())

  # Public: Get the text representing a single level of indent.
  #
  # If soft tabs are enabled, the text is composed of N spaces, where N is the
  # tab length. Otherwise the text is a tab character (`\t`).
  #
  # Returns a {String}.
  getTabText: -> @buildIndentString(1)

  # Public: Get the on-screen length of tab characters.
  #
  # Returns a {Number}.
  getTabLength: -> @displayBuffer.getTabLength()

  # Public: Set the on-screen length of tab characters.
  setTabLength: (tabLength) -> @displayBuffer.setTabLength(tabLength)

  # If soft tabs are enabled, convert all hard tabs to soft tabs in the given
  # {Range}.
  normalizeTabsInBufferRange: (bufferRange) ->
    return unless @getSoftTabs()
    @scanInBufferRange /\t/g, bufferRange, ({replace}) => replace(@getTabText())

  ###
  Section: Soft Wrap Behavior
  ###

  # Public: Sets the column at which column will soft wrap
  getSoftWrapColumn: -> @displayBuffer.getSoftWrapColumn()

  # Public: Get whether soft wrap is enabled for this editor.
  getSoftWrap: -> @displayBuffer.getSoftWrap()

  # Public: Enable or disable soft wrap for this editor.
  #
  # * `softWrap` A {Boolean}
  setSoftWrap: (softWrap) -> @displayBuffer.setSoftWrap(softWrap)

  # Public: Toggle soft wrap for this editor
  toggleSoftWrap: -> @setSoftWrap(not @getSoftWrap())



  ###
  Section: Indentation
  ###

  # Public: Get the indentation level of the given a buffer row.
  #
  # Returns how deeply the given row is indented based on the soft tabs and
  # tab length settings of this editor. Note that if soft tabs are enabled and
  # the tab length is 2, a row with 4 leading spaces would have an indentation
  # level of 2.
  #
  # * `bufferRow` A {Number} indicating the buffer row.
  #
  # Returns a {Number}.
  indentationForBufferRow: (bufferRow) ->
    @indentLevelForLine(@lineForBufferRow(bufferRow))

  # Public: Set the indentation level for the given buffer row.
  #
  # Inserts or removes hard tabs or spaces based on the soft tabs and tab length
  # settings of this editor in order to bring it to the given indentation level.
  # Note that if soft tabs are enabled and the tab length is 2, a row with 4
  # leading spaces would have an indentation level of 2.
  #
  # * `bufferRow` A {Number} indicating the buffer row.
  # * `newLevel` A {Number} indicating the new indentation level.
  # * `options` (optional) An {Object} with the following keys:
  #   * `preserveLeadingWhitespace` `true` to preserve any whitespace already at
  #      the beginning of the line (default: false).
  setIndentationForBufferRow: (bufferRow, newLevel, {preserveLeadingWhitespace}={}) ->
    if preserveLeadingWhitespace
      endColumn = 0
    else
      endColumn = @lineForBufferRow(bufferRow).match(/^\s*/)[0].length
    newIndentString = @buildIndentString(newLevel)
    @buffer.setTextInRange([[bufferRow, 0], [bufferRow, endColumn]], newIndentString)

  # Public: Get the indentation level of the given line of text.
  #
  # Returns how deeply the given line is indented based on the soft tabs and
  # tab length settings of this editor. Note that if soft tabs are enabled and
  # the tab length is 2, a row with 4 leading spaces would have an indentation
  # level of 2.
  #
  # * `line` A {String} representing a line of text.
  #
  # Returns a {Number}.
  indentLevelForLine: (line) ->
    @displayBuffer.indentLevelForLine(line)

  # Indent all lines intersecting selections. See {Selection::indent} for more
  # information.
  indent: (options={}) ->
    options.autoIndent ?= @shouldAutoIndent()
    @mutateSelectedText (selection) -> selection.indent(options)

  # Public: Indent rows intersecting selections by one level.
  indentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.indentSelectedRows()

  # Public: Outdent rows intersecting selections by one level.
  outdentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.outdentSelectedRows()

  # Public: Indent rows intersecting selections based on the grammar's suggested
  # indent level.
  autoIndentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.autoIndentSelectedRows()

  # Constructs the string used for tabs.
  buildIndentString: (number, column=0) ->
    if @getSoftTabs()
      tabStopViolation = column % @getTabLength()
      _.multiplyString(" ", Math.floor(number * @getTabLength()) - tabStopViolation)
    else
      _.multiplyString("\t", Math.floor(number))

  ###
  Section: Undo Operations
  ###

  # Public: Undo the last change.
  undo: ->
    @getCursor().needsAutoscroll = true
    @buffer.undo(this)

  # Public: Redo the last change.
  redo: ->
    @getCursor().needsAutoscroll = true
    @buffer.redo(this)

  ###
  Section: Text Mutation Transactions
  ###

  # Public: Batch multiple operations as a single undo/redo step.
  #
  # Any group of operations that are logically grouped from the perspective of
  # undoing and redoing should be performed in a transaction. If you want to
  # abort the transaction, call {::abortTransaction} to terminate the function's
  # execution and revert any changes performed up to the abortion.
  #
  # * `fn` A {Function} to call inside the transaction.
  transact: (fn) -> @buffer.transact(fn)

  # Public: Start an open-ended transaction.
  #
  # Call {::commitTransaction} or {::abortTransaction} to terminate the
  # transaction. If you nest calls to transactions, only the outermost
  # transaction is considered. You must match every begin with a matching
  # commit, but a single call to abort will cancel all nested transactions.
  beginTransaction: -> @buffer.beginTransaction()

  # Public: Commit an open-ended transaction started with {::beginTransaction}
  # and push it to the undo stack.
  #
  # If transactions are nested, only the outermost commit takes effect.
  commitTransaction: -> @buffer.commitTransaction()

  # Public: Abort an open transaction, undoing any operations performed so far
  # within the transaction.
  abortTransaction: -> @buffer.abortTransaction()

  ###
  Section: Editor Coordinates
  ###

  # Public: Convert a position in buffer-coordinates to screen-coordinates.
  #
  # The position is clipped via {::clipBufferPosition} prior to the conversion.
  # The position is also clipped via {::clipScreenPosition} following the
  # conversion, which only makes a difference when `options` are supplied.
  #
  # * `bufferPosition` A {Point} or {Array} of [row, column].
  # * `options` (optional) An options hash for {::clipScreenPosition}.
  #
  # Returns a {Point}.
  screenPositionForBufferPosition: (bufferPosition, options) -> @displayBuffer.screenPositionForBufferPosition(bufferPosition, options)

  # Public: Convert a position in screen-coordinates to buffer-coordinates.
  #
  # The position is clipped via {::clipScreenPosition} prior to the conversion.
  #
  # * `bufferPosition` A {Point} or {Array} of [row, column].
  # * `options` (optional) An options hash for {::clipScreenPosition}.
  #
  # Returns a {Point}.
  bufferPositionForScreenPosition: (screenPosition, options) -> @displayBuffer.bufferPositionForScreenPosition(screenPosition, options)

  # Public: Convert a range in buffer-coordinates to screen-coordinates.
  #
  # Returns a {Range}.
  screenRangeForBufferRange: (bufferRange) -> @displayBuffer.screenRangeForBufferRange(bufferRange)

  # Public: Convert a range in screen-coordinates to buffer-coordinates.
  #
  # Returns a {Range}.
  bufferRangeForScreenRange: (screenRange) -> @displayBuffer.bufferRangeForScreenRange(screenRange)

  # Public: Clip the given {Point} to a valid position in the buffer.
  #
  # If the given {Point} describes a position that is actually reachable by the
  # cursor based on the current contents of the buffer, it is returned
  # unchanged. If the {Point} does not describe a valid position, the closest
  # valid position is returned instead.
  #
  # ## Examples
  #
  # ```coffee
  # editor.clipBufferPosition([-1, -1]) # -> `[0, 0]`
  #
  # # When the line at buffer row 2 is 10 characters long
  # editor.clipBufferPosition([2, Infinity]) # -> `[2, 10]`
  # ```
  #
  # * `bufferPosition` The {Point} representing the position to clip.
  #
  # Returns a {Point}.
  clipBufferPosition: (bufferPosition) -> @buffer.clipPosition(bufferPosition)

  # Public: Clip the start and end of the given range to valid positions in the
  # buffer. See {::clipBufferPosition} for more information.
  #
  # * `range` The {Range} to clip.
  #
  # Returns a {Range}.
  clipBufferRange: (range) -> @buffer.clipRange(range)

  # Public: Clip the given {Point} to a valid position on screen.
  #
  # If the given {Point} describes a position that is actually reachable by the
  # cursor based on the current contents of the screen, it is returned
  # unchanged. If the {Point} does not describe a valid position, the closest
  # valid position is returned instead.
  #
  # ## Examples
  #
  # ```coffee
  # editor.clipScreenPosition([-1, -1]) # -> `[0, 0]`
  #
  # # When the line at screen row 2 is 10 characters long
  # editor.clipScreenPosition([2, Infinity]) # -> `[2, 10]`
  # ```
  #
  # * `bufferPosition` The {Point} representing the position to clip.
  #
  # Returns a {Point}.
  clipScreenPosition: (screenPosition, options) -> @displayBuffer.clipScreenPosition(screenPosition, options)




  ###
  Section: Grammars
  ###

  # Public: Get the current {Grammar} of this editor.
  getGrammar: ->
    @displayBuffer.getGrammar()

  # Public: Set the current {Grammar} of this editor.
  #
  # Assigning a grammar will cause the editor to re-tokenize based on the new
  # grammar.
  setGrammar: (grammar) ->
    @displayBuffer.setGrammar(grammar)

  # Reload the grammar based on the file name.
  reloadGrammar: ->
    @displayBuffer.reloadGrammar()

  ###
  Section: Syntatic Queries
  ###

  # Public: Get the syntactic scopes for the given position in buffer
  # coordinates.
  #
  # For example, if called with a position inside the parameter list of an
  # anonymous CoffeeScript function, the method returns the following array:
  # `["source.coffee", "meta.inline.function.coffee", "variable.parameter.function.coffee"]`
  #
  # * `bufferPosition` A {Point} or {Array} of [row, column].
  #
  # Returns an {Array} of {String}s.
  scopesForBufferPosition: (bufferPosition) -> @displayBuffer.scopesForBufferPosition(bufferPosition)

  # Public: Get the range in buffer coordinates of all tokens surrounding the
  # cursor that match the given scope selector.
  #
  # For example, if you wanted to find the string surrounding the cursor, you
  # could call `editor.bufferRangeForScopeAtCursor(".string.quoted")`.
  #
  # Returns a {Range}.
  bufferRangeForScopeAtCursor: (selector) ->
    @displayBuffer.bufferRangeForScopeAtPosition(selector, @getCursorBufferPosition())

  # {Delegates to: DisplayBuffer.tokenForBufferPosition}
  tokenForBufferPosition: (bufferPosition) -> @displayBuffer.tokenForBufferPosition(bufferPosition)

  # Public: Get the syntactic scopes for the most recently added cursor's
  # position. See {::scopesForBufferPosition} for more information.
  #
  # Returns an {Array} of {String}s.
  getCursorScopes: -> @getCursor().getScopes()

  logCursorScope: ->
    console.log @getCursorScopes()


  # Public: Determine if the given row is entirely a comment
  isBufferRowCommented: (bufferRow) ->
    if match = @lineForBufferRow(bufferRow).match(/\S/)
      scopes = @tokenForBufferPosition([bufferRow, match.index]).scopes
      new TextMateScopeSelector('comment.*').matches(scopes)

  # Public: Toggle line comments for rows intersecting selections.
  #
  # If the current grammar doesn't support comments, does nothing.
  #
  # Returns an {Array} of the commented {Range}s.
  toggleLineCommentsInSelection: ->
    @mutateSelectedText (selection) -> selection.toggleLineComments()







  ###
  Section: Clipboard Operations
  ###

  # Public: For each selection, copy the selected text.
  copySelectedText: ->
    maintainClipboard = false
    for selection in @getSelections()
      selection.copy(maintainClipboard)
      maintainClipboard = true

  # Public: For each selection, replace the selected text with the contents of
  # the clipboard.
  #
  # If the clipboard contains the same number of selections as the current
  # editor, each selection will be replaced with the content of the
  # corresponding clipboard selection text.
  #
  # * `options` (optional) See {Selection::insertText}.
  pasteText: (options={}) ->
    {text, metadata} = atom.clipboard.readWithMetadata()

    containsNewlines = text.indexOf('\n') isnt -1

    if metadata?.selections? and metadata.selections.length is @getSelections().length
      @mutateSelectedText (selection, index) ->
        text = metadata.selections[index]
        selection.insertText(text, options)

      return

    else if atom.config.get("editor.normalizeIndentOnPaste") and metadata?.indentBasis?
      if !@getCursor().hasPrecedingCharactersOnLine() or containsNewlines
        options.indentBasis ?= metadata.indentBasis

    @insertText(text, options)

  # Public: For each selection, cut the selected text.
  cutSelectedText: ->
    maintainClipboard = false
    @mutateSelectedText (selection) ->
      selection.cut(maintainClipboard)
      maintainClipboard = true

  # Public: For each selection, if the selection is empty, cut all characters
  # of the containing line following the cursor. Otherwise cut the selected
  # text.
  cutToEndOfLine: ->
    maintainClipboard = false
    @mutateSelectedText (selection) ->
      selection.cutToEndOfLine(maintainClipboard)
      maintainClipboard = true


  ###
  Section: Folds
  ###

  # Public: Fold the most recent cursor's row based on its indentation level.
  #
  # The fold will extend from the nearest preceding line with a lower
  # indentation level up to the nearest following row with a lower indentation
  # level.
  foldCurrentRow: ->
    bufferRow = @bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @foldBufferRow(bufferRow)

  # Public: Unfold the most recent cursor's row by one level.
  unfoldCurrentRow: ->
    bufferRow = @bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @unfoldBufferRow(bufferRow)

  # Public: For each selection, fold the rows it intersects.
  foldSelectedLines: ->
    selection.fold() for selection in @getSelections()

  # Public: Fold all foldable lines.
  foldAll: ->
    @languageMode.foldAll()

  # Public: Unfold all existing folds.
  unfoldAll: ->
    @languageMode.unfoldAll()

  # Public: Fold all foldable lines at the given indent level.
  #
  # * `level` A {Number}.
  foldAllAtIndentLevel: (level) ->
    @languageMode.foldAllAtIndentLevel(level)

  # Public: Fold the given row in buffer coordinates based on its indentation
  # level.
  #
  # If the given row is foldable, the fold will begin there. Otherwise, it will
  # begin at the first foldable row preceding the given row.
  #
  # * `bufferRow` A {Number}.
  foldBufferRow: (bufferRow) ->
    @languageMode.foldBufferRow(bufferRow)

  # Public: Unfold all folds containing the given row in buffer coordinates.
  #
  # * `bufferRow` A {Number}
  unfoldBufferRow: (bufferRow) ->
    @displayBuffer.unfoldBufferRow(bufferRow)

  # Public: Determine whether the given row in buffer coordinates is foldable.
  #
  # A *foldable* row is a row that *starts* a row range that can be folded.
  #
  # * `bufferRow` A {Number}
  #
  # Returns a {Boolean}.
  isFoldableAtBufferRow: (bufferRow) ->
    @languageMode.isFoldableAtBufferRow(bufferRow)

  isFoldableAtScreenRow: (screenRow) ->
    bufferRow = @displayBuffer.bufferRowForScreenRow(screenRow)
    @isFoldableAtBufferRow(bufferRow)

  # TODO: Rename to foldRowRange?
  createFold: (startRow, endRow) ->
    @displayBuffer.createFold(startRow, endRow)

  # {Delegates to: DisplayBuffer.destroyFoldWithId}
  destroyFoldWithId: (id) ->
    @displayBuffer.destroyFoldWithId(id)

  # Remove any {Fold}s found that intersect the given buffer row.
  destroyFoldsIntersectingBufferRange: (bufferRange) ->
    for row in [bufferRange.start.row..bufferRange.end.row]
      @unfoldBufferRow(row)

  # Public: Fold the given buffer row if it isn't currently folded, and unfold
  # it otherwise.
  toggleFoldAtBufferRow: (bufferRow) ->
    if @isFoldedAtBufferRow(bufferRow)
      @unfoldBufferRow(bufferRow)
    else
      @foldBufferRow(bufferRow)

  # Public: Determine whether the most recently added cursor's row is folded.
  #
  # Returns a {Boolean}.
  isFoldedAtCursorRow: ->
    @isFoldedAtScreenRow(@getCursorScreenRow())

  # Public: Determine whether the given row in buffer coordinates is folded.
  #
  # * `bufferRow` A {Number}
  #
  # Returns a {Boolean}.
  isFoldedAtBufferRow: (bufferRow) ->
    @displayBuffer.isFoldedAtBufferRow(bufferRow)

  # Public: Determine whether the given row in screen coordinates is folded.
  #
  # * `screenRow` A {Number}
  #
  # Returns a {Boolean}.
  isFoldedAtScreenRow: (screenRow) ->
    @displayBuffer.isFoldedAtScreenRow(screenRow)

  # {Delegates to: DisplayBuffer.largestFoldContainingBufferRow}
  largestFoldContainingBufferRow: (bufferRow) ->
    @displayBuffer.largestFoldContainingBufferRow(bufferRow)

  # {Delegates to: DisplayBuffer.largestFoldStartingAtScreenRow}
  largestFoldStartingAtScreenRow: (screenRow) ->
    @displayBuffer.largestFoldStartingAtScreenRow(screenRow)

  # {Delegates to: DisplayBuffer.outermostFoldsForBufferRowRange}
  outermostFoldsInBufferRowRange: (startRow, endRow) ->
    @displayBuffer.outermostFoldsInBufferRowRange(startRow, endRow)





  ###
  Section: Decorations
  ###

  # Public: Get all the decorations within a screen row range.
  #
  # * `startScreenRow` the {Number} beginning screen row
  # * `endScreenRow` the {Number} end screen row (inclusive)
  #
  # Returns an {Object} of decorations in the form
  #  `{1: [{id: 10, type: 'gutter', class: 'someclass'}], 2: ...}`
  #   where the keys are {Marker} IDs, and the values are an array of decoration
  #   params objects attached to the marker.
  # Returns an empty object when no decorations are found
  decorationsForScreenRowRange: (startScreenRow, endScreenRow) ->
    @displayBuffer.decorationsForScreenRowRange(startScreenRow, endScreenRow)

  # Public: Adds a decoration that tracks a {Marker}. When the marker moves,
  # is invalidated, or is destroyed, the decoration will be updated to reflect
  # the marker's state.
  #
  # There are three types of supported decorations:
  #
  # * __line__: Adds your CSS `class` to the line nodes within the range
  #     marked by the marker
  # * __gutter__: Adds your CSS `class` to the line number nodes within the
  #     range marked by the marker
  # * __highlight__: Adds a new highlight div to the editor surrounding the
  #     range marked by the marker. When the user selects text, the selection is
  #     visualized with a highlight decoration internally. The structure of this
  #     highlight will be
  #     ```html
  #     <div class="highlight <your-class>">
  #       <!-- Will be one region for each row in the range. Spans 2 lines? There will be 2 regions. -->
  #       <div class="region"></div>
  #     </div>
  #     ```
  #
  # ## Arguments
  #
  # * `marker` A {Marker} you want this decoration to follow.
  # * `decorationParams` An {Object} representing the decoration eg. `{type: 'gutter', class: 'linter-error'}`
  #   * `type` There are a few supported decoration types: `gutter`, `line`, and `highlight`
  #   * `class` This CSS class will be applied to the decorated line number,
  #     line, or highlight.
  #   * `onlyHead` (optional) If `true`, the decoration will only be applied to the head
  #     of the marker. Only applicable to the `line` and `gutter` types.
  #   * `onlyEmpty` (optional) If `true`, the decoration will only be applied if the
  #     associated marker is empty. Only applicable to the `line` and
  #     `gutter` types.
  #   * `onlyNonEmpty` (optional) If `true`, the decoration will only be applied if the
  #     associated marker is non-empty.  Only applicable to the `line` and
  #     gutter types.
  #
  # Returns a {Decoration} object
  decorateMarker: (marker, decorationParams) ->
    @displayBuffer.decorateMarker(marker, decorationParams)

  decorationForId: (id) ->
    @displayBuffer.decorationForId(id)

  ###
  Section: Markers
  ###

  # Public: Get the {DisplayBufferMarker} for the given marker id.
  getMarker: (id) ->
    @displayBuffer.getMarker(id)

  # Public: Get all {DisplayBufferMarker}s.
  getMarkers: ->
    @displayBuffer.getMarkers()

  # Public: Find all {DisplayBufferMarker}s that match the given properties.
  #
  # This method finds markers based on the given properties. Markers can be
  # associated with custom properties that will be compared with basic equality.
  # In addition, there are several special properties that will be compared
  # with the range of the markers rather than their properties.
  #
  # * `properties` An {Object} containing properties that each returned marker
  #   must satisfy. Markers can be associated with custom properties, which are
  #   compared with basic equality. In addition, several reserved properties
  #   can be used to filter markers based on their current range:
  #   * `startBufferRow` Only include markers starting at this row in buffer
  #       coordinates.
  #   * `endBufferRow` Only include markers ending at this row in buffer
  #       coordinates.
  #   * `containsBufferRange` Only include markers containing this {Range} or
  #       in range-compatible {Array} in buffer coordinates.
  #   * `containsBufferPosition` Only include markers containing this {Point}
  #       or {Array} of `[row, column]` in buffer coordinates.
  findMarkers: (properties) ->
    @displayBuffer.findMarkers(properties)

  # Public: Mark the given range in screen coordinates.
  #
  # * `range` A {Range} or range-compatible {Array}.
  # * `options` (optional) See {TextBuffer::markRange}.
  #
  # Returns a {DisplayBufferMarker}.
  markScreenRange: (args...) ->
    @displayBuffer.markScreenRange(args...)

  # Public: Mark the given range in buffer coordinates.
  #
  # * `range` A {Range} or range-compatible {Array}.
  # * `options` (optional) See {TextBuffer::markRange}.
  #
  # Returns a {DisplayBufferMarker}.
  markBufferRange: (args...) ->
    @displayBuffer.markBufferRange(args...)

  # Public: Mark the given position in screen coordinates.
  #
  # * `position` A {Point} or {Array} of `[row, column]`.
  # * `options` (optional) See {TextBuffer::markRange}.
  #
  # Returns a {DisplayBufferMarker}.
  markScreenPosition: (args...) ->
    @displayBuffer.markScreenPosition(args...)

  # Public: Mark the given position in buffer coordinates.
  #
  # * `position` A {Point} or {Array} of `[row, column]`.
  # * `options` (optional) See {TextBuffer::markRange}.
  #
  # Returns a {DisplayBufferMarker}.
  markBufferPosition: (args...) ->
    @displayBuffer.markBufferPosition(args...)

  # {Delegates to: DisplayBuffer.destroyMarker}
  destroyMarker: (args...) ->
    @displayBuffer.destroyMarker(args...)

  # Public: Get the number of markers in this editor's buffer.
  #
  # Returns a {Number}.
  getMarkerCount: ->
    @buffer.getMarkerCount()


  ###
  Section: Cursors
  ###

  # Public: Determine if there are multiple cursors.
  hasMultipleCursors: ->
    @getCursors().length > 1

  # Public: Get an Array of all {Cursor}s.
  getCursors: -> new Array(@cursors...)

  # Public: Get the most recently added {Cursor}.
  getCursor: ->
    _.last(@cursors)

  # Public: Add a cursor at the position in screen coordinates.
  #
  # Returns a {Cursor}.
  addCursorAtScreenPosition: (screenPosition) ->
    @markScreenPosition(screenPosition, @getSelectionMarkerAttributes())
    @getLastSelection().cursor

  # Public: Add a cursor at the given position in buffer coordinates.
  #
  # Returns a {Cursor}.
  addCursorAtBufferPosition: (bufferPosition) ->
    @markBufferPosition(bufferPosition, @getSelectionMarkerAttributes())
    @getLastSelection().cursor

  # Add a cursor based on the given {DisplayBufferMarker}.
  addCursor: (marker) ->
    cursor = new Cursor(editor: this, marker: marker)
    @cursors.push(cursor)
    @decorateMarker(marker, type: 'gutter', class: 'cursor-line')
    @decorateMarker(marker, type: 'gutter', class: 'cursor-line-no-selection', onlyHead: true, onlyEmpty: true)
    @decorateMarker(marker, type: 'line', class: 'cursor-line', onlyEmpty: true)
    @emit 'cursor-added', cursor
    cursor

  # Remove the given cursor from this editor.
  removeCursor: (cursor) ->
    _.remove(@cursors, cursor)
    @emit 'cursor-removed', cursor

  # Public: Move the cursor to the given position in screen coordinates.
  #
  # If there are multiple cursors, they will be consolidated to a single cursor.
  #
  # * `position` A {Point} or {Array} of `[row, column]`
  # * `options` (optional) An {Object} combining options for {::clipScreenPosition} with:
  #   * `autoscroll` Determines whether the editor scrolls to the new cursor's
  #     position. Defaults to true.
  setCursorScreenPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setScreenPosition(position, options)

  # Public: Get the position of the most recently added cursor in screen
  # coordinates.
  #
  # Returns a {Point}.
  getCursorScreenPosition: ->
    @getCursor().getScreenPosition()

  # Public: Get the row of the most recently added cursor in screen coordinates.
  #
  # Returns the screen row {Number}.
  getCursorScreenRow: ->
    @getCursor().getScreenRow()

  # Public: Move the cursor to the given position in buffer coordinates.
  #
  # If there are multiple cursors, they will be consolidated to a single cursor.
  #
  # * `position` A {Point} or {Array} of `[row, column]`
  # * `options` (optional) An {Object} combining options for {::clipScreenPosition} with:
  #   * `autoscroll` Determines whether the editor scrolls to the new cursor's
  #     position. Defaults to true.
  setCursorBufferPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setBufferPosition(position, options)

  # Public: Get the position of the most recently added cursor in buffer
  # coordinates.
  #
  # Returns a {Point}.
  getCursorBufferPosition: ->
    @getCursor().getBufferPosition()

  # Public: Returns the word surrounding the most recently added cursor.
  #
  # * `options` (optional) See {Cursor::getBeginningOfCurrentWordBufferPosition}.
  getWordUnderCursor: (options) ->
    @getTextInBufferRange(@getCursor().getCurrentWordBufferRange(options))

  # Public: Move every cursor up one row in screen coordinates.
  moveCursorUp: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveUp(lineCount, moveToEndOfSelection: true)

  # Public: Move every cursor down one row in screen coordinates.
  moveCursorDown: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveDown(lineCount, moveToEndOfSelection: true)

  # Public: Move every cursor left one column.
  moveCursorLeft: ->
    @moveCursors (cursor) -> cursor.moveLeft(moveToEndOfSelection: true)

  # Public: Move every cursor right one column.
  moveCursorRight: ->
    @moveCursors (cursor) -> cursor.moveRight(moveToEndOfSelection: true)

  # Public: Move every cursor to the top of the buffer.
  #
  # If there are multiple cursors, they will be merged into a single cursor.
  moveCursorToTop: ->
    @moveCursors (cursor) -> cursor.moveToTop()

  # Public: Move every cursor to the bottom of the buffer.
  #
  # If there are multiple cursors, they will be merged into a single cursor.
  moveCursorToBottom: ->
    @moveCursors (cursor) -> cursor.moveToBottom()

  # Public: Move every cursor to the beginning of its line in screen coordinates.
  moveCursorToBeginningOfScreenLine: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfScreenLine()

  # Public: Move every cursor to the beginning of its line in buffer coordinates.
  moveCursorToBeginningOfLine: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfLine()

  # Public: Move every cursor to the first non-whitespace character of its line.
  moveCursorToFirstCharacterOfLine: ->
    @moveCursors (cursor) -> cursor.moveToFirstCharacterOfLine()

  # Public: Move every cursor to the end of its line in screen coordinates.
  moveCursorToEndOfScreenLine: ->
    @moveCursors (cursor) -> cursor.moveToEndOfScreenLine()

  # Public: Move every cursor to the end of its line in buffer coordinates.
  moveCursorToEndOfLine: ->
    @moveCursors (cursor) -> cursor.moveToEndOfLine()

  # Public: Move every cursor to the beginning of its surrounding word.
  moveCursorToBeginningOfWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfWord()

  # Public: Move every cursor to the end of its surrounding word.
  moveCursorToEndOfWord: ->
    @moveCursors (cursor) -> cursor.moveToEndOfWord()

  # Public: Move every cursor to the beginning of the next word.
  moveCursorToBeginningOfNextWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfNextWord()

  # Public: Move every cursor to the previous word boundary.
  moveCursorToPreviousWordBoundary: ->
    @moveCursors (cursor) -> cursor.moveToPreviousWordBoundary()

  # Public: Move every cursor to the next word boundary.
  moveCursorToNextWordBoundary: ->
    @moveCursors (cursor) -> cursor.moveToNextWordBoundary()

  # Public: Move every cursor to the beginning of the next paragraph.
  moveCursorToBeginningOfNextParagraph: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfNextParagraph()

  # Public: Move every cursor to the beginning of the previous paragraph.
  moveCursorToBeginningOfPreviousParagraph: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfPreviousParagraph()

  moveCursors: (fn) ->
    @movingCursors = true
    fn(cursor) for cursor in @getCursors()
    @mergeCursors()
    @movingCursors = false
    @emit 'cursors-moved'

  cursorMoved: (event) ->
    @emit 'cursor-moved', event
    @emit 'cursors-moved' unless @movingCursors

  # Merge cursors that have the same screen position
  mergeCursors: ->
    positions = []
    for cursor in @getCursors()
      position = cursor.getBufferPosition().toString()
      if position in positions
        cursor.destroy()
      else
        positions.push(position)

  preserveCursorPositionOnBufferReload: ->
    cursorPosition = null
    @subscribe @buffer, "will-reload", =>
      cursorPosition = @getCursorBufferPosition()
    @subscribe @buffer, "reloaded", =>
      @setCursorBufferPosition(cursorPosition) if cursorPosition
      cursorPosition = null


  ###
  Section: Selections
  ###

  # Add a {Selection} based on the given {DisplayBufferMarker}.
  #
  # * `marker` The {DisplayBufferMarker} to highlight
  # * `options` (optional) An {Object} that pertains to the {Selection} constructor.
  #
  # Returns the new {Selection}.
  addSelection: (marker, options={}) ->
    unless marker.getAttributes().preserveFolds
      @destroyFoldsIntersectingBufferRange(marker.getBufferRange())
    cursor = @addCursor(marker)
    selection = new Selection(_.extend({editor: this, marker, cursor}, options))
    @selections.push(selection)
    selectionBufferRange = selection.getBufferRange()
    @mergeIntersectingSelections()
    if selection.destroyed
      for selection in @getSelections()
        if selection.intersectsBufferRange(selectionBufferRange)
          return selection
    else
      @emit 'selection-added', selection
      selection

  # Public: Add a selection for the given range in buffer coordinates.
  #
  # * `bufferRange` A {Range}
  # * `options` (optional) An options {Object}:
  #   * `reversed` A {Boolean} indicating whether to create the selection in a
  #     reversed orientation.
  #
  # Returns the added {Selection}.
  addSelectionForBufferRange: (bufferRange, options={}) ->
    @markBufferRange(bufferRange, _.defaults(@getSelectionMarkerAttributes(), options))
    selection = @getLastSelection()
    selection.autoscroll() if @manageScrollPosition
    selection

  # Public: Set the selected range in buffer coordinates. If there are multiple
  # selections, they are reduced to a single selection with the given range.
  #
  # * `bufferRange` A {Range} or range-compatible {Array}.
  # * `options` (optional) An options {Object}:
  #   * `reversed` A {Boolean} indicating whether to create the selection in a
  #     reversed orientation.
  setSelectedBufferRange: (bufferRange, options) ->
    @setSelectedBufferRanges([bufferRange], options)

  # Public: Set the selected range in screen coordinates. If there are multiple
  # selections, they are reduced to a single selection with the given range.
  #
  # * `screenRange` A {Range} or range-compatible {Array}.
  # * `options` (optional) An options {Object}:
  #   * `reversed` A {Boolean} indicating whether to create the selection in a
  #     reversed orientation.
  setSelectedScreenRange: (screenRange, options) ->
    @setSelectedBufferRange(@bufferRangeForScreenRange(screenRange, options), options)

  # Public: Set the selected ranges in buffer coordinates. If there are multiple
  # selections, they are replaced by new selections with the given ranges.
  #
  # * `bufferRanges` An {Array} of {Range}s or range-compatible {Array}s.
  # * `options` (optional) An options {Object}:
  #   * `reversed` A {Boolean} indicating whether to create the selection in a
  #     reversed orientation.
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

  # Remove the given selection.
  removeSelection: (selection) ->
    _.remove(@selections, selection)
    @emit 'selection-removed', selection

  # Reduce one or more selections to a single empty selection based on the most
  # recently added cursor.
  clearSelections: ->
    @consolidateSelections()
    @getSelection().clear()

  # Reduce multiple selections to the most recently added selection.
  consolidateSelections: ->
    selections = @getSelections()
    if selections.length > 1
      selection.destroy() for selection in selections[0...-1]
      true
    else
      false

  selectionScreenRangeChanged: (selection) ->
    @emit 'selection-screen-range-changed', selection

  # Public: Get current {Selection}s.
  #
  # Returns: An {Array} of {Selection}s.
  getSelections: -> new Array(@selections...)

  selectionsForScreenRows: (startRow, endRow) ->
    @getSelections().filter (selection) -> selection.intersectsScreenRowRange(startRow, endRow)

  # Public: Get the most recent {Selection} or the selection at the given
  # index.
  #
  # * `index` (optional) The index of the selection to return, based on the order
  #   in which the selections were added.
  #
  # Returns a {Selection}.
  # or the  at the specified index.
  getSelection: (index) ->
    index ?= @selections.length - 1
    @selections[index]

  # Public: Get the most recently added {Selection}.
  #
  # Returns a {Selection}.
  getLastSelection: ->
    _.last(@selections)

  # Public: Get all {Selection}s, ordered by their position in the buffer
  # instead of the order in which they were added.
  #
  # Returns an {Array} of {Selection}s.
  getSelectionsOrderedByBufferPosition: ->
    @getSelections().sort (a, b) -> a.compare(b)

  # Public: Get the last {Selection} based on its position in the buffer.
  #
  # Returns a {Selection}.
  getLastSelectionInBuffer: ->
    _.last(@getSelectionsOrderedByBufferPosition())

  # Public: Determine if a given range in buffer coordinates intersects a
  # selection.
  #
  # * `bufferRange` A {Range} or range-compatible {Array}.
  #
  # Returns a {Boolean}.
  selectionIntersectsBufferRange: (bufferRange) ->
    _.any @getSelections(), (selection) ->
      selection.intersectsBufferRange(bufferRange)

  # Public: Get the {Range} of the most recently added selection in screen
  # coordinates.
  #
  # Returns a {Range}.
  getSelectedScreenRange: ->
    @getLastSelection().getScreenRange()

  # Public: Get the {Range} of the most recently added selection in buffer
  # coordinates.
  #
  # Returns a {Range}.
  getSelectedBufferRange: ->
    @getLastSelection().getBufferRange()

  # Public: Get the {Range}s of all selections in buffer coordinates.
  #
  # The ranges are sorted by their position in the buffer.
  #
  # Returns an {Array} of {Range}s.
  getSelectedBufferRanges: ->
    selection.getBufferRange() for selection in @getSelectionsOrderedByBufferPosition()

  # Public: Get the {Range}s of all selections in screen coordinates.
  #
  # The ranges are sorted by their position in the buffer.
  #
  # Returns an {Array} of {Range}s.
  getSelectedScreenRanges: ->
    selection.getScreenRange() for selection in @getSelectionsOrderedByBufferPosition()

  # Public: Get the selected text of the most recently added selection.
  #
  # Returns a {String}.
  getSelectedText: ->
    @getLastSelection().getText()

  # Public: Select from the current cursor position to the given position in
  # screen coordinates.
  #
  # This method may merge selections that end up intesecting.
  #
  # * `position` An instance of {Point}, with a given `row` and `column`.
  selectToScreenPosition: (position) ->
    lastSelection = @getLastSelection()
    lastSelection.selectToScreenPosition(position)
    @mergeIntersectingSelections(reversed: lastSelection.isReversed())

  # Public: Move the cursor of each selection one character rightward while
  # preserving the selection's tail position.
  #
  # This method may merge selections that end up intesecting.
  selectRight: ->
    @expandSelectionsForward (selection) -> selection.selectRight()

  # Public: Move the cursor of each selection one character leftward while
  # preserving the selection's tail position.
  #
  # This method may merge selections that end up intesecting.
  selectLeft: ->
    @expandSelectionsBackward (selection) -> selection.selectLeft()

  # Public: Move the cursor of each selection one character upward while
  # preserving the selection's tail position.
  #
  # This method may merge selections that end up intesecting.
  selectUp: (rowCount) ->
    @expandSelectionsBackward (selection) -> selection.selectUp(rowCount)

  # Public: Move the cursor of each selection one character downward while
  # preserving the selection's tail position.
  #
  # This method may merge selections that end up intesecting.
  selectDown: (rowCount) ->
    @expandSelectionsForward (selection) -> selection.selectDown(rowCount)

  # Public: Select from the top of the buffer to the end of the last selection
  # in the buffer.
  #
  # This method merges multiple selections into a single selection.
  selectToTop: ->
    @expandSelectionsBackward (selection) -> selection.selectToTop()

  # Public: Select all text in the buffer.
  #
  # This method merges multiple selections into a single selection.
  selectAll: ->
    @expandSelectionsForward (selection) -> selection.selectAll()

  # Public: Selects from the top of the first selection in the buffer to the end
  # of the buffer.
  #
  # This method merges multiple selections into a single selection.
  selectToBottom: ->
    @expandSelectionsForward (selection) -> selection.selectToBottom()

  # Public: Move the cursor of each selection to the beginning of its line
  # while preserving the selection's tail position.
  #
  # This method may merge selections that end up intesecting.
  selectToBeginningOfLine: ->
    @expandSelectionsBackward (selection) -> selection.selectToBeginningOfLine()

  # Public: Move the cursor of each selection to the first non-whitespace
  # character of its line while preserving the selection's tail position. If the
  # cursor is already on the first character of the line, move it to the
  # beginning of the line.
  #
  # This method may merge selections that end up intersecting.
  selectToFirstCharacterOfLine: ->
    @expandSelectionsBackward (selection) -> selection.selectToFirstCharacterOfLine()

  # Public: Move the cursor of each selection to the end of its line while
  # preserving the selection's tail position.
  #
  # This method may merge selections that end up intersecting.
  selectToEndOfLine: ->
    @expandSelectionsForward (selection) -> selection.selectToEndOfLine()

  # Public: For each selection, move its cursor to the preceding word boundary
  # while maintaining the selection's tail position.
  #
  # This method may merge selections that end up intersecting.
  selectToPreviousWordBoundary: ->
    @expandSelectionsBackward (selection) -> selection.selectToPreviousWordBoundary()

  # Public: For each selection, move its cursor to the next word boundary while
  # maintaining the selection's tail position.
  #
  # This method may merge selections that end up intersecting.
  selectToNextWordBoundary: ->
    @expandSelectionsForward (selection) -> selection.selectToNextWordBoundary()

  # Public: For each cursor, select the containing line.
  #
  # This method merges selections on successive lines.
  selectLine: ->
    @expandSelectionsForward (selection) -> selection.selectLine()

  # Public: Add a similarly-shaped selection to the next eligible line below
  # each selection.
  #
  # Operates on all selections. If the selection is empty, adds an empty
  # selection to the next following non-empty line as close to the current
  # selection's column as possible. If the selection is non-empty, adds a
  # selection to the next line that is long enough for a non-empty selection
  # starting at the same column as the current selection to be added to it.
  addSelectionBelow: ->
    @expandSelectionsForward (selection) -> selection.addSelectionBelow()

  # Public: Add a similarly-shaped selection to the next eligible line above
  # each selection.
  #
  # Operates on all selections. If the selection is empty, adds an empty
  # selection to the next preceding non-empty line as close to the current
  # selection's column as possible. If the selection is non-empty, adds a
  # selection to the next line that is long enough for a non-empty selection
  # starting at the same column as the current selection to be added to it.
  addSelectionAbove: ->
    @expandSelectionsBackward (selection) -> selection.addSelectionAbove()

  # Public: Expand selections to the beginning of their containing word.
  #
  # Operates on all selections. Moves the cursor to the beginning of the
  # containing word while preserving the selection's tail position.
  selectToBeginningOfWord: ->
    @expandSelectionsBackward (selection) -> selection.selectToBeginningOfWord()

  # Public: Expand selections to the end of their containing word.
  #
  # Operates on all selections. Moves the cursor to the end of the containing
  # word while preserving the selection's tail position.
  selectToEndOfWord: ->
    @expandSelectionsForward (selection) -> selection.selectToEndOfWord()

  # Public: Expand selections to the beginning of the next word.
  #
  # Operates on all selections. Moves the cursor to the beginning of the next
  # word while preserving the selection's tail position.
  selectToBeginningOfNextWord: ->
    @expandSelectionsForward (selection) -> selection.selectToBeginningOfNextWord()

  # Public: Select the word containing each cursor.
  selectWord: ->
    @expandSelectionsForward (selection) -> selection.selectWord()

  # Public: Expand selections to the beginning of the next paragraph.
  #
  # Operates on all selections. Moves the cursor to the beginning of the next
  # paragraph while preserving the selection's tail position.
  selectToBeginningOfNextParagraph: ->
    @expandSelectionsForward (selection) -> selection.selectToBeginningOfNextParagraph()

  # Public: Expand selections to the beginning of the next paragraph.
  #
  # Operates on all selections. Moves the cursor to the beginning of the next
  # paragraph while preserving the selection's tail position.
  selectToBeginningOfPreviousParagraph: ->
    @expandSelectionsBackward (selection) -> selection.selectToBeginningOfPreviousParagraph()

  # Public: Select the range of the given marker if it is valid.
  #
  # * `marker` A {DisplayBufferMarker}
  #
  # Returns the selected {Range} or `undefined` if the marker is invalid.
  selectMarker: (marker) ->
    if marker.isValid()
      range = marker.getBufferRange()
      @setSelectedBufferRange(range)
      range

  # Calls the given function with each selection, then merges selections
  expandSelectionsForward: (fn) ->
    @mergeIntersectingSelections =>
      fn(selection) for selection in @getSelections()

  # Calls the given function with each selection, then merges selections in the
  # reversed orientation
  expandSelectionsBackward: (fn) ->
    @mergeIntersectingSelections reversed: true, =>
      fn(selection) for selection in @getSelections()

  finalizeSelections: ->
    selection.finalize() for selection in @getSelections()

  # Merges intersecting selections. If passed a function, it executes
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
      intersectingSelection = _.find disjointSelections, (otherSelection) ->
        exclusive = not selection.isEmpty() and not otherSelection.isEmpty()
        intersects = otherSelection.intersectsWith(selection, exclusive)
        intersects

      if intersectingSelection?
        intersectingSelection.merge(selection, options)
        disjointSelections
      else
        disjointSelections.concat([selection])

    _.reduce(@getSelections(), reducer, [])



  ###
  Section: Scrolling the Editor
  ###

  # Public: Scroll the editor to reveal the most recently added cursor if it is
  # off-screen.
  #
  # * `options` (optional) {Object}
  #   * `center` Center the editor around the cursor if possible. Defauls to true.
  scrollToCursorPosition: (options) ->
    @getCursor().autoscroll(center: options?.center ? true)

  pageUp: ->
    newScrollTop = @getScrollTop() - @getHeight()
    @moveCursorUp(@getRowsPerPage())
    @setScrollTop(newScrollTop)

  pageDown: ->
    newScrollTop = @getScrollTop() + @getHeight()
    @moveCursorDown(@getRowsPerPage())
    @setScrollTop(newScrollTop)

  selectPageUp: ->
    @selectUp(@getRowsPerPage())

  selectPageDown: ->
    @selectDown(@getRowsPerPage())

  # Returns the number of rows per page
  getRowsPerPage: ->
    Math.max(1, Math.ceil(@getHeight() / @getLineHeightInPixels()))


  ###
  Section: Config
  ###

  shouldAutoIndent: ->
    atom.config.get("editor.autoIndent")

  shouldShowInvisibles: ->
    not @mini and atom.config.get('editor.showInvisibles')

  updateInvisibles: ->
    if @shouldShowInvisibles()
      @displayBuffer.setInvisibles(atom.config.get('editor.invisibles'))
    else
      @displayBuffer.setInvisibles(null)


  ###
  Section: Event Handlers
  ###

  handleTokenization: ->
    @softTabs = @usesSoftTabs() ? @softTabs

  handleGrammarChange: ->
    @unfoldAll()
    @emit 'grammar-changed'

  handleMarkerCreated: (marker) =>
    if marker.matchesAttributes(@getSelectionMarkerAttributes())
      @addSelection(marker)

  ###
  Section: Editor Rendering
  ###

  getSelectionMarkerAttributes: ->
    type: 'selection', editorId: @id, invalidate: 'never'

  getVerticalScrollMargin: -> @displayBuffer.getVerticalScrollMargin()
  setVerticalScrollMargin: (verticalScrollMargin) -> @displayBuffer.setVerticalScrollMargin(verticalScrollMargin)

  getHorizontalScrollMargin: -> @displayBuffer.getHorizontalScrollMargin()
  setHorizontalScrollMargin: (horizontalScrollMargin) -> @displayBuffer.setHorizontalScrollMargin(horizontalScrollMargin)

  getLineHeightInPixels: -> @displayBuffer.getLineHeightInPixels()
  setLineHeightInPixels: (lineHeightInPixels) -> @displayBuffer.setLineHeightInPixels(lineHeightInPixels)

  batchCharacterMeasurement: (fn) -> @displayBuffer.batchCharacterMeasurement(fn)

  getScopedCharWidth: (scopeNames, char) -> @displayBuffer.getScopedCharWidth(scopeNames, char)
  setScopedCharWidth: (scopeNames, char, width) -> @displayBuffer.setScopedCharWidth(scopeNames, char, width)

  getScopedCharWidths: (scopeNames) -> @displayBuffer.getScopedCharWidths(scopeNames)

  clearScopedCharWidths: -> @displayBuffer.clearScopedCharWidths()

  getDefaultCharWidth: -> @displayBuffer.getDefaultCharWidth()
  setDefaultCharWidth: (defaultCharWidth) -> @displayBuffer.setDefaultCharWidth(defaultCharWidth)

  setHeight: (height) -> @displayBuffer.setHeight(height)
  getHeight: -> @displayBuffer.getHeight()

  getClientHeight: -> @displayBuffer.getClientHeight()

  setWidth: (width) -> @displayBuffer.setWidth(width)
  getWidth: -> @displayBuffer.getWidth()

  getScrollTop: -> @displayBuffer.getScrollTop()
  setScrollTop: (scrollTop) -> @displayBuffer.setScrollTop(scrollTop)

  getScrollBottom: -> @displayBuffer.getScrollBottom()
  setScrollBottom: (scrollBottom) -> @displayBuffer.setScrollBottom(scrollBottom)

  getScrollLeft: -> @displayBuffer.getScrollLeft()
  setScrollLeft: (scrollLeft) -> @displayBuffer.setScrollLeft(scrollLeft)

  getScrollRight: -> @displayBuffer.getScrollRight()
  setScrollRight: (scrollRight) -> @displayBuffer.setScrollRight(scrollRight)

  getScrollHeight: -> @displayBuffer.getScrollHeight()
  getScrollWidth: -> @displayBuffer.getScrollWidth()

  getVisibleRowRange: -> @displayBuffer.getVisibleRowRange()

  intersectsVisibleRowRange: (startRow, endRow) -> @displayBuffer.intersectsVisibleRowRange(startRow, endRow)

  selectionIntersectsVisibleRowRange: (selection) -> @displayBuffer.selectionIntersectsVisibleRowRange(selection)

  pixelPositionForScreenPosition: (screenPosition) -> @displayBuffer.pixelPositionForScreenPosition(screenPosition)

  pixelPositionForBufferPosition: (bufferPosition) -> @displayBuffer.pixelPositionForBufferPosition(bufferPosition)

  screenPositionForPixelPosition: (pixelPosition) -> @displayBuffer.screenPositionForPixelPosition(pixelPosition)

  pixelRectForScreenRange: (screenRange) -> @displayBuffer.pixelRectForScreenRange(screenRange)

  scrollToScreenRange: (screenRange, options) -> @displayBuffer.scrollToScreenRange(screenRange, options)

  scrollToScreenPosition: (screenPosition, options) -> @displayBuffer.scrollToScreenPosition(screenPosition, options)

  scrollToBufferPosition: (bufferPosition, options) -> @displayBuffer.scrollToBufferPosition(bufferPosition, options)

  horizontallyScrollable: -> @displayBuffer.horizontallyScrollable()

  verticallyScrollable: -> @displayBuffer.verticallyScrollable()

  getHorizontalScrollbarHeight: -> @displayBuffer.getHorizontalScrollbarHeight()
  setHorizontalScrollbarHeight: (height) -> @displayBuffer.setHorizontalScrollbarHeight(height)

  getVerticalScrollbarWidth: -> @displayBuffer.getVerticalScrollbarWidth()
  setVerticalScrollbarWidth: (width) -> @displayBuffer.setVerticalScrollbarWidth(width)

  # Deprecated: Call {::joinLines} instead.
  joinLine: ->
    deprecate("Use Editor::joinLines() instead")
    @joinLines()

  ###
  Section: Utility
  ###

  inspect: ->
    "<Editor #{@id}>"

  logScreenLines: (start, end) -> @displayBuffer.logLines(start, end)
