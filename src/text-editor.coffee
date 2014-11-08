_ = require 'underscore-plus'
path = require 'path'
Serializable = require 'serializable'
Delegator = require 'delegato'
{deprecate} = require 'grim'
{Model} = require 'theorist'
EmitterMixin = require('emissary').Emitter
{CompositeDisposable, Emitter} = require 'event-kit'
{Point, Range} = require 'text-buffer'
LanguageMode = require './language-mode'
DisplayBuffer = require './display-buffer'
Cursor = require './cursor'
Selection = require './selection'
TextMateScopeSelector = require('first-mate').ScopeSelector

# Public: This class represents all essential editing state for a single
# {TextBuffer}, including cursor and selection positions, folds, and soft wraps.
# If you're manipulating the state of an editor, use this class. If you're
# interested in the visual appearance of editors, use {TextEditorView} instead.
#
# A single {TextBuffer} can belong to multiple editors. For example, if the
# same file is open in two different panes, Atom creates a separate editor for
# each pane. If the buffer is manipulated the changes are reflected in both
# editors, but each maintains its own cursor position, folded lines, etc.
#
# ## Accessing TextEditor Instances
#
# The easiest way to get hold of `TextEditor` objects is by registering a callback
# with `::observeTextEditors` on the `atom.workspace` global. Your callback will
# then be called with all current editor instances and also when any editor is
# created in the future.
#
# ```coffee
# atom.workspace.observeTextEditors (editor) ->
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
module.exports =
class TextEditor extends Model
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

  constructor: ({@softTabs, initialLine, initialColumn, tabLength, softWrapped, @displayBuffer, buffer, registerEditor, suppressCursorCreation, @mini, @placeholderText}) ->
    super

    @emitter = new Emitter
    @cursors = []
    @selections = []

    @displayBuffer ?= new DisplayBuffer({buffer, tabLength, softWrapped})
    @buffer = @displayBuffer.buffer
    @softTabs = @usesSoftTabs() ? @softTabs ? atom.config.get('editor.softTabs') ? true

    @updateInvisibles()

    for marker in @findMarkers(@getSelectionMarkerAttributes())
      marker.setProperties(preserveFolds: true)
      @addSelection(marker)

    @subscribeToBuffer()
    @subscribeToDisplayBuffer()

    if @getCursors().length is 0 and not suppressCursorCreation
      initialLine = Math.max(parseInt(initialLine) or 0, 0)
      initialColumn = Math.max(parseInt(initialColumn) or 0, 0)
      @addCursorAtBufferPosition([initialLine, initialColumn])

    @languageMode = new LanguageMode(this)

    @subscribe @$scrollTop, (scrollTop) =>
      @emit 'scroll-top-changed', scrollTop
      @emitter.emit 'did-change-scroll-top', scrollTop
    @subscribe @$scrollLeft, (scrollLeft) =>
      @emit 'scroll-left-changed', scrollLeft
      @emitter.emit 'did-change-scroll-left', scrollLeft

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
    @subscribe @buffer.onDidChangePath =>
      unless atom.project.getPaths()[0]?
        atom.project.setPaths([path.dirname(@getPath())])
      @emit "title-changed"
      @emitter.emit 'did-change-title', @getTitle()
      @emit "path-changed"
      @emitter.emit 'did-change-path', @getPath()
    @subscribe @buffer.onDidChangeEncoding =>
      @emitter.emit 'did-change-encoding', @getEncoding()
    @subscribe @buffer.onDidDestroy => @destroy()

    # TODO: remove these when we remove the deprecations. They are old events.
    @subscribe @buffer.onDidStopChanging => @emit "contents-modified"
    @subscribe @buffer.onDidConflict => @emit "contents-conflicted"
    @subscribe @buffer.onDidChangeModified => @emit "modified-status-changed"

    @preserveCursorPositionOnBufferReload()

  subscribeToDisplayBuffer: ->
    @subscribe @displayBuffer.onDidCreateMarker @handleMarkerCreated
    @subscribe @displayBuffer.onDidUpdateMarkers => @mergeIntersectingSelections()
    @subscribe @displayBuffer.onDidChangeGrammar => @handleGrammarChange()
    @subscribe @displayBuffer.onDidTokenize => @handleTokenization()
    @subscribe @displayBuffer.onDidChange (e) =>
      @emit 'screen-lines-changed', e
      @emitter.emit 'did-change', e

    # TODO: remove these when we remove the deprecations. Though, no one is likely using them
    @subscribe @displayBuffer.onDidChangeSoftWrapped (softWrapped) => @emit 'soft-wrap-changed', softWrapped
    @subscribe @displayBuffer.onDidAddDecoration (decoration) => @emit 'decoration-added', decoration
    @subscribe @displayBuffer.onDidRemoveDecoration (decoration) => @emit 'decoration-removed', decoration

    @subscribeToScopedConfigSettings()

  subscribeToScopedConfigSettings: ->
    @scopedConfigSubscriptions?.dispose()
    @scopedConfigSubscriptions = subscriptions = new CompositeDisposable

    scopeDescriptor = @getRootScopeDescriptor()

    subscriptions.add atom.config.onDidChange scopeDescriptor, 'editor.showInvisibles', => @updateInvisibles()
    subscriptions.add atom.config.onDidChange scopeDescriptor, 'editor.invisibles', => @updateInvisibles()

  getViewClass: ->
    require './text-editor-view'

  destroyed: ->
    @unsubscribe()
    @scopedConfigSubscriptions.dispose()
    selection.destroy() for selection in @getSelections()
    @buffer.release()
    @displayBuffer.destroy()
    @languageMode.destroy()
    @emitter.emit 'did-destroy'

  ###
  Section: Event Subscription
  ###

  # Essential: Calls your `callback` when the buffer's title has changed.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeTitle: (callback) ->
    @emitter.on 'did-change-title', callback

  # Essential: Calls your `callback` when the buffer's path, and therefore title, has changed.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangePath: (callback) ->
    @emitter.on 'did-change-path', callback

  # Essential: Invoke the given callback synchronously when the content of the
  # buffer changes.
  #
  # Because observers are invoked synchronously, it's important not to perform
  # any expensive operations via this method. Consider {::onDidStopChanging} to
  # delay expensive operations until after changes stop occurring.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  # Essential: Invoke `callback` when the buffer's contents change. It is
  # emit asynchronously 300ms after the last buffer change. This is a good place
  # to handle changes to the buffer without compromising typing performance.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidStopChanging: (callback) ->
    @getBuffer().onDidStopChanging(callback)

  # Essential: Calls your `callback` when a {Cursor} is moved. If there are
  # multiple cursors, your callback will be called for each cursor.
  #
  # * `callback` {Function}
  #   * `event` {Object}
  #     * `oldBufferPosition` {Point}
  #     * `oldScreenPosition` {Point}
  #     * `newBufferPosition` {Point}
  #     * `newScreenPosition` {Point}
  #     * `textChanged` {Boolean}
  #     * `cursor` {Cursor} that triggered the event
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeCursorPosition: (callback) ->
    @emitter.on 'did-change-cursor-position', callback

  # Essential: Calls your `callback` when a selection's screen range changes.
  #
  # * `callback` {Function}
  #   * `event` {Object}
  #     * `oldBufferRange` {Range}
  #     * `oldScreenRange` {Range}
  #     * `newBufferRange` {Range}
  #     * `newScreenRange` {Range}
  #     * `selection` {Selection} that triggered the event
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeSelectionRange: (callback) ->
    @emitter.on 'did-change-selection-range', callback

  # Extended: Calls your `callback` when soft wrap was enabled or disabled.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeSoftWrapped: (callback) ->
    @displayBuffer.onDidChangeSoftWrapped(callback)

  # Extended: Calls your `callback` when the buffer's encoding has changed.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeEncoding: (callback) ->
    @emitter.on 'did-change-encoding', callback

  # Extended: Calls your `callback` when the grammar that interprets and
  # colorizes the text has been changed. Immediately calls your callback with
  # the current grammar.
  #
  # * `callback` {Function}
  #   * `grammar` {Grammar}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeGrammar: (callback) ->
    callback(@getGrammar())
    @onDidChangeGrammar(callback)

  # Extended: Calls your `callback` when the grammar that interprets and
  # colorizes the text has been changed.
  #
  # * `callback` {Function}
  #   * `grammar` {Grammar}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeGrammar: (callback) ->
    @emitter.on 'did-change-grammar', callback

  # Extended: Calls your `callback` when the result of {::isModified} changes.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeModified: (callback) ->
    @getBuffer().onDidChangeModified(callback)

  # Extended: Calls your `callback` when the buffer's underlying file changes on
  # disk at a moment when the result of {::isModified} is true.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidConflict: (callback) ->
    @getBuffer().onDidConflict(callback)

  # Extended: Calls your `callback` before text has been inserted.
  #
  # * `callback` {Function}
  #   * `event` event {Object}
  #     * `text` {String} text to be inserted
  #     * `cancel` {Function} Call to prevent the text from being inserted
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillInsertText: (callback) ->
    @emitter.on 'will-insert-text', callback

  # Extended: Calls your `callback` adter text has been inserted.
  #
  # * `callback` {Function}
  #   * `event` event {Object}
  #     * `text` {String} text to be inserted
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidInsertText: (callback) ->
    @emitter.on 'did-insert-text', callback

  # Public: Invoke the given callback after the buffer is saved to disk.
  #
  # * `callback` {Function} to be called after the buffer is saved.
  #   * `event` {Object} with the following keys:
  #     * `path` The path to which the buffer was saved.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidSave: (callback) ->
    @getBuffer().onDidSave(callback)

  # Public: Invoke the given callback when the editor is destroyed.
  #
  # * `callback` {Function} to be called when the editor is destroyed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  # Extended: Calls your `callback` when a {Cursor} is added to the editor.
  # Immediately calls your callback for each existing cursor.
  #
  # * `callback` {Function}
  #   * `selection` {Selection} that was added
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeCursors: (callback) ->
    callback(cursor) for cursor in @getCursors()
    @onDidAddCursor(callback)

  # Extended: Calls your `callback` when a {Cursor} is added to the editor.
  #
  # * `callback` {Function}
  #   * `cursor` {Cursor} that was added
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddCursor: (callback) ->
    @emitter.on 'did-add-cursor', callback

  # Extended: Calls your `callback` when a {Cursor} is removed from the editor.
  #
  # * `callback` {Function}
  #   * `cursor` {Cursor} that was removed
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidRemoveCursor: (callback) ->
    @emitter.on 'did-remove-cursor', callback

  # Extended: Calls your `callback` when a {Selection} is added to the editor.
  # Immediately calls your callback for each existing selection.
  #
  # * `callback` {Function}
  #   * `selection` {Selection} that was added
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeSelections: (callback) ->
    callback(selection) for selection in @getSelections()
    @onDidAddSelection(callback)

  # Extended: Calls your `callback` when a {Selection} is added to the editor.
  #
  # * `callback` {Function}
  #   * `selection` {Selection} that was added
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddSelection: (callback) ->
    @emitter.on 'did-add-selection', callback

  # Extended: Calls your `callback` when a {Selection} is removed from the editor.
  #
  # * `callback` {Function}
  #   * `selection` {Selection} that was removed
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidRemoveSelection: (callback) ->
    @emitter.on 'did-remove-selection', callback

  # Extended: Calls your `callback` with each {Decoration} added to the editor.
  # Calls your `callback` immediately for any existing decorations.
  #
  # * `callback` {Function}
  #   * `decoration` {Decoration}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeDecorations: (callback) ->
    @displayBuffer.observeDecorations(callback)

  # Extended: Calls your `callback` when a {Decoration} is added to the editor.
  #
  # * `callback` {Function}
  #   * `decoration` {Decoration} that was added
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddDecoration: (callback) ->
    @displayBuffer.onDidAddDecoration(callback)

  # Extended: Calls your `callback` when a {Decoration} is removed from the editor.
  #
  # * `callback` {Function}
  #   * `decoration` {Decoration} that was removed
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidRemoveDecoration: (callback) ->
    @displayBuffer.onDidRemoveDecoration(callback)

  # Extended: Calls your `callback` when the placeholder text is changed.
  #
  # * `callback` {Function}
  #   * `placeholderText` {String} new text
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangePlaceholderText: (callback) ->
    @emitter.on 'did-change-placeholder-text', callback

  onDidChangeCharacterWidths: (callback) ->
    @displayBuffer.onDidChangeCharacterWidths(callback)

  onDidChangeScrollTop: (callback) ->
    @emitter.on 'did-change-scroll-top', callback

  onDidChangeScrollLeft: (callback) ->
    @emitter.on 'did-change-scroll-left', callback

  on: (eventName) ->
    switch eventName
      when 'title-changed'
        deprecate("Use TextEditor::onDidChangeTitle instead")
      when 'path-changed'
        deprecate("Use TextEditor::onDidChangePath instead")
      when 'modified-status-changed'
        deprecate("Use TextEditor::onDidChangeModified instead")
      when 'soft-wrap-changed'
        deprecate("Use TextEditor::onDidChangeSoftWrapped instead")
      when 'grammar-changed'
        deprecate("Use TextEditor::onDidChangeGrammar instead")
      when 'character-widths-changed'
        deprecate("Use TextEditor::onDidChangeCharacterWidths instead")
      when 'contents-modified'
        deprecate("Use TextEditor::onDidStopChanging instead")
      when 'contents-conflicted'
        deprecate("Use TextEditor::onDidConflict instead")

      when 'will-insert-text'
        deprecate("Use TextEditor::onWillInsertText instead")
      when 'did-insert-text'
        deprecate("Use TextEditor::onDidInsertText instead")

      when 'cursor-added'
        deprecate("Use TextEditor::onDidAddCursor instead")
      when 'cursor-removed'
        deprecate("Use TextEditor::onDidRemoveCursor instead")
      when 'cursor-moved'
        deprecate("Use TextEditor::onDidChangeCursorPosition instead")

      when 'selection-added'
        deprecate("Use TextEditor::onDidAddSelection instead")
      when 'selection-removed'
        deprecate("Use TextEditor::onDidRemoveSelection instead")
      when 'selection-screen-range-changed'
        deprecate("Use TextEditor::onDidChangeSelectionRange instead")

      when 'decoration-added'
        deprecate("Use TextEditor::onDidAddDecoration instead")
      when 'decoration-removed'
        deprecate("Use TextEditor::onDidRemoveDecoration instead")
      when 'decoration-updated'
        deprecate("Use Decoration::onDidChangeProperties instead. You will get the decoration back from `TextEditor::decorateMarker()`")
      when 'decoration-changed'
        deprecate("Use Marker::onDidChange instead. e.g. `editor::decorateMarker(...).getMarker().onDidChange()`")

      when 'screen-lines-changed'
        deprecate("Use TextEditor::onDidChange instead")

      when 'scroll-top-changed'
        deprecate("Use TextEditor::onDidChangeScrollTop instead")
      when 'scroll-left-changed'
        deprecate("Use TextEditor::onDidChangeScrollLeft instead")

    EmitterMixin::on.apply(this, arguments)

  # Retrieves the current {TextBuffer}.
  getBuffer: -> @buffer

  # Retrieves the current buffer's URI.
  getUri: -> @buffer.getUri()

  # Create an {TextEditor} with its initial state based on this object
  copy: ->
    displayBuffer = @displayBuffer.copy()
    softTabs = @getSoftTabs()
    newEditor = new TextEditor({@buffer, displayBuffer, @tabLength, softTabs, suppressCursorCreation: true, registerEditor: true})
    for marker in @findMarkers(editorId: @id)
      marker.copy(editorId: newEditor.id, preserveFolds: true)
    newEditor

  # Controls visibility based on the given {Boolean}.
  setVisible: (visible) -> @displayBuffer.setVisible(visible)

  setMini: (mini) ->
    if mini isnt @mini
      @mini = mini
      @updateInvisibles()

  isMini: -> @mini

  # Set the number of characters that can be displayed horizontally in the
  # editor.
  #
  # * `editorWidthInChars` A {Number} representing the width of the {TextEditorView}
  # in characters.
  setEditorWidthInChars: (editorWidthInChars) ->
    @displayBuffer.setEditorWidthInChars(editorWidthInChars)

  ###
  Section: File Details
  ###

  # Essential: Get the editor's title for display in other parts of the
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

  # Essential: Get the editor's long title for display in other parts of the UI
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

  # Essential: Returns the {String} path of this editor's text buffer.
  getPath: -> @buffer.getPath()

  # Extended: Returns the {String} character set encoding of this editor's text
  # buffer.
  getEncoding: -> @buffer.getEncoding()

  # Extended: Set the character set encoding to use in this editor's text
  # buffer.
  #
  # * `encoding` The {String} character set encoding name such as 'utf8'
  setEncoding: (encoding) -> @buffer.setEncoding(encoding)

  # Essential: Returns {Boolean} `true` if this editor has been modified.
  isModified: -> @buffer.isModified()

  # Essential: Returns {Boolean} `true` if this editor has no content.
  isEmpty: -> @buffer.isEmpty()

  # Copies the current file path to the native clipboard.
  copyPathToClipboard: ->
    if filePath = @getPath()
      atom.clipboard.write(filePath)

  ###
  Section: File Operations
  ###

  # Essential: Saves the editor's text buffer.
  #
  # See {TextBuffer::save} for more details.
  save: -> @buffer.save()

  # Public: Saves the editor's text buffer as the given path.
  #
  # See {TextBuffer::saveAs} for more details.
  #
  # * `filePath` A {String} path.
  saveAs: (filePath) -> @buffer.saveAs(filePath)

  # Determine whether the user should be prompted to save before closing
  # this editor.
  shouldPromptToSave: -> @isModified() and not @buffer.hasMultipleEditors()

  ###
  Section: Reading Text
  ###

  # Essential: Returns a {String} representing the entire contents of the editor.
  getText: -> @buffer.getText()

  # Essential: Get the text in the given {Range} in buffer coordinates.
  #
  # * `range` A {Range} or range-compatible {Array}.
  #
  # Returns a {String}.
  getTextInBufferRange: (range) ->
    @buffer.getTextInRange(range)

  # Essential: Returns a {Number} representing the number of lines in the buffer.
  getLineCount: -> @buffer.getLineCount()

  # Essential: Returns a {Number} representing the number of screen lines in the
  # editor. This accounts for folds.
  getScreenLineCount: -> @displayBuffer.getLineCount()

  # Essential: Returns a {Number} representing the last zero-indexed buffer row
  # number of the editor.
  getLastBufferRow: -> @buffer.getLastRow()

  # Essential: Returns a {Number} representing the last zero-indexed screen row
  # number of the editor.
  getLastScreenRow: -> @displayBuffer.getLastRow()

  # Essential: Returns a {String} representing the contents of the line at the
  # given buffer row.
  #
  # * `bufferRow` A {Number} representing a zero-indexed buffer row.
  lineTextForBufferRow: (bufferRow) -> @buffer.lineForRow(bufferRow)
  lineForBufferRow: (bufferRow) ->
    deprecate 'Use TextEditor::lineTextForBufferRow(bufferRow) instead'
    @lineTextForBufferRow(bufferRow)

  # Essential: Returns a {String} representing the contents of the line at the
  # given screen row.
  #
  # * `screenRow` A {Number} representing a zero-indexed screen row.
  lineTextForScreenRow: (screenRow) -> @displayBuffer.tokenizedLineForScreenRow(screenRow)?.text

  # Gets the screen line for the given screen row.
  #
  # * `screenRow` - A {Number} indicating the screen row.
  #
  # Returns {TokenizedLine}
  tokenizedLineForScreenRow: (screenRow) -> @displayBuffer.tokenizedLineForScreenRow(screenRow)
  lineForScreenRow: (screenRow) ->
    deprecate "TextEditor::tokenizedLineForScreenRow(bufferRow) is the new name. But it's private. Try to use TextEditor::lineTextForScreenRow instead"
    @tokenizedLineForScreenRow(screenRow)

  # {Delegates to: DisplayBuffer.tokenizedLinesForScreenRows}
  tokenizedLinesForScreenRows: (start, end) -> @displayBuffer.tokenizedLinesForScreenRows(start, end)
  linesForScreenRows: (start, end) ->
    deprecate "Use TextEditor::tokenizedLinesForScreenRows instead"
    @tokenizedLinesForScreenRows(start, end)

  # Returns a {Number} representing the line length for the given
  # buffer row, exclusive of its line-ending character(s).
  #
  # * `row` A {Number} indicating the buffer row.
  lineLengthForBufferRow: (row) ->
    deprecate "Use editor.lineTextForBufferRow(row).length instead"
    @lineTextForBufferRow(row).length

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
    @getLastCursor().getCurrentParagraphBufferRange()


  ###
  Section: Mutating Text
  ###

  # Essential: Replaces the entire contents of the buffer with the given {String}.
  setText: (text) -> @buffer.setText(text)

  # Essential: Set the text in the given {Range} in buffer coordinates.
  #
  # * `range` A {Range} or range-compatible {Array}.
  # * `text` A {String}
  # * `options` (optional) {Object}
  #   * `normalizeLineEndings` (optional) {Boolean} (default: true)
  #   * `undo` (optional) {String} 'skip' will skip the undo system
  #
  # Returns the {Range} of the newly-inserted text.
  setTextInBufferRange: (range, text, options) -> @getBuffer().setTextInRange(range, text, options)

  # Essential: For each selection, replace the selected text with the given text.
  #
  # * `text` A {String} representing the text to insert.
  # * `options` (optional) See {Selection::insertText}.
  #
  # Returns a {Range} when the text has been inserted
  # Returns a {Bool} false when the text has not been inserted
  insertText: (text, options={}) ->
    willInsert = true
    cancel = -> willInsert = false
    willInsertEvent = {cancel, text}
    @emit('will-insert-text', willInsertEvent)
    @emitter.emit 'will-insert-text', willInsertEvent

    if willInsert
      options.autoIndentNewline ?= @shouldAutoIndent()
      options.autoDecreaseIndent ?= @shouldAutoIndent()
      @mutateSelectedText (selection) =>
        range = selection.insertText(text, options)
        didInsertEvent = {text, range}
        @emit('did-insert-text', didInsertEvent)
        @emitter.emit 'did-insert-text', didInsertEvent
        range
    else
      false

  # Essential: For each selection, replace the selected text with a newline.
  insertNewline: ->
    @insertText('\n')

  # Essential: For each selection, if the selection is empty, delete the character
  # following the cursor. Otherwise delete the selected text.
  delete: ->
    @mutateSelectedText (selection) -> selection.delete()

  # Essential: For each selection, if the selection is empty, delete the character
  # preceding the cursor. Otherwise delete the selected text.
  backspace: ->
    @mutateSelectedText (selection) -> selection.backspace()

  # Extended: Mutate the text of all the selections in a single transaction.
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
    deprecate("Use TextEditor::duplicateLines() instead")
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

  # Split multi-line selections into one selection per line.
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

  # Extended: For each selection, transpose the selected text.
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

  # Extended: Convert the selected text to upper case.
  #
  # For each selection, if the selection is empty, converts the containing word
  # to upper case. Otherwise convert the selected text to upper case.
  upperCase: ->
    @replaceSelectedText selectWordIfEmpty:true, (text) -> text.toUpperCase()

  # Extended: Convert the selected text to lower case.
  #
  # For each selection, if the selection is empty, converts the containing word
  # to upper case. Otherwise convert the selected text to upper case.
  lowerCase: ->
    @replaceSelectedText selectWordIfEmpty:true, (text) -> text.toLowerCase()

  # Extended: Toggle line comments for rows intersecting selections.
  #
  # If the current grammar doesn't support comments, does nothing.
  #
  # Returns an {Array} of the commented {Range}s.
  toggleLineCommentsInSelection: ->
    @mutateSelectedText (selection) -> selection.toggleLineComments()

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

  # Extended: For each cursor, insert a newline at beginning the following line.
  insertNewlineBelow: ->
    @transact =>
      @moveToEndOfLine()
      @insertNewline()

  # Extended: For each cursor, insert a newline at the end of the preceding line.
  insertNewlineAbove: ->
    @transact =>
      bufferRow = @getCursorBufferPosition().row
      indentLevel = @indentationForBufferRow(bufferRow)
      onFirstLine = bufferRow is 0

      @moveToBeginningOfLine()
      @moveLeft()
      @insertNewline()

      if @shouldAutoIndent() and @indentationForBufferRow(bufferRow) < indentLevel
        @setIndentationForBufferRow(bufferRow, indentLevel)

      if onFirstLine
        @moveUp()
        @moveToEndOfLine()

  # Extended: For each selection, if the selection is empty, delete all characters
  # of the containing word that precede the cursor. Otherwise delete the
  # selected text.
  deleteToBeginningOfWord: ->
    @mutateSelectedText (selection) -> selection.deleteToBeginningOfWord()

  # Extended: For each selection, if the selection is empty, delete all characters
  # of the containing line that precede the cursor. Otherwise delete the
  # selected text.
  deleteToBeginningOfLine: ->
    @mutateSelectedText (selection) -> selection.deleteToBeginningOfLine()

  # Extended: For each selection, if the selection is not empty, deletes the
  # selection; otherwise, deletes all characters of the containing line
  # following the cursor. If the cursor is already at the end of the line,
  # deletes the following newline.
  deleteToEndOfLine: ->
    @mutateSelectedText (selection) -> selection.deleteToEndOfLine()

  # Extended: For each selection, if the selection is empty, delete all characters
  # of the containing word following the cursor. Otherwise delete the selected
  # text.
  deleteToEndOfWord: ->
    @mutateSelectedText (selection) -> selection.deleteToEndOfWord()

  # Extended: Delete all lines intersecting selections.
  deleteLine: ->
    @mutateSelectedText (selection) -> selection.deleteLine()

  # Deprecated: Use {::deleteToBeginningOfWord} instead.
  backspaceToBeginningOfWord: ->
    deprecate("Use TextEditor::deleteToBeginningOfWord() instead")
    @deleteToBeginningOfWord()

  # Deprecated: Use {::deleteToBeginningOfLine} instead.
  backspaceToBeginningOfLine: ->
    deprecate("Use TextEditor::deleteToBeginningOfLine() instead")
    @deleteToBeginningOfLine()

  ###
  Section: History
  ###

  # Essential: Undo the last change.
  undo: ->
    @getLastCursor().needsAutoscroll = true
    @buffer.undo(this)

  # Essential: Redo the last change.
  redo: ->
    @getLastCursor().needsAutoscroll = true
    @buffer.redo(this)

  # Extended: Batch multiple operations as a single undo/redo step.
  #
  # Any group of operations that are logically grouped from the perspective of
  # undoing and redoing should be performed in a transaction. If you want to
  # abort the transaction, call {::abortTransaction} to terminate the function's
  # execution and revert any changes performed up to the abortion.
  #
  # * `groupingInterval` (optional) This is the sames as the `groupingInterval`
  #    parameter in {::beginTransaction}
  # * `fn` A {Function} to call inside the transaction.
  transact: (groupingInterval, fn) -> @buffer.transact(groupingInterval, fn)

  # Extended: Start an open-ended transaction.
  #
  # Call {::commitTransaction} or {::abortTransaction} to terminate the
  # transaction. If you nest calls to transactions, only the outermost
  # transaction is considered. You must match every begin with a matching
  # commit, but a single call to abort will cancel all nested transactions.
  #
  # * `groupingInterval` (optional) The {Number} of milliseconds for which this
  #   transaction should be considered 'groupable' after it begins. If a transaction
  #   with a positive `groupingInterval` is committed while the previous transaction is
  #   still 'groupable', the two transactions are merged with respect to undo and redo.
  beginTransaction: (groupingInterval) -> @buffer.beginTransaction(groupingInterval)

  # Extended: Commit an open-ended transaction started with {::beginTransaction}
  # and push it to the undo stack.
  #
  # If transactions are nested, only the outermost commit takes effect.
  commitTransaction: -> @buffer.commitTransaction()

  # Extended: Abort an open transaction, undoing any operations performed so far
  # within the transaction.
  abortTransaction: -> @buffer.abortTransaction()

  ###
  Section: TextEditor Coordinates
  ###

  # Essential: Convert a position in buffer-coordinates to screen-coordinates.
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

  # Essential: Convert a position in screen-coordinates to buffer-coordinates.
  #
  # The position is clipped via {::clipScreenPosition} prior to the conversion.
  #
  # * `bufferPosition` A {Point} or {Array} of [row, column].
  # * `options` (optional) An options hash for {::clipScreenPosition}.
  #
  # Returns a {Point}.
  bufferPositionForScreenPosition: (screenPosition, options) -> @displayBuffer.bufferPositionForScreenPosition(screenPosition, options)

  # Essential: Convert a range in buffer-coordinates to screen-coordinates.
  #
  # * `bufferRange` {Range} in buffer coordinates to translate into screen coordinates.
  #
  # Returns a {Range}.
  screenRangeForBufferRange: (bufferRange) -> @displayBuffer.screenRangeForBufferRange(bufferRange)

  # Essential: Convert a range in screen-coordinates to buffer-coordinates.
  #
  # * `screenRange` {Range} in screen coordinates to translate into buffer coordinates.
  #
  # Returns a {Range}.
  bufferRangeForScreenRange: (screenRange) -> @displayBuffer.bufferRangeForScreenRange(screenRange)

  # Extended: Clip the given {Point} to a valid position in the buffer.
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

  # Extended: Clip the start and end of the given range to valid positions in the
  # buffer. See {::clipBufferPosition} for more information.
  #
  # * `range` The {Range} to clip.
  #
  # Returns a {Range}.
  clipBufferRange: (range) -> @buffer.clipRange(range)

  # Extended: Clip the given {Point} to a valid position on screen.
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
  # * `screenPosition` The {Point} representing the position to clip.
  # * `options` (optional) {Object}
  #   * `wrapBeyondNewlines` {Boolean} if `true`, continues wrapping past newlines
  #   * `wrapAtSoftNewlines` {Boolean} if `true`, continues wrapping past soft newlines
  #   * `screenLine` {Boolean} if `true`, indicates that you're using a line number, not a row number
  #
  # Returns a {Point}.
  clipScreenPosition: (screenPosition, options) -> @displayBuffer.clipScreenPosition(screenPosition, options)

  ###
  Section: Decorations
  ###

  # Essential: Adds a decoration that tracks a {Marker}. When the marker moves,
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
  # * `decorationParams` An {Object} representing the decoration e.g. `{type: 'gutter', class: 'linter-error'}`
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

  decorationForId: (id) ->
    @displayBuffer.decorationForId(id)

  ###
  Section: Markers
  ###

  # Essential: Create a marker with the given range in buffer coordinates. This
  # marker will maintain its logical location as the buffer is changed, so if
  # you mark a particular word, the marker will remain over that word even if
  # the word's location in the buffer changes.
  #
  # * `range` A {Range} or range-compatible {Array}
  # * `properties` A hash of key-value pairs to associate with the marker. There
  #   are also reserved property names that have marker-specific meaning.
  #   * `reversed` (optional) Creates the marker in a reversed orientation. (default: false)
  #   * `persistent` (optional) Whether to include this marker when serializing the buffer. (default: true)
  #   * `invalidate` (optional) Determines the rules by which changes to the
  #     buffer *invalidate* the marker. (default: 'overlap') It can be any of
  #     the following strategies, in order of fragility
  #     * __never__: The marker is never marked as invalid. This is a good choice for
  #       markers representing selections in an editor.
  #     * __surround__: The marker is invalidated by changes that completely surround it.
  #     * __overlap__: The marker is invalidated by changes that surround the
  #       start or end of the marker. This is the default.
  #     * __inside__: The marker is invalidated by changes that extend into the
  #       inside of the marker. Changes that end at the marker's start or
  #       start at the marker's end do not invalidate the marker.
  #     * __touch__: The marker is invalidated by a change that touches the marked
  #       region in any way, including changes that end at the marker's
  #       start or start at the marker's end. This is the most fragile strategy.
  #
  # Returns a {Marker}.
  markBufferRange: (args...) ->
    @displayBuffer.markBufferRange(args...)

  # Essential: Create a marker with the given range in screen coordinates. This
  # marker will maintain its logical location as the buffer is changed, so if
  # you mark a particular word, the marker will remain over that word even if
  # the word's location in the buffer changes.
  #
  # * `range` A {Range} or range-compatible {Array}
  # * `properties` A hash of key-value pairs to associate with the marker. There
  #   are also reserved property names that have marker-specific meaning.
  #   * `reversed` (optional) Creates the marker in a reversed orientation. (default: false)
  #   * `persistent` (optional) Whether to include this marker when serializing the buffer. (default: true)
  #   * `invalidate` (optional) Determines the rules by which changes to the
  #     buffer *invalidate* the marker. (default: 'overlap') It can be any of
  #     the following strategies, in order of fragility
  #     * __never__: The marker is never marked as invalid. This is a good choice for
  #       markers representing selections in an editor.
  #     * __surround__: The marker is invalidated by changes that completely surround it.
  #     * __overlap__: The marker is invalidated by changes that surround the
  #       start or end of the marker. This is the default.
  #     * __inside__: The marker is invalidated by changes that extend into the
  #       inside of the marker. Changes that end at the marker's start or
  #       start at the marker's end do not invalidate the marker.
  #     * __touch__: The marker is invalidated by a change that touches the marked
  #       region in any way, including changes that end at the marker's
  #       start or start at the marker's end. This is the most fragile strategy.
  #
  # Returns a {Marker}.
  markScreenRange: (args...) ->
    @displayBuffer.markScreenRange(args...)

  # Essential: Mark the given position in buffer coordinates.
  #
  # * `position` A {Point} or {Array} of `[row, column]`.
  # * `options` (optional) See {TextBuffer::markRange}.
  #
  # Returns a {Marker}.
  markBufferPosition: (args...) ->
    @displayBuffer.markBufferPosition(args...)

  # Essential: Mark the given position in screen coordinates.
  #
  # * `position` A {Point} or {Array} of `[row, column]`.
  # * `options` (optional) See {TextBuffer::markRange}.
  #
  # Returns a {Marker}.
  markScreenPosition: (args...) ->
    @displayBuffer.markScreenPosition(args...)

  # Essential: Find all {Marker}s that match the given properties.
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

  # Extended: Get the {Marker} for the given marker id.
  #
  # * `id` {Number} id of the marker
  getMarker: (id) ->
    @displayBuffer.getMarker(id)

  # Extended: Get all {Marker}s. Consider using {::findMarkers}
  getMarkers: ->
    @displayBuffer.getMarkers()

  # Extended: Get the number of markers in this editor's buffer.
  #
  # Returns a {Number}.
  getMarkerCount: ->
    @buffer.getMarkerCount()

  # {Delegates to: DisplayBuffer.destroyMarker}
  destroyMarker: (args...) ->
    @displayBuffer.destroyMarker(args...)

  ###
  Section: Cursors
  ###

  # Essential: Get the position of the most recently added cursor in buffer
  # coordinates.
  #
  # Returns a {Point}
  getCursorBufferPosition: ->
    @getLastCursor().getBufferPosition()

  # Essential: Get the position of all the cursor positions in buffer coordinates.
  #
  # Returns {Array} of {Point}s in the order they were added
  getCursorBufferPositions: ->
    cursor.getBufferPosition() for cursor in @getCursors()

  # Essential: Move the cursor to the given position in buffer coordinates.
  #
  # If there are multiple cursors, they will be consolidated to a single cursor.
  #
  # * `position` A {Point} or {Array} of `[row, column]`
  # * `options` (optional) An {Object} combining options for {::clipScreenPosition} with:
  #   * `autoscroll` Determines whether the editor scrolls to the new cursor's
  #     position. Defaults to true.
  setCursorBufferPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setBufferPosition(position, options)

  # Essential: Get the position of the most recently added cursor in screen
  # coordinates.
  #
  # Returns a {Point}.
  getCursorScreenPosition: ->
    @getLastCursor().getScreenPosition()

  # Essential: Get the position of all the cursor positions in screen coordinates.
  #
  # Returns {Array} of {Point}s in the order the cursors were added
  getCursorScreenPositions: ->
    cursor.getScreenPosition() for cursor in @getCursors()

  # Get the row of the most recently added cursor in screen coordinates.
  #
  # Returns the screen row {Number}.
  getCursorScreenRow: ->
    deprecate('Use `editor.getCursorScreenPosition().row` instead')
    @getCursorScreenPosition().row

  # Essential: Move the cursor to the given position in screen coordinates.
  #
  # If there are multiple cursors, they will be consolidated to a single cursor.
  #
  # * `position` A {Point} or {Array} of `[row, column]`
  # * `options` (optional) An {Object} combining options for {::clipScreenPosition} with:
  #   * `autoscroll` Determines whether the editor scrolls to the new cursor's
  #     position. Defaults to true.
  setCursorScreenPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setScreenPosition(position, options)

  # Essential: Add a cursor at the given position in buffer coordinates.
  #
  # * `bufferPosition` A {Point} or {Array} of `[row, column]`
  #
  # Returns a {Cursor}.
  addCursorAtBufferPosition: (bufferPosition) ->
    @markBufferPosition(bufferPosition, @getSelectionMarkerAttributes())
    @getLastSelection().cursor

  # Essential: Add a cursor at the position in screen coordinates.
  #
  # * `screenPosition` A {Point} or {Array} of `[row, column]`
  #
  # Returns a {Cursor}.
  addCursorAtScreenPosition: (screenPosition) ->
    @markScreenPosition(screenPosition, @getSelectionMarkerAttributes())
    @getLastSelection().cursor

  # Essential: Returns {Boolean} indicating whether or not there are multiple cursors.
  hasMultipleCursors: ->
    @getCursors().length > 1

  # Essential: Move every cursor up one row in screen coordinates.
  #
  # * `lineCount` (optional) {Number} number of lines to move
  moveUp: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveUp(lineCount, moveToEndOfSelection: true)
  moveCursorUp: (lineCount) ->
    deprecate("Use TextEditor::moveUp() instead")
    @moveUp(lineCount)

  # Essential: Move every cursor down one row in screen coordinates.
  #
  # * `lineCount` (optional) {Number} number of lines to move
  moveDown: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveDown(lineCount, moveToEndOfSelection: true)
  moveCursorDown: (lineCount) ->
    deprecate("Use TextEditor::moveDown() instead")
    @moveDown(lineCount)

  # Essential: Move every cursor left one column.
  #
  # * `columnCount` (optional) {Number} number of columns to move (default: 1)
  moveLeft: (columnCount) ->
    @moveCursors (cursor) -> cursor.moveLeft(columnCount, moveToEndOfSelection: true)
  moveCursorLeft: ->
    deprecate("Use TextEditor::moveLeft() instead")
    @moveLeft()

  # Essential: Move every cursor right one column.
  #
  # * `columnCount` (optional) {Number} number of columns to move (default: 1)
  moveRight: (columnCount) ->
    @moveCursors (cursor) -> cursor.moveRight(columnCount, moveToEndOfSelection: true)
  moveCursorRight: ->
    deprecate("Use TextEditor::moveRight() instead")
    @moveRight()

  # Essential: Move every cursor to the beginning of its line in buffer coordinates.
  moveToBeginningOfLine: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfLine()
  moveCursorToBeginningOfLine: ->
    deprecate("Use TextEditor::moveToBeginningOfLine() instead")
    @moveToBeginningOfLine()

  # Essential: Move every cursor to the beginning of its line in screen coordinates.
  moveToBeginningOfScreenLine: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfScreenLine()
  moveCursorToBeginningOfScreenLine: ->
    deprecate("Use TextEditor::moveToBeginningOfScreenLine() instead")
    @moveToBeginningOfScreenLine()

  # Essential: Move every cursor to the first non-whitespace character of its line.
  moveToFirstCharacterOfLine: ->
    @moveCursors (cursor) -> cursor.moveToFirstCharacterOfLine()
  moveCursorToFirstCharacterOfLine: ->
    deprecate("Use TextEditor::moveToFirstCharacterOfLine() instead")
    @moveToFirstCharacterOfLine()

  # Essential: Move every cursor to the end of its line in buffer coordinates.
  moveToEndOfLine: ->
    @moveCursors (cursor) -> cursor.moveToEndOfLine()
  moveCursorToEndOfLine: ->
    deprecate("Use TextEditor::moveToEndOfLine() instead")
    @moveToEndOfLine()

  # Essential: Move every cursor to the end of its line in screen coordinates.
  moveToEndOfScreenLine: ->
    @moveCursors (cursor) -> cursor.moveToEndOfScreenLine()
  moveCursorToEndOfScreenLine: ->
    deprecate("Use TextEditor::moveToEndOfScreenLine() instead")
    @moveToEndOfScreenLine()

  # Essential: Move every cursor to the beginning of its surrounding word.
  moveToBeginningOfWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfWord()
  moveCursorToBeginningOfWord: ->
    deprecate("Use TextEditor::moveToBeginningOfWord() instead")
    @moveToBeginningOfWord()

  # Essential: Move every cursor to the end of its surrounding word.
  moveToEndOfWord: ->
    @moveCursors (cursor) -> cursor.moveToEndOfWord()
  moveCursorToEndOfWord: ->
    deprecate("Use TextEditor::moveToEndOfWord() instead")
    @moveToEndOfWord()

  # Cursor Extended

  # Extended: Move every cursor to the top of the buffer.
  #
  # If there are multiple cursors, they will be merged into a single cursor.
  moveToTop: ->
    @moveCursors (cursor) -> cursor.moveToTop()
  moveCursorToTop: ->
    deprecate("Use TextEditor::moveToTop() instead")
    @moveToTop()

  # Extended: Move every cursor to the bottom of the buffer.
  #
  # If there are multiple cursors, they will be merged into a single cursor.
  moveToBottom: ->
    @moveCursors (cursor) -> cursor.moveToBottom()
  moveCursorToBottom: ->
    deprecate("Use TextEditor::moveToBottom() instead")
    @moveToBottom()

  # Extended: Move every cursor to the beginning of the next word.
  moveToBeginningOfNextWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfNextWord()
  moveCursorToBeginningOfNextWord: ->
    deprecate("Use TextEditor::moveToBeginningOfNextWord() instead")
    @moveToBeginningOfNextWord()

  # Extended: Move every cursor to the previous word boundary.
  moveToPreviousWordBoundary: ->
    @moveCursors (cursor) -> cursor.moveToPreviousWordBoundary()
  moveCursorToPreviousWordBoundary: ->
    deprecate("Use TextEditor::moveToPreviousWordBoundary() instead")
    @moveToPreviousWordBoundary()

  # Extended: Move every cursor to the next word boundary.
  moveToNextWordBoundary: ->
    @moveCursors (cursor) -> cursor.moveToNextWordBoundary()
  moveCursorToNextWordBoundary: ->
    deprecate("Use TextEditor::moveToNextWordBoundary() instead")
    @moveToNextWordBoundary()

  # Extended: Move every cursor to the beginning of the next paragraph.
  moveToBeginningOfNextParagraph: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfNextParagraph()
  moveCursorToBeginningOfNextParagraph: ->
    deprecate("Use TextEditor::moveToBeginningOfNextParagraph() instead")
    @moveToBeginningOfNextParagraph()

  # Extended: Move every cursor to the beginning of the previous paragraph.
  moveToBeginningOfPreviousParagraph: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfPreviousParagraph()
  moveCursorToBeginningOfPreviousParagraph: ->
    deprecate("Use TextEditor::moveToBeginningOfPreviousParagraph() instead")
    @moveToBeginningOfPreviousParagraph()

  # Extended: Returns the most recently added {Cursor}
  getLastCursor: ->
    _.last(@cursors)

  # Deprecated:
  getCursor: ->
    deprecate("Use TextEditor::getLastCursor() instead")
    @getLastCursor()

  # Extended: Returns the word surrounding the most recently added cursor.
  #
  # * `options` (optional) See {Cursor::getBeginningOfCurrentWordBufferPosition}.
  getWordUnderCursor: (options) ->
    @getTextInBufferRange(@getLastCursor().getCurrentWordBufferRange(options))

  # Extended: Get an Array of all {Cursor}s.
  getCursors: ->
    cursor for cursor in @cursors

  # Extended: Get all {Cursors}s, ordered by their position in the buffer
  # instead of the order in which they were added.
  #
  # Returns an {Array} of {Selection}s.
  getCursorsOrderedByBufferPosition: ->
    @getCursors().sort (a, b) -> a.compare(b)

  # Add a cursor based on the given {Marker}.
  addCursor: (marker) ->
    cursor = new Cursor(editor: this, marker: marker)
    @cursors.push(cursor)
    @decorateMarker(marker, type: 'gutter', class: 'cursor-line')
    @decorateMarker(marker, type: 'gutter', class: 'cursor-line-no-selection', onlyHead: true, onlyEmpty: true)
    @decorateMarker(marker, type: 'line', class: 'cursor-line', onlyEmpty: true)
    @emit 'cursor-added', cursor
    @emitter.emit 'did-add-cursor', cursor
    cursor

  # Remove the given cursor from this editor.
  removeCursor: (cursor) ->
    _.remove(@cursors, cursor)
    @emit 'cursor-removed', cursor
    @emitter.emit 'did-remove-cursor', cursor

  moveCursors: (fn) ->
    fn(cursor) for cursor in @getCursors()
    @mergeCursors()

  cursorMoved: (event) ->
    @emit 'cursor-moved', event
    @emitter.emit 'did-change-cursor-position', event

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
    @subscribe @buffer.onWillReload =>
      cursorPosition = @getCursorBufferPosition()
    @subscribe @buffer.onDidReload =>
      @setCursorBufferPosition(cursorPosition) if cursorPosition
      cursorPosition = null

  ###
  Section: Selections
  ###

  # Essential: Get the selected text of the most recently added selection.
  #
  # Returns a {String}.
  getSelectedText: ->
    @getLastSelection().getText()

  # Essential: Get the {Range} of the most recently added selection in buffer
  # coordinates.
  #
  # Returns a {Range}.
  getSelectedBufferRange: ->
    @getLastSelection().getBufferRange()

  # Essential: Get the {Range}s of all selections in buffer coordinates.
  #
  # The ranges are sorted by when the selections were added. Most recent at the end.
  #
  # Returns an {Array} of {Range}s.
  getSelectedBufferRanges: ->
    selection.getBufferRange() for selection in @getSelections()

  # Essential: Set the selected range in buffer coordinates. If there are multiple
  # selections, they are reduced to a single selection with the given range.
  #
  # * `bufferRange` A {Range} or range-compatible {Array}.
  # * `options` (optional) An options {Object}:
  #   * `reversed` A {Boolean} indicating whether to create the selection in a
  #     reversed orientation.
  setSelectedBufferRange: (bufferRange, options) ->
    @setSelectedBufferRanges([bufferRange], options)

  # Essential: Set the selected ranges in buffer coordinates. If there are multiple
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

  # Essential: Get the {Range} of the most recently added selection in screen
  # coordinates.
  #
  # Returns a {Range}.
  getSelectedScreenRange: ->
    @getLastSelection().getScreenRange()

  # Essential: Get the {Range}s of all selections in screen coordinates.
  #
  # The ranges are sorted by when the selections were added. Most recent at the end.
  #
  # Returns an {Array} of {Range}s.
  getSelectedScreenRanges: ->
    selection.getScreenRange() for selection in @getSelections()

  # Essential: Set the selected range in screen coordinates. If there are multiple
  # selections, they are reduced to a single selection with the given range.
  #
  # * `screenRange` A {Range} or range-compatible {Array}.
  # * `options` (optional) An options {Object}:
  #   * `reversed` A {Boolean} indicating whether to create the selection in a
  #     reversed orientation.
  setSelectedScreenRange: (screenRange, options) ->
    @setSelectedBufferRange(@bufferRangeForScreenRange(screenRange, options), options)

  # Essential: Set the selected ranges in screen coordinates. If there are multiple
  # selections, they are replaced by new selections with the given ranges.
  #
  # * `screenRanges` An {Array} of {Range}s or range-compatible {Array}s.
  # * `options` (optional) An options {Object}:
  #   * `reversed` A {Boolean} indicating whether to create the selection in a
  #     reversed orientation.
  setSelectedScreenRanges: (screenRanges, options={}) ->
    throw new Error("Passed an empty array to setSelectedScreenRanges") unless screenRanges.length

    selections = @getSelections()
    selection.destroy() for selection in selections[screenRanges.length...]

    @mergeIntersectingSelections options, =>
      for screenRange, i in screenRanges
        screenRange = Range.fromObject(screenRange)
        if selections[i]
          selections[i].setScreenRange(screenRange, options)
        else
          @addSelectionForScreenRange(screenRange, options)

  # Essential: Add a selection for the given range in buffer coordinates.
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

  # Essential: Add a selection for the given range in screen coordinates.
  #
  # * `screenRange` A {Range}
  # * `options` (optional) An options {Object}:
  #   * `reversed` A {Boolean} indicating whether to create the selection in a
  #     reversed orientation.
  #
  # Returns the added {Selection}.
  addSelectionForScreenRange: (screenRange, options={}) ->
    @markScreenRange(screenRange, _.defaults(@getSelectionMarkerAttributes(), options))
    selection = @getLastSelection()
    selection.autoscroll() if @manageScrollPosition
    selection

  # Essential: Select from the current cursor position to the given position in
  # buffer coordinates.
  #
  # This method may merge selections that end up intesecting.
  #
  # * `position` An instance of {Point}, with a given `row` and `column`.
  selectToBufferPosition: (position) ->
    lastSelection = @getLastSelection()
    lastSelection.selectToBufferPosition(position)
    @mergeIntersectingSelections(reversed: lastSelection.isReversed())

  # Essential: Select from the current cursor position to the given position in
  # screen coordinates.
  #
  # This method may merge selections that end up intesecting.
  #
  # * `position` An instance of {Point}, with a given `row` and `column`.
  selectToScreenPosition: (position) ->
    lastSelection = @getLastSelection()
    lastSelection.selectToScreenPosition(position)
    @mergeIntersectingSelections(reversed: lastSelection.isReversed())

  # Essential: Move the cursor of each selection one character upward while
  # preserving the selection's tail position.
  #
  # * `rowCount` (optional) {Number} number of rows to select (default: 1)
  #
  # This method may merge selections that end up intesecting.
  selectUp: (rowCount) ->
    @expandSelectionsBackward (selection) -> selection.selectUp(rowCount)

  # Essential: Move the cursor of each selection one character downward while
  # preserving the selection's tail position.
  #
  # * `rowCount` (optional) {Number} number of rows to select (default: 1)
  #
  # This method may merge selections that end up intesecting.
  selectDown: (rowCount) ->
    @expandSelectionsForward (selection) -> selection.selectDown(rowCount)

  # Essential: Move the cursor of each selection one character leftward while
  # preserving the selection's tail position.
  #
  # * `columnCount` (optional) {Number} number of columns to select (default: 1)
  #
  # This method may merge selections that end up intesecting.
  selectLeft: (columnCount) ->
    @expandSelectionsBackward (selection) -> selection.selectLeft(columnCount)

  # Essential: Move the cursor of each selection one character rightward while
  # preserving the selection's tail position.
  #
  # * `columnCount` (optional) {Number} number of columns to select (default: 1)
  #
  # This method may merge selections that end up intesecting.
  selectRight: (columnCount) ->
    @expandSelectionsForward (selection) -> selection.selectRight(columnCount)

  # Essential: Select from the top of the buffer to the end of the last selection
  # in the buffer.
  #
  # This method merges multiple selections into a single selection.
  selectToTop: ->
    @expandSelectionsBackward (selection) -> selection.selectToTop()

  # Essential: Selects from the top of the first selection in the buffer to the end
  # of the buffer.
  #
  # This method merges multiple selections into a single selection.
  selectToBottom: ->
    @expandSelectionsForward (selection) -> selection.selectToBottom()

  # Essential: Select all text in the buffer.
  #
  # This method merges multiple selections into a single selection.
  selectAll: ->
    @expandSelectionsForward (selection) -> selection.selectAll()

  # Essential: Move the cursor of each selection to the beginning of its line
  # while preserving the selection's tail position.
  #
  # This method may merge selections that end up intesecting.
  selectToBeginningOfLine: ->
    @expandSelectionsBackward (selection) -> selection.selectToBeginningOfLine()

  # Essential: Move the cursor of each selection to the first non-whitespace
  # character of its line while preserving the selection's tail position. If the
  # cursor is already on the first character of the line, move it to the
  # beginning of the line.
  #
  # This method may merge selections that end up intersecting.
  selectToFirstCharacterOfLine: ->
    @expandSelectionsBackward (selection) -> selection.selectToFirstCharacterOfLine()

  # Essential: Move the cursor of each selection to the end of its line while
  # preserving the selection's tail position.
  #
  # This method may merge selections that end up intersecting.
  selectToEndOfLine: ->
    @expandSelectionsForward (selection) -> selection.selectToEndOfLine()

  # Essential: Expand selections to the beginning of their containing word.
  #
  # Operates on all selections. Moves the cursor to the beginning of the
  # containing word while preserving the selection's tail position.
  selectToBeginningOfWord: ->
    @expandSelectionsBackward (selection) -> selection.selectToBeginningOfWord()

  # Essential: Expand selections to the end of their containing word.
  #
  # Operates on all selections. Moves the cursor to the end of the containing
  # word while preserving the selection's tail position.
  selectToEndOfWord: ->
    @expandSelectionsForward (selection) -> selection.selectToEndOfWord()

  # Essential: For each cursor, select the containing line.
  #
  # This method merges selections on successive lines.
  selectLinesContainingCursors: ->
    @expandSelectionsForward (selection) -> selection.selectLine()
  selectLine: ->
    deprecate('Use TextEditor::selectLinesContainingCursors instead')
    @selectLinesContainingCursors()

  # Essential: Select the word surrounding each cursor.
  selectWordsContainingCursors: ->
    @expandSelectionsForward (selection) -> selection.selectWord()
  selectWord: ->
    deprecate('Use TextEditor::selectWordsContainingCursors instead')
    @selectWordsContainingCursors()

  # Selection Extended

  # Extended: For each selection, move its cursor to the preceding word boundary
  # while maintaining the selection's tail position.
  #
  # This method may merge selections that end up intersecting.
  selectToPreviousWordBoundary: ->
    @expandSelectionsBackward (selection) -> selection.selectToPreviousWordBoundary()

  # Extended: For each selection, move its cursor to the next word boundary while
  # maintaining the selection's tail position.
  #
  # This method may merge selections that end up intersecting.
  selectToNextWordBoundary: ->
    @expandSelectionsForward (selection) -> selection.selectToNextWordBoundary()

  # Extended: Expand selections to the beginning of the next word.
  #
  # Operates on all selections. Moves the cursor to the beginning of the next
  # word while preserving the selection's tail position.
  selectToBeginningOfNextWord: ->
    @expandSelectionsForward (selection) -> selection.selectToBeginningOfNextWord()

  # Extended: Expand selections to the beginning of the next paragraph.
  #
  # Operates on all selections. Moves the cursor to the beginning of the next
  # paragraph while preserving the selection's tail position.
  selectToBeginningOfNextParagraph: ->
    @expandSelectionsForward (selection) -> selection.selectToBeginningOfNextParagraph()

  # Extended: Expand selections to the beginning of the next paragraph.
  #
  # Operates on all selections. Moves the cursor to the beginning of the next
  # paragraph while preserving the selection's tail position.
  selectToBeginningOfPreviousParagraph: ->
    @expandSelectionsBackward (selection) -> selection.selectToBeginningOfPreviousParagraph()

  # Extended: Select the range of the given marker if it is valid.
  #
  # * `marker` A {Marker}
  #
  # Returns the selected {Range} or `undefined` if the marker is invalid.
  selectMarker: (marker) ->
    if marker.isValid()
      range = marker.getBufferRange()
      @setSelectedBufferRange(range)
      range

  # Extended: Get the most recently added {Selection}.
  #
  # Returns a {Selection}.
  getLastSelection: ->
    _.last(@selections)

  # Deprecated:
  getSelection: (index) ->
    if index?
      deprecate("Use TextEditor::getSelections()[index] instead when getting a specific selection")
      @getSelections()[index]
    else
      deprecate("Use TextEditor::getLastSelection() instead")
      @getLastSelection()

  # Extended: Get current {Selection}s.
  #
  # Returns: An {Array} of {Selection}s.
  getSelections: ->
    selection for selection in @selections

  # Extended: Get all {Selection}s, ordered by their position in the buffer
  # instead of the order in which they were added.
  #
  # Returns an {Array} of {Selection}s.
  getSelectionsOrderedByBufferPosition: ->
    @getSelections().sort (a, b) -> a.compare(b)

  # Extended: Determine if a given range in buffer coordinates intersects a
  # selection.
  #
  # * `bufferRange` A {Range} or range-compatible {Array}.
  #
  # Returns a {Boolean}.
  selectionIntersectsBufferRange: (bufferRange) ->
    _.any @getSelections(), (selection) ->
      selection.intersectsBufferRange(bufferRange)

  # Selections Private

  # Add a similarly-shaped selection to the next eligible line below
  # each selection.
  #
  # Operates on all selections. If the selection is empty, adds an empty
  # selection to the next following non-empty line as close to the current
  # selection's column as possible. If the selection is non-empty, adds a
  # selection to the next line that is long enough for a non-empty selection
  # starting at the same column as the current selection to be added to it.
  addSelectionBelow: ->
    @expandSelectionsForward (selection) -> selection.addSelectionBelow()

  # Add a similarly-shaped selection to the next eligible line above
  # each selection.
  #
  # Operates on all selections. If the selection is empty, adds an empty
  # selection to the next preceding non-empty line as close to the current
  # selection's column as possible. If the selection is non-empty, adds a
  # selection to the next line that is long enough for a non-empty selection
  # starting at the same column as the current selection to be added to it.
  addSelectionAbove: ->
    @expandSelectionsBackward (selection) -> selection.addSelectionAbove()

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

  selectionsForScreenRows: (startRow, endRow) ->
    @getSelections().filter (selection) -> selection.intersectsScreenRowRange(startRow, endRow)

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

  # Add a {Selection} based on the given {Marker}.
  #
  # * `marker` The {Marker} to highlight
  # * `options` (optional) An {Object} that pertains to the {Selection} constructor.
  #
  # Returns the new {Selection}.
  addSelection: (marker, options={}) ->
    unless marker.getProperties().preserveFolds
      @destroyFoldsIntersectingBufferRange(marker.getBufferRange())
    cursor = @addCursor(marker)
    selection = new Selection(_.extend({editor: this, marker, cursor}, options))
    @selections.push(selection)
    selectionBufferRange = selection.getBufferRange()
    @mergeIntersectingSelections(preserveFolds: marker.getProperties().preserveFolds)
    if selection.destroyed
      for selection in @getSelections()
        if selection.intersectsBufferRange(selectionBufferRange)
          return selection
    else
      @emit 'selection-added', selection
      @emitter.emit 'did-add-selection', selection
      selection

  # Remove the given selection.
  removeSelection: (selection) ->
    _.remove(@selections, selection)
    @emit 'selection-removed', selection
    @emitter.emit 'did-remove-selection', selection

  # Reduce one or more selections to a single empty selection based on the most
  # recently added cursor.
  clearSelections: ->
    @consolidateSelections()
    @getLastSelection().clear()

  # Reduce multiple selections to the most recently added selection.
  consolidateSelections: ->
    selections = @getSelections()
    if selections.length > 1
      selection.destroy() for selection in selections[0...-1]
      true
    else
      false

  # Called by the selection
  selectionRangeChanged: (event) ->
    @emit 'selection-screen-range-changed', event
    @emitter.emit 'did-change-selection-range', event

  ###
  Section: Searching and Replacing
  ###

  # Essential: Scan regular expression matches in the entire buffer, calling the
  # given iterator function on each match.
  #
  # `::scan` functions as the replace method as well via the `replace`
  #
  # If you're programmatically modifying the results, you may want to try
  # {::backwardsScanInBufferRange} to avoid tripping over your own changes.
  #
  # * `regex` A {RegExp} to search for.
  # * `iterator` A {Function} that's called on each match
  #   * `object` {Object}
  #     * `match` The current regular expression match.
  #     * `matchText` A {String} with the text of the match.
  #     * `range` The {Range} of the match.
  #     * `stop` Call this {Function} to terminate the scan.
  #     * `replace` Call this {Function} with a {String} to replace the match.
  scan: (regex, iterator) -> @buffer.scan(regex, iterator)

  # Public: Scan regular expression matches in a given range, calling the given
  # iterator function on each match.
  #
  # * `regex` A {RegExp} to search for.
  # * `range` A {Range} in which to search.
  # * `iterator` A {Function} that's called on each match with an {Object}
  #   containing the following keys:
  #   * `match` The current regular expression match.
  #   * `matchText` A {String} with the text of the match.
  #   * `range` The {Range} of the match.
  #   * `stop` Call this {Function} to terminate the scan.
  #   * `replace` Call this {Function} with a {String} to replace the match.
  scanInBufferRange: (regex, range, iterator) -> @buffer.scanInRange(regex, range, iterator)

  # Public: Scan regular expression matches in a given range in reverse order,
  # calling the given iterator function on each match.
  #
  # * `regex` A {RegExp} to search for.
  # * `range` A {Range} in which to search.
  # * `iterator` A {Function} that's called on each match with an {Object}
  #   containing the following keys:
  #   * `match` The current regular expression match.
  #   * `matchText` A {String} with the text of the match.
  #   * `range` The {Range} of the match.
  #   * `stop` Call this {Function} to terminate the scan.
  #   * `replace` Call this {Function} with a {String} to replace the match.
  backwardsScanInBufferRange: (regex, range, iterator) -> @buffer.backwardsScanInRange(regex, range, iterator)

  ###
  Section: Tab Behavior
  ###

  # Essential: Returns a {Boolean} indicating whether softTabs are enabled for this
  # editor.
  getSoftTabs: -> @softTabs

  # Essential: Enable or disable soft tabs for this editor.
  #
  # * `softTabs` A {Boolean}
  setSoftTabs: (@softTabs) -> @softTabs

  # Essential: Toggle soft tabs for this editor
  toggleSoftTabs: -> @setSoftTabs(not @getSoftTabs())

  # Essential: Get the on-screen length of tab characters.
  #
  # Returns a {Number}.
  getTabLength: -> @displayBuffer.getTabLength()

  # Essential: Set the on-screen length of tab characters. Setting this to a
  # {Number} This will override the `editor.tabLength` setting.
  #
  # * `tabLength` {Number} length of a single tab. Setting to `null` will
  #   fallback to using the `editor.tabLength` config setting
  setTabLength: (tabLength) -> @displayBuffer.setTabLength(tabLength)

  # Extended: Determine if the buffer uses hard or soft tabs.
  #
  # Returns `true` if the first non-comment line with leading whitespace starts
  # with a space character. Returns `false` if it starts with a hard tab (`\t`).
  #
  # Returns a {Boolean} or undefined if no non-comment lines had leading
  # whitespace.
  usesSoftTabs: ->
    for bufferRow in [0..@buffer.getLastRow()]
      continue if @displayBuffer.tokenizedBuffer.tokenizedLineForRow(bufferRow).isComment()

      line = @buffer.lineForRow(bufferRow)
      return true  if line[0] is ' '
      return false if line[0] is '\t'

    undefined

  # Extended: Get the text representing a single level of indent.
  #
  # If soft tabs are enabled, the text is composed of N spaces, where N is the
  # tab length. Otherwise the text is a tab character (`\t`).
  #
  # Returns a {String}.
  getTabText: -> @buildIndentString(1)

  # If soft tabs are enabled, convert all hard tabs to soft tabs in the given
  # {Range}.
  normalizeTabsInBufferRange: (bufferRange) ->
    return unless @getSoftTabs()
    @scanInBufferRange /\t/g, bufferRange, ({replace}) => replace(@getTabText())

  ###
  Section: Soft Wrap Behavior
  ###

  # Essential: Determine whether lines in this editor are soft-wrapped.
  #
  # Returns a {Boolean}.
  isSoftWrapped: (softWrapped) -> @displayBuffer.isSoftWrapped()
  getSoftWrapped: ->
    deprecate("Use TextEditor::isSoftWrapped instead")
    @displayBuffer.isSoftWrapped()

  # Essential: Enable or disable soft wrapping for this editor.
  #
  # * `softWrapped` A {Boolean}
  #
  # Returns a {Boolean}.
  setSoftWrapped: (softWrapped) -> @displayBuffer.setSoftWrapped(softWrapped)
  setSoftWrap: (softWrapped) ->
    deprecate("Use TextEditor::setSoftWrapped instead")
    @setSoftWrapped(softWrapped)

  # Essential: Toggle soft wrapping for this editor
  #
  # Returns a {Boolean}.
  toggleSoftWrapped: -> @setSoftWrapped(not @isSoftWrapped())
  toggleSoftWrap: ->
    deprecate("Use TextEditor::toggleSoftWrapped instead")
    @toggleSoftWrapped()

  # Public: Gets the column at which column will soft wrap
  getSoftWrapColumn: -> @displayBuffer.getSoftWrapColumn()

  ###
  Section: Indentation
  ###

  # Essential: Get the indentation level of the given a buffer row.
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
    @indentLevelForLine(@lineTextForBufferRow(bufferRow))

  # Essential: Set the indentation level for the given buffer row.
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
      endColumn = @lineTextForBufferRow(bufferRow).match(/^\s*/)[0].length
    newIndentString = @buildIndentString(newLevel)
    @buffer.setTextInRange([[bufferRow, 0], [bufferRow, endColumn]], newIndentString)

  # Extended: Indent rows intersecting selections by one level.
  indentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.indentSelectedRows()

  # Extended: Outdent rows intersecting selections by one level.
  outdentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.outdentSelectedRows()

  # Extended: Get the indentation level of the given line of text.
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

  # Extended: Indent rows intersecting selections based on the grammar's suggested
  # indent level.
  autoIndentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.autoIndentSelectedRows()

  # Indent all lines intersecting selections. See {Selection::indent} for more
  # information.
  indent: (options={}) ->
    options.autoIndent ?= @shouldAutoIndent()
    @mutateSelectedText (selection) -> selection.indent(options)

  # Constructs the string used for tabs.
  buildIndentString: (number, column=0) ->
    if @getSoftTabs()
      tabStopViolation = column % @getTabLength()
      _.multiplyString(" ", Math.floor(number * @getTabLength()) - tabStopViolation)
    else
      _.multiplyString("\t", Math.floor(number))

  ###
  Section: Grammars
  ###

  # Essential: Get the current {Grammar} of this editor.
  getGrammar: ->
    @displayBuffer.getGrammar()

  # Essential: Set the current {Grammar} of this editor.
  #
  # Assigning a grammar will cause the editor to re-tokenize based on the new
  # grammar.
  #
  # * `grammar` {Grammar}
  setGrammar: (grammar) ->
    @displayBuffer.setGrammar(grammar)

  # Reload the grammar based on the file name.
  reloadGrammar: ->
    @displayBuffer.reloadGrammar()

  ###
  Section: Managing Syntax Scopes
  ###

  # Essential: Returns a {ScopeDescriptor} that includes this editor's language.
  # e.g. `['.source.ruby']`, or `['.source.coffee']`. You can use this with
  # {Config::get} to get language specific config values.
  getRootScopeDescriptor: ->
    @displayBuffer.getRootScopeDescriptor()

  # Essential: Get the syntactic scopeDescriptor for the given position in buffer
  # coordinates. Useful with {Config::get}.
  #
  # For example, if called with a position inside the parameter list of an
  # anonymous CoffeeScript function, the method returns the following array:
  # `["source.coffee", "meta.inline.function.coffee", "variable.parameter.function.coffee"]`
  #
  # * `bufferPosition` A {Point} or {Array} of [row, column].
  #
  # Returns a {ScopeDescriptor}.
  scopeDescriptorForBufferPosition: (bufferPosition) ->
    @displayBuffer.scopeDescriptorForBufferPosition(bufferPosition)
  scopesForBufferPosition: (bufferPosition) ->
    deprecate 'Use ::scopeDescriptorForBufferPosition instead. The return value has changed! It now returns a `ScopeDescriptor`'
    @scopeDescriptorForBufferPosition(bufferPosition).getScopesArray()

  # Extended: Get the range in buffer coordinates of all tokens surrounding the
  # cursor that match the given scope selector.
  #
  # For example, if you wanted to find the string surrounding the cursor, you
  # could call `editor.bufferRangeForScopeAtCursor(".string.quoted")`.
  #
  # * `scopeSelector` {String} selector. e.g. `'.source.ruby'`
  #
  # Returns a {Range}.
  bufferRangeForScopeAtCursor: (scopeSelector) ->
    @displayBuffer.bufferRangeForScopeAtPosition(scopeSelector, @getCursorBufferPosition())

  # Extended: Determine if the given row is entirely a comment
  isBufferRowCommented: (bufferRow) ->
    if match = @lineTextForBufferRow(bufferRow).match(/\S/)
      scopeDescriptor = @tokenForBufferPosition([bufferRow, match.index]).scopes
      @commentScopeSelector ?= new TextMateScopeSelector('comment.*')
      @commentScopeSelector.matches(scopeDescriptor)

  logCursorScope: ->
    console.log @getLastCursor().getScopeDescriptor()

  # {Delegates to: DisplayBuffer.tokenForBufferPosition}
  tokenForBufferPosition: (bufferPosition) -> @displayBuffer.tokenForBufferPosition(bufferPosition)

  scopesAtCursor: ->
    deprecate 'Use editor.getLastCursor().getScopeDescriptor() instead'
    @getLastCursor().getScopeDescriptor().getScopesArray()
  getCursorScopes: ->
    deprecate 'Use editor.getLastCursor().getScopeDescriptor() instead'
    @scopesAtCursor()

  ###
  Section: Clipboard Operations
  ###

  # Essential: For each selection, copy the selected text.
  copySelectedText: ->
    maintainClipboard = false
    for selection in @getSelections()
      selection.copy(maintainClipboard)
      maintainClipboard = true

  # Essential: For each selection, cut the selected text.
  cutSelectedText: ->
    maintainClipboard = false
    @mutateSelectedText (selection) ->
      selection.cut(maintainClipboard)
      maintainClipboard = true

  # Essential: For each selection, replace the selected text with the contents of
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

    else if atom.config.get(@getLastCursor().getScopeDescriptor(), "editor.normalizeIndentOnPaste") and metadata?.indentBasis?
      if !@getLastCursor().hasPrecedingCharactersOnLine() or containsNewlines
        options.indentBasis ?= metadata.indentBasis

    @insertText(text, options)

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

  # Essential: Fold the most recent cursor's row based on its indentation level.
  #
  # The fold will extend from the nearest preceding line with a lower
  # indentation level up to the nearest following row with a lower indentation
  # level.
  foldCurrentRow: ->
    bufferRow = @bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @foldBufferRow(bufferRow)

  # Essential: Unfold the most recent cursor's row by one level.
  unfoldCurrentRow: ->
    bufferRow = @bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @unfoldBufferRow(bufferRow)

  # Essential: Fold the given row in buffer coordinates based on its indentation
  # level.
  #
  # If the given row is foldable, the fold will begin there. Otherwise, it will
  # begin at the first foldable row preceding the given row.
  #
  # * `bufferRow` A {Number}.
  foldBufferRow: (bufferRow) ->
    @languageMode.foldBufferRow(bufferRow)

  # Essential: Unfold all folds containing the given row in buffer coordinates.
  #
  # * `bufferRow` A {Number}
  unfoldBufferRow: (bufferRow) ->
    @displayBuffer.unfoldBufferRow(bufferRow)

  # Extended: For each selection, fold the rows it intersects.
  foldSelectedLines: ->
    selection.fold() for selection in @getSelections()

  # Extended: Fold all foldable lines.
  foldAll: ->
    @languageMode.foldAll()

  # Extended: Unfold all existing folds.
  unfoldAll: ->
    @languageMode.unfoldAll()

  # Extended: Fold all foldable lines at the given indent level.
  #
  # * `level` A {Number}.
  foldAllAtIndentLevel: (level) ->
    @languageMode.foldAllAtIndentLevel(level)

  # Extended: Determine whether the given row in buffer coordinates is foldable.
  #
  # A *foldable* row is a row that *starts* a row range that can be folded.
  #
  # * `bufferRow` A {Number}
  #
  # Returns a {Boolean}.
  isFoldableAtBufferRow: (bufferRow) ->
    @languageMode.isFoldableAtBufferRow(bufferRow)

  # Extended: Determine whether the given row in screen coordinates is foldable.
  #
  # A *foldable* row is a row that *starts* a row range that can be folded.
  #
  # * `bufferRow` A {Number}
  #
  # Returns a {Boolean}.
  isFoldableAtScreenRow: (screenRow) ->
    bufferRow = @displayBuffer.bufferRowForScreenRow(screenRow)
    @isFoldableAtBufferRow(bufferRow)

  # Extended: Fold the given buffer row if it isn't currently folded, and unfold
  # it otherwise.
  toggleFoldAtBufferRow: (bufferRow) ->
    if @isFoldedAtBufferRow(bufferRow)
      @unfoldBufferRow(bufferRow)
    else
      @foldBufferRow(bufferRow)

  # Extended: Determine whether the most recently added cursor's row is folded.
  #
  # Returns a {Boolean}.
  isFoldedAtCursorRow: ->
    @isFoldedAtScreenRow(@getCursorScreenPosition().row)

  # Extended: Determine whether the given row in buffer coordinates is folded.
  #
  # * `bufferRow` A {Number}
  #
  # Returns a {Boolean}.
  isFoldedAtBufferRow: (bufferRow) ->
    @displayBuffer.isFoldedAtBufferRow(bufferRow)

  # Extended: Determine whether the given row in screen coordinates is folded.
  #
  # * `screenRow` A {Number}
  #
  # Returns a {Boolean}.
  isFoldedAtScreenRow: (screenRow) ->
    @displayBuffer.isFoldedAtScreenRow(screenRow)

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
  Section: Scrolling the TextEditor
  ###

  # Essential: Scroll the editor to reveal the most recently added cursor if it is
  # off-screen.
  #
  # * `options` (optional) {Object}
  #   * `center` Center the editor around the cursor if possible. (default: true)
  scrollToCursorPosition: (options) ->
    @getLastCursor().autoscroll(center: options?.center ? true)

  # Essential: Scrolls the editor to the given buffer position.
  #
  # * `bufferPosition` An object that represents a buffer position. It can be either
  #   an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # * `options` (optional) {Object}
  #   * `center` Center the editor around the position if possible. (default: false)
  scrollToBufferPosition: (bufferPosition, options) ->
    @displayBuffer.scrollToBufferPosition(bufferPosition, options)

  # Essential: Scrolls the editor to the given screen position.
  #
  # * `screenPosition` An object that represents a buffer position. It can be either
  #    an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # * `options` (optional) {Object}
  #   * `center` Center the editor around the position if possible. (default: false)
  scrollToScreenPosition: (screenPosition, options) ->
    @displayBuffer.scrollToScreenPosition(screenPosition, options)

  # Essential: Scrolls the editor to the top
  scrollToTop: ->
    @setScrollTop(0)

  # Essential: Scrolls the editor to the bottom
  scrollToBottom: ->
    @setScrollBottom(Infinity)

  scrollToScreenRange: (screenRange, options) -> @displayBuffer.scrollToScreenRange(screenRange, options)

  horizontallyScrollable: -> @displayBuffer.horizontallyScrollable()

  verticallyScrollable: -> @displayBuffer.verticallyScrollable()

  getHorizontalScrollbarHeight: -> @displayBuffer.getHorizontalScrollbarHeight()
  setHorizontalScrollbarHeight: (height) -> @displayBuffer.setHorizontalScrollbarHeight(height)

  getVerticalScrollbarWidth: -> @displayBuffer.getVerticalScrollbarWidth()
  setVerticalScrollbarWidth: (width) -> @displayBuffer.setVerticalScrollbarWidth(width)

  pageUp: ->
    newScrollTop = @getScrollTop() - @getHeight()
    @moveUp(@getRowsPerPage())
    @setScrollTop(newScrollTop)

  pageDown: ->
    newScrollTop = @getScrollTop() + @getHeight()
    @moveDown(@getRowsPerPage())
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
    atom.config.get(@getRootScopeDescriptor(), "editor.autoIndent")

  shouldShowInvisibles: ->
    not @mini and atom.config.get(@getRootScopeDescriptor(), 'editor.showInvisibles')

  updateInvisibles: ->
    if @shouldShowInvisibles()
      @displayBuffer.setInvisibles(atom.config.get(@getRootScopeDescriptor(), 'editor.invisibles'))
    else
      @displayBuffer.setInvisibles(null)

  ###
  Section: Event Handlers
  ###

  handleTokenization: ->
    @softTabs = @usesSoftTabs() ? @softTabs

  handleGrammarChange: ->
    @updateInvisibles()
    @subscribeToScopedConfigSettings()
    @unfoldAll()
    @emit 'grammar-changed'
    @emitter.emit 'did-change-grammar'

  handleMarkerCreated: (marker) =>
    if marker.matchesProperties(@getSelectionMarkerAttributes())
      @addSelection(marker)

  ###
  Section: TextEditor Rendering
  ###

  # Public: Retrieves the greyed out placeholder of a mini editor.
  #
  # Returns a {String}.
  getPlaceholderText: ->
    @placeholderText

  # Public: Set the greyed out placeholder of a mini editor. Placeholder text
  # will be displayed when the editor has no content.
  #
  # * `placeholderText` {String} text that is displayed when the editor has no content.
  setPlaceholderText: (placeholderText) ->
    return if @placeholderText is placeholderText
    @placeholderText = placeholderText
    @emitter.emit 'did-change-placeholder-text', @placeholderText

  # Extended: Retrieves the number of the row that is visible and currently at the
  # top of the editor.
  #
  # Returns a {Number}.
  getFirstVisibleScreenRow: ->
    @getVisibleRowRange()[0]

  # Extended: Retrieves the number of the row that is visible and currently at the
  # bottom of the editor.
  #
  # Returns a {Number}.
  getLastVisibleScreenRow: ->
    @getVisibleRowRange()[1]

  # Extended: Converts a buffer position to a pixel position.
  #
  # * `bufferPosition` An object that represents a buffer position. It can be either
  #   an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  #
  # Returns an {Object} with two values: `top` and `left`, representing the pixel positions.
  pixelPositionForBufferPosition: (bufferPosition) -> @displayBuffer.pixelPositionForBufferPosition(bufferPosition)

  # Extended: Converts a screen position to a pixel position.
  #
  # * `screenPosition` An object that represents a screen position. It can be either
  #   an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  #
  # Returns an {Object} with two values: `top` and `left`, representing the pixel positions.
  pixelPositionForScreenPosition: (screenPosition) -> @displayBuffer.pixelPositionForScreenPosition(screenPosition)

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

  screenPositionForPixelPosition: (pixelPosition) -> @displayBuffer.screenPositionForPixelPosition(pixelPosition)

  pixelRectForScreenRange: (screenRange) -> @displayBuffer.pixelRectForScreenRange(screenRange)

  # Deprecated: Call {::joinLines} instead.
  joinLine: ->
    deprecate("Use TextEditor::joinLines() instead")
    @joinLines()

  ###
  Section: Utility
  ###

  inspect: ->
    "<TextEditor #{@id}>"

  logScreenLines: (start, end) -> @displayBuffer.logLines(start, end)
