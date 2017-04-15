_ = require 'underscore-plus'
path = require 'path'
fs = require 'fs-plus'
Grim = require 'grim'
{CompositeDisposable, Disposable, Emitter} = require 'event-kit'
{Point, Range} = TextBuffer = require 'text-buffer'
LanguageMode = require './language-mode'
DecorationManager = require './decoration-manager'
TokenizedBuffer = require './tokenized-buffer'
Cursor = require './cursor'
Model = require './model'
Selection = require './selection'
TextMateScopeSelector = require('first-mate').ScopeSelector
GutterContainer = require './gutter-container'
TextEditorComponent = null
{isDoubleWidthCharacter, isHalfWidthCharacter, isKoreanCharacter, isWrapBoundary} = require './text-utils'

ZERO_WIDTH_NBSP = '\ufeff'
MAX_SCREEN_LINE_LENGTH = 500

# Essential: This class represents all essential editing state for a single
# {TextBuffer}, including cursor and selection positions, folds, and soft wraps.
# If you're manipulating the state of an editor, use this class.
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
  @setClipboard: (clipboard) ->
    @clipboard = clipboard

  @setScheduler: (scheduler) ->
    TextEditorComponent ?= require './text-editor-component'
    TextEditorComponent.setScheduler(scheduler)

  @didUpdateStyles: ->
    TextEditorComponent ?= require './text-editor-component'
    TextEditorComponent.didUpdateStyles()

  @didUpdateScrollbarStyles: ->
    TextEditorComponent ?= require './text-editor-component'
    TextEditorComponent.didUpdateScrollbarStyles()

  @viewForItem: (item) -> item.element ? item

  serializationVersion: 1

  buffer: null
  languageMode: null
  cursors: null
  showCursorOnSelection: null
  selections: null
  suppressSelectionMerging: false
  selectionFlashDuration: 500
  gutterContainer: null
  editorElement: null
  verticalScrollMargin: 2
  horizontalScrollMargin: 6
  softWrapped: null
  editorWidthInChars: null
  lineHeightInPixels: null
  defaultCharWidth: null
  height: null
  width: null
  registered: false
  atomicSoftTabs: true
  invisibles: null
  showLineNumbers: true
  scrollSensitivity: 40

  Object.defineProperty @prototype, "element",
    get: -> @getElement()

  Object.defineProperty(@prototype, 'displayBuffer', get: ->
    Grim.deprecate("""
      `TextEditor.prototype.displayBuffer` has always been private, but now
      it is gone. Reading the `displayBuffer` property now returns a reference
      to the containing `TextEditor`, which now provides *some* of the API of
      the defunct `DisplayBuffer` class.
    """)
    this
  )

  @deserialize: (state, atomEnvironment) ->
    # TODO: Return null on version mismatch when 1.8.0 has been out for a while
    if state.version isnt @prototype.serializationVersion and state.displayBuffer?
      state.tokenizedBuffer = state.displayBuffer.tokenizedBuffer

    try
      state.tokenizedBuffer = TokenizedBuffer.deserialize(state.tokenizedBuffer, atomEnvironment)
      state.tabLength = state.tokenizedBuffer.getTabLength()
    catch error
      if error.syscall is 'read'
        return # Error reading the file, don't deserialize an editor for it
      else
        throw error

    state.buffer = state.tokenizedBuffer.buffer
    state.assert = atomEnvironment.assert.bind(atomEnvironment)
    editor = new this(state)
    if state.registered
      disposable = atomEnvironment.textEditors.add(editor)
      editor.onDidDestroy -> disposable.dispose()
    editor

  constructor: (params={}) ->
    unless @constructor.clipboard?
      throw new Error("Must call TextEditor.setClipboard at least once before creating TextEditor instances")

    super

    {
      @softTabs, @firstVisibleScreenRow, @firstVisibleScreenColumn, initialLine, initialColumn, tabLength,
      @softWrapped, @decorationManager, @selectionsMarkerLayer, @buffer, suppressCursorCreation,
      @mini, @placeholderText, lineNumberGutterVisible, @largeFileMode,
      @assert, grammar, @showInvisibles, @autoHeight, @autoWidth, @scrollPastEnd, @editorWidthInChars,
      @tokenizedBuffer, @displayLayer, @invisibles, @showIndentGuide,
      @softWrapped, @softWrapAtPreferredLineLength, @preferredLineLength,
      @showCursorOnSelection
    } = params

    @assert ?= (condition) -> condition
    @firstVisibleScreenRow ?= 0
    @firstVisibleScreenColumn ?= 0
    @emitter = new Emitter
    @disposables = new CompositeDisposable
    @cursors = []
    @cursorsByMarkerId = new Map
    @selections = []
    @hasTerminatedPendingState = false

    @mini ?= false
    @scrollPastEnd ?= false
    @showInvisibles ?= true
    @softTabs ?= true
    tabLength ?= 2
    @autoIndent ?= true
    @autoIndentOnPaste ?= true
    @showCursorOnSelection ?= true
    @undoGroupingInterval ?= 300
    @nonWordCharacters ?= "/\\()\"':,.;<>~!@#$%^&*|+=[]{}`?-…"
    @softWrapped ?= false
    @softWrapAtPreferredLineLength ?= false
    @preferredLineLength ?= 80

    @buffer ?= new TextBuffer({shouldDestroyOnFileDelete: ->
      atom.config.get('core.closeDeletedFileTabs')})
    @tokenizedBuffer ?= new TokenizedBuffer({
      grammar, tabLength, @buffer, @largeFileMode, @assert
    })

    unless @displayLayer?
      displayLayerParams = {
        invisibles: @getInvisibles(),
        softWrapColumn: @getSoftWrapColumn(),
        showIndentGuides: @doesShowIndentGuide(),
        atomicSoftTabs: params.atomicSoftTabs ? true,
        tabLength: tabLength,
        ratioForCharacter: @ratioForCharacter.bind(this),
        isWrapBoundary: isWrapBoundary,
        foldCharacter: ZERO_WIDTH_NBSP,
        softWrapHangingIndent: params.softWrapHangingIndentLength ? 0
      }

      if @displayLayer = @buffer.getDisplayLayer(params.displayLayerId)
        @displayLayer.reset(displayLayerParams)
        @selectionsMarkerLayer = @displayLayer.getMarkerLayer(params.selectionsMarkerLayerId)
      else
        @displayLayer = @buffer.addDisplayLayer(displayLayerParams)

    @backgroundWorkHandle = requestIdleCallback(@doBackgroundWork)
    @disposables.add new Disposable =>
      cancelIdleCallback(@backgroundWorkHandle) if @backgroundWorkHandle?

    @displayLayer.setTextDecorationLayer(@tokenizedBuffer)
    @defaultMarkerLayer = @displayLayer.addMarkerLayer()
    @disposables.add(@defaultMarkerLayer.onDidDestroy =>
      @assert(false, "defaultMarkerLayer destroyed at an unexpected time")
    )
    @selectionsMarkerLayer ?= @addMarkerLayer(maintainHistory: true, persistent: true)
    @selectionsMarkerLayer.trackDestructionInOnDidCreateMarkerCallbacks = true

    @decorationManager = new DecorationManager(@displayLayer)
    @decorateMarkerLayer(@selectionsMarkerLayer, type: 'cursor')
    @decorateCursorLine() unless @isMini()

    @decorateMarkerLayer(@displayLayer.foldsMarkerLayer, {type: 'line-number', class: 'folded'})

    for marker in @selectionsMarkerLayer.getMarkers()
      @addSelection(marker)

    @subscribeToBuffer()
    @subscribeToDisplayLayer()

    if @cursors.length is 0 and not suppressCursorCreation
      initialLine = Math.max(parseInt(initialLine) or 0, 0)
      initialColumn = Math.max(parseInt(initialColumn) or 0, 0)
      @addCursorAtBufferPosition([initialLine, initialColumn])

    @languageMode = new LanguageMode(this)

    @gutterContainer = new GutterContainer(this)
    @lineNumberGutter = @gutterContainer.addGutter
      name: 'line-number'
      priority: 0
      visible: lineNumberGutterVisible

  decorateCursorLine: ->
    @cursorLineDecorations = [
      @decorateMarkerLayer(@selectionsMarkerLayer, type: 'line', class: 'cursor-line', onlyEmpty: true),
      @decorateMarkerLayer(@selectionsMarkerLayer, type: 'line-number', class: 'cursor-line'),
      @decorateMarkerLayer(@selectionsMarkerLayer, type: 'line-number', class: 'cursor-line-no-selection', onlyHead: true, onlyEmpty: true)
    ]

  doBackgroundWork: (deadline) =>
    if @displayLayer.doBackgroundWork(deadline)
      @presenter?.updateVerticalDimensions()
      @backgroundWorkHandle = requestIdleCallback(@doBackgroundWork)
    else
      @backgroundWorkHandle = null

  update: (params) ->
    displayLayerParams = {}

    for param in Object.keys(params)
      value = params[param]

      switch param
        when 'autoIndent'
          @autoIndent = value

        when 'autoIndentOnPaste'
          @autoIndentOnPaste = value

        when 'undoGroupingInterval'
          @undoGroupingInterval = value

        when 'nonWordCharacters'
          @nonWordCharacters = value

        when 'scrollSensitivity'
          @scrollSensitivity = value

        when 'encoding'
          @buffer.setEncoding(value)

        when 'softTabs'
          if value isnt @softTabs
            @softTabs = value

        when 'atomicSoftTabs'
          if value isnt @displayLayer.atomicSoftTabs
            displayLayerParams.atomicSoftTabs = value

        when 'tabLength'
          if value? and value isnt @tokenizedBuffer.getTabLength()
            @tokenizedBuffer.setTabLength(value)
            displayLayerParams.tabLength = value

        when 'softWrapped'
          if value isnt @softWrapped
            @softWrapped = value
            displayLayerParams.softWrapColumn = @getSoftWrapColumn()
            @emitter.emit 'did-change-soft-wrapped', @isSoftWrapped()

        when 'softWrapHangingIndentLength'
          if value isnt @displayLayer.softWrapHangingIndent
            displayLayerParams.softWrapHangingIndent = value

        when 'softWrapAtPreferredLineLength'
          if value isnt @softWrapAtPreferredLineLength
            @softWrapAtPreferredLineLength = value
            displayLayerParams.softWrapColumn = @getSoftWrapColumn()

        when 'preferredLineLength'
          if value isnt @preferredLineLength
            @preferredLineLength = value
            displayLayerParams.softWrapColumn = @getSoftWrapColumn()

        when 'mini'
          if value isnt @mini
            @mini = value
            @emitter.emit 'did-change-mini', value
            displayLayerParams.invisibles = @getInvisibles()
            displayLayerParams.softWrapColumn = @getSoftWrapColumn()
            displayLayerParams.showIndentGuides = @doesShowIndentGuide()
            if @mini
              decoration.destroy() for decoration in @cursorLineDecorations
              @cursorLineDecorations = null
            else
              @decorateCursorLine()
            @component?.scheduleUpdate()

        when 'placeholderText'
          if value isnt @placeholderText
            @placeholderText = value
            @emitter.emit 'did-change-placeholder-text', value

        when 'lineNumberGutterVisible'
          if value isnt @lineNumberGutterVisible
            if value
              @lineNumberGutter.show()
            else
              @lineNumberGutter.hide()
            @emitter.emit 'did-change-line-number-gutter-visible', @lineNumberGutter.isVisible()

        when 'showIndentGuide'
          if value isnt @showIndentGuide
            @showIndentGuide = value
            displayLayerParams.showIndentGuides = @doesShowIndentGuide()

        when 'showLineNumbers'
          if value isnt @showLineNumbers
            @showLineNumbers = value
            @presenter?.didChangeShowLineNumbers()

        when 'showInvisibles'
          if value isnt @showInvisibles
            @showInvisibles = value
            displayLayerParams.invisibles = @getInvisibles()

        when 'invisibles'
          if not _.isEqual(value, @invisibles)
            @invisibles = value
            displayLayerParams.invisibles = @getInvisibles()

        when 'editorWidthInChars'
          if value > 0 and value isnt @editorWidthInChars
            @editorWidthInChars = value
            displayLayerParams.softWrapColumn = @getSoftWrapColumn()

        when 'width'
          if value isnt @width
            @width = value
            displayLayerParams.softWrapColumn = @getSoftWrapColumn()

        when 'scrollPastEnd'
          if value isnt @scrollPastEnd
            @scrollPastEnd = value
            @component?.scheduleUpdate()

        when 'autoHeight'
          if value isnt @autoHeight
            @autoHeight = value
            @presenter?.setAutoHeight(@autoHeight)

        when 'autoWidth'
          if value isnt @autoWidth
            @autoWidth = value
            @presenter?.didChangeAutoWidth()

        when 'showCursorOnSelection'
          if value isnt @showCursorOnSelection
            @showCursorOnSelection = value
            @component?.scheduleUpdate()

        else
          if param isnt 'ref' and param isnt 'key'
            throw new TypeError("Invalid TextEditor parameter: '#{param}'")

    @displayLayer.reset(displayLayerParams)

    if @component?
      @component.getNextUpdatePromise()
    else
      Promise.resolve()

  scheduleComponentUpdate: ->
    @component?.scheduleUpdate()

  serialize: ->
    tokenizedBufferState = @tokenizedBuffer.serialize()

    {
      deserializer: 'TextEditor'
      version: @serializationVersion

      # TODO: Remove this forward-compatible fallback once 1.8 reaches stable.
      displayBuffer: {tokenizedBuffer: tokenizedBufferState}

      tokenizedBuffer: tokenizedBufferState
      displayLayerId: @displayLayer.id
      selectionsMarkerLayerId: @selectionsMarkerLayer.id

      firstVisibleScreenRow: @getFirstVisibleScreenRow()
      firstVisibleScreenColumn: @getFirstVisibleScreenColumn()

      atomicSoftTabs: @displayLayer.atomicSoftTabs
      softWrapHangingIndentLength: @displayLayer.softWrapHangingIndent

      @id, @softTabs, @softWrapped, @softWrapAtPreferredLineLength,
      @preferredLineLength, @mini, @editorWidthInChars, @width, @largeFileMode,
      @registered, @invisibles, @showInvisibles, @showIndentGuide, @autoHeight, @autoWidth
    }

  subscribeToBuffer: ->
    @buffer.retain()
    @disposables.add @buffer.onDidChangePath =>
      @emitter.emit 'did-change-title', @getTitle()
      @emitter.emit 'did-change-path', @getPath()
    @disposables.add @buffer.onDidChangeEncoding =>
      @emitter.emit 'did-change-encoding', @getEncoding()
    @disposables.add @buffer.onDidDestroy => @destroy()
    @disposables.add @buffer.onDidChangeModified =>
      @terminatePendingState() if not @hasTerminatedPendingState and @buffer.isModified()

    @preserveCursorPositionOnBufferReload()

  terminatePendingState: ->
    @emitter.emit 'did-terminate-pending-state' if not @hasTerminatedPendingState
    @hasTerminatedPendingState = true

  onDidTerminatePendingState: (callback) ->
    @emitter.on 'did-terminate-pending-state', callback

  subscribeToDisplayLayer: ->
    @disposables.add @selectionsMarkerLayer.onDidCreateMarker @addSelection.bind(this)
    @disposables.add @tokenizedBuffer.onDidChangeGrammar @handleGrammarChange.bind(this)
    @disposables.add @displayLayer.onDidChangeSync (e) =>
      @mergeIntersectingSelections()
      @emitter.emit 'did-change', e
    @disposables.add @displayLayer.onDidReset =>
      @mergeIntersectingSelections()
      @emitter.emit 'did-change', {}

  destroyed: ->
    @disposables.dispose()
    @displayLayer.destroy()
    @tokenizedBuffer.destroy()
    selection.destroy() for selection in @selections.slice()
    @buffer.release()
    @languageMode.destroy()
    @gutterContainer.destroy()
    @emitter.emit 'did-destroy'
    @emitter.clear()
    @editorElement = null
    @presenter = null

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
    @emitter.on 'did-change-soft-wrapped', callback

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

  # Extended: Calls your `callback` after text has been inserted.
  #
  # * `callback` {Function}
  #   * `event` event {Object}
  #     * `text` {String} text to be inserted
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidInsertText: (callback) ->
    @emitter.on 'did-insert-text', callback

  # Essential: Invoke the given callback after the buffer is saved to disk.
  #
  # * `callback` {Function} to be called after the buffer is saved.
  #   * `event` {Object} with the following keys:
  #     * `path` The path to which the buffer was saved.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidSave: (callback) ->
    @getBuffer().onDidSave(callback)

  # Essential: Invoke the given callback when the editor is destroyed.
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
  #   * `cursor` {Cursor} that was added
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
    @decorationManager.observeDecorations(callback)

  # Extended: Calls your `callback` when a {Decoration} is added to the editor.
  #
  # * `callback` {Function}
  #   * `decoration` {Decoration} that was added
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddDecoration: (callback) ->
    @decorationManager.onDidAddDecoration(callback)

  # Extended: Calls your `callback` when a {Decoration} is removed from the editor.
  #
  # * `callback` {Function}
  #   * `decoration` {Decoration} that was removed
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidRemoveDecoration: (callback) ->
    @decorationManager.onDidRemoveDecoration(callback)

  # Extended: Calls your `callback` when the placeholder text is changed.
  #
  # * `callback` {Function}
  #   * `placeholderText` {String} new text
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangePlaceholderText: (callback) ->
    @emitter.on 'did-change-placeholder-text', callback

  onDidChangeFirstVisibleScreenRow: (callback, fromView) ->
    @emitter.on 'did-change-first-visible-screen-row', callback

  onDidChangeScrollTop: (callback) ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::onDidChangeScrollTop instead.")

    @getElement().onDidChangeScrollTop(callback)

  onDidChangeScrollLeft: (callback) ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::onDidChangeScrollLeft instead.")

    @getElement().onDidChangeScrollLeft(callback)

  onDidRequestAutoscroll: (callback) ->
    @emitter.on 'did-request-autoscroll', callback

  # TODO Remove once the tabs package no longer uses .on subscriptions
  onDidChangeIcon: (callback) ->
    @emitter.on 'did-change-icon', callback

  onDidUpdateDecorations: (callback) ->
    @decorationManager.onDidUpdateDecorations(callback)

  # Essential: Retrieves the current {TextBuffer}.
  getBuffer: -> @buffer

  # Retrieves the current buffer's URI.
  getURI: -> @buffer.getUri()

  # Create an {TextEditor} with its initial state based on this object
  copy: ->
    displayLayer = @displayLayer.copy()
    selectionsMarkerLayer = displayLayer.getMarkerLayer(@buffer.getMarkerLayer(@selectionsMarkerLayer.id).copy().id)
    softTabs = @getSoftTabs()
    new TextEditor({
      @buffer, selectionsMarkerLayer, softTabs,
      suppressCursorCreation: true,
      tabLength: @tokenizedBuffer.getTabLength(),
      @firstVisibleScreenRow, @firstVisibleScreenColumn,
      @assert, displayLayer, grammar: @getGrammar(),
      @autoWidth, @autoHeight, @showCursorOnSelection
    })

  # Controls visibility based on the given {Boolean}.
  setVisible: (visible) -> @tokenizedBuffer.setVisible(visible)

  setMini: (mini) ->
    @update({mini})
    @mini

  isMini: -> @mini

  onDidChangeMini: (callback) ->
    @emitter.on 'did-change-mini', callback

  setLineNumberGutterVisible: (lineNumberGutterVisible) -> @update({lineNumberGutterVisible})

  isLineNumberGutterVisible: -> @lineNumberGutter.isVisible()

  onDidChangeLineNumberGutterVisible: (callback) ->
    @emitter.on 'did-change-line-number-gutter-visible', callback

  # Essential: Calls your `callback` when a {Gutter} is added to the editor.
  # Immediately calls your callback for each existing gutter.
  #
  # * `callback` {Function}
  #   * `gutter` {Gutter} that currently exists/was added.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeGutters: (callback) ->
    @gutterContainer.observeGutters callback

  # Essential: Calls your `callback` when a {Gutter} is added to the editor.
  #
  # * `callback` {Function}
  #   * `gutter` {Gutter} that was added.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddGutter: (callback) ->
    @gutterContainer.onDidAddGutter callback

  # Essential: Calls your `callback` when a {Gutter} is removed from the editor.
  #
  # * `callback` {Function}
  #   * `name` The name of the {Gutter} that was removed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidRemoveGutter: (callback) ->
    @gutterContainer.onDidRemoveGutter callback

  # Set the number of characters that can be displayed horizontally in the
  # editor.
  #
  # * `editorWidthInChars` A {Number} representing the width of the
  # {TextEditorElement} in characters.
  setEditorWidthInChars: (editorWidthInChars) -> @update({editorWidthInChars})

  # Returns the editor width in characters.
  getEditorWidthInChars: ->
    if @width? and @defaultCharWidth > 0
      Math.max(0, Math.floor(@width / @defaultCharWidth))
    else
      @editorWidthInChars

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
    @getFileName() ? 'untitled'

  # Essential: Get unique title for display in other parts of the UI, such as
  # the window title.
  #
  # If the editor's buffer is unsaved, its title is "untitled"
  # If the editor's buffer is saved, its unique title is formatted as one
  # of the following,
  # * "<filename>" when it is the only editing buffer with this file name.
  # * "<filename> — <unique-dir-prefix>" when other buffers have this file name.
  #
  # Returns a {String}
  getLongTitle: ->
    if @getPath()
      fileName = @getFileName()

      allPathSegments = []
      for textEditor in atom.workspace.getTextEditors() when textEditor isnt this
        if textEditor.getFileName() is fileName
          directoryPath = fs.tildify(textEditor.getDirectoryPath())
          allPathSegments.push(directoryPath.split(path.sep))

      if allPathSegments.length is 0
        return fileName

      ourPathSegments = fs.tildify(@getDirectoryPath()).split(path.sep)
      allPathSegments.push ourPathSegments

      loop
        firstSegment = ourPathSegments[0]

        commonBase = _.all(allPathSegments, (pathSegments) -> pathSegments.length > 1 and pathSegments[0] is firstSegment)
        if commonBase
          pathSegments.shift() for pathSegments in allPathSegments
        else
          break

      "#{fileName} \u2014 #{path.join(pathSegments...)}"
    else
      'untitled'

  # Essential: Returns the {String} path of this editor's text buffer.
  getPath: -> @buffer.getPath()

  getFileName: ->
    if fullPath = @getPath()
      path.basename(fullPath)
    else
      null

  getDirectoryPath: ->
    if fullPath = @getPath()
      path.dirname(fullPath)
    else
      null

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

  ###
  Section: File Operations
  ###

  # Essential: Saves the editor's text buffer.
  #
  # See {TextBuffer::save} for more details.
  save: -> @buffer.save()

  # Essential: Saves the editor's text buffer as the given path.
  #
  # See {TextBuffer::saveAs} for more details.
  #
  # * `filePath` A {String} path.
  saveAs: (filePath) -> @buffer.saveAs(filePath)

  # Determine whether the user should be prompted to save before closing
  # this editor.
  shouldPromptToSave: ({windowCloseRequested, projectHasPaths}={}) ->
    if windowCloseRequested and projectHasPaths and atom.stateStore.isConnected()
      false
    else
      @isModified() and not @buffer.hasMultipleEditors()

  # Returns an {Object} to configure dialog shown when this editor is saved
  # via {Pane::saveItemAs}.
  getSaveDialogOptions: -> {}

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
  getScreenLineCount: -> @displayLayer.getScreenLineCount()

  getApproximateScreenLineCount: -> @displayLayer.getApproximateScreenLineCount()

  # Essential: Returns a {Number} representing the last zero-indexed buffer row
  # number of the editor.
  getLastBufferRow: -> @buffer.getLastRow()

  # Essential: Returns a {Number} representing the last zero-indexed screen row
  # number of the editor.
  getLastScreenRow: -> @getScreenLineCount() - 1

  # Essential: Returns a {String} representing the contents of the line at the
  # given buffer row.
  #
  # * `bufferRow` A {Number} representing a zero-indexed buffer row.
  lineTextForBufferRow: (bufferRow) -> @buffer.lineForRow(bufferRow)

  # Essential: Returns a {String} representing the contents of the line at the
  # given screen row.
  #
  # * `screenRow` A {Number} representing a zero-indexed screen row.
  lineTextForScreenRow: (screenRow) ->
    @screenLineForScreenRow(screenRow)?.lineText

  logScreenLines: (start=0, end=@getLastScreenRow()) ->
    for row in [start..end]
      line = @lineTextForScreenRow(row)
      console.log row, @bufferRowForScreenRow(row), line, line.length
    return

  tokensForScreenRow: (screenRow) ->
    tokens = []
    lineTextIndex = 0
    currentTokenScopes = []
    {lineText, tagCodes} = @screenLineForScreenRow(screenRow)
    for tagCode in tagCodes
      if @displayLayer.isOpenTagCode(tagCode)
        currentTokenScopes.push(@displayLayer.tagForCode(tagCode))
      else if @displayLayer.isCloseTagCode(tagCode)
        currentTokenScopes.pop()
      else
        tokens.push({
          text: lineText.substr(lineTextIndex, tagCode)
          scopes: currentTokenScopes.slice()
        })
        lineTextIndex += tagCode
    tokens

  screenLineForScreenRow: (screenRow) ->
    @displayLayer.getScreenLine(screenRow)

  bufferRowForScreenRow: (screenRow) ->
    @displayLayer.translateScreenPosition(Point(screenRow, 0)).row

  bufferRowsForScreenRows: (startScreenRow, endScreenRow) ->
    for screenRow in [startScreenRow..endScreenRow]
      @bufferRowForScreenRow(screenRow)

  screenRowForBufferRow: (row) ->
    @displayLayer.translateBufferPosition(Point(row, 0)).row

  getRightmostScreenPosition: -> @displayLayer.getRightmostScreenPosition()

  getApproximateRightmostScreenPosition: -> @displayLayer.getApproximateRightmostScreenPosition()

  getMaxScreenLineLength: -> @getRightmostScreenPosition().column

  getLongestScreenRow: -> @getRightmostScreenPosition().row

  getApproximateLongestScreenRow: -> @getApproximateRightmostScreenPosition().row

  lineLengthForScreenRow: (screenRow) -> @displayLayer.lineLengthForScreenRow(screenRow)

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

  # Essential: Get the {Range} of the paragraph surrounding the most recently added
  # cursor.
  #
  # Returns a {Range}.
  getCurrentParagraphBufferRange: ->
    @getLastCursor().getCurrentParagraphBufferRange()


  ###
  Section: Mutating Text
  ###

  # Essential: Replaces the entire contents of the buffer with the given {String}.
  #
  # * `text` A {String} to replace with
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
  # Returns a {Boolean} false when the text has not been inserted
  insertText: (text, options={}) ->
    return false unless @emitWillInsertTextEvent(text)

    groupingInterval = if options.groupUndo
      @undoGroupingInterval
    else
      0

    options.autoIndentNewline ?= @shouldAutoIndent()
    options.autoDecreaseIndent ?= @shouldAutoIndent()
    @mutateSelectedText(
      (selection) =>
        range = selection.insertText(text, options)
        didInsertEvent = {text, range}
        @emitter.emit 'did-insert-text', didInsertEvent
        range
      , groupingInterval
    )

  # Essential: For each selection, replace the selected text with a newline.
  insertNewline: (options) ->
    @insertText('\n', options)

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
  mutateSelectedText: (fn, groupingInterval=0) ->
    @mergeIntersectingSelections =>
      @transact groupingInterval, =>
        fn(selection, index) for selection, index in @getSelectionsOrderedByBufferPosition()

  # Move lines intersecting the most recent selection or multiple selections
  # up by one row in screen coordinates.
  moveLineUp: ->
    selections = @getSelectedBufferRanges().sort((a, b) -> a.compare(b))

    if selections[0].start.row is 0
      return

    if selections[selections.length - 1].start.row is @getLastBufferRow() and @buffer.getLastLine() is ''
      return

    @transact =>
      newSelectionRanges = []

      while selections.length > 0
        # Find selections spanning a contiguous set of lines
        selection = selections.shift()
        selectionsToMove = [selection]

        while selection.end.row is selections[0]?.start.row
          selectionsToMove.push(selections[0])
          selection.end.row = selections[0].end.row
          selections.shift()

        # Compute the buffer range spanned by all these selections, expanding it
        # so that it includes any folded region that intersects them.
        startRow = selection.start.row
        endRow = selection.end.row
        if selection.end.row > selection.start.row and selection.end.column is 0
          # Don't move the last line of a multi-line selection if the selection ends at column 0
          endRow--

        startRow = @displayLayer.findBoundaryPrecedingBufferRow(startRow)
        endRow = @displayLayer.findBoundaryFollowingBufferRow(endRow + 1)
        linesRange = new Range(Point(startRow, 0), Point(endRow, 0))

        # If selected line range is preceded by a fold, one line above on screen
        # could be multiple lines in the buffer.
        precedingRow = @displayLayer.findBoundaryPrecedingBufferRow(startRow - 1)
        insertDelta = linesRange.start.row - precedingRow

        # Any folds in the text that is moved will need to be re-created.
        # It includes the folds that were intersecting with the selection.
        rangesToRefold = @displayLayer
          .destroyFoldsIntersectingBufferRange(linesRange)
          .map((range) -> range.translate([-insertDelta, 0]))

        # Delete lines spanned by selection and insert them on the preceding buffer row
        lines = @buffer.getTextInRange(linesRange)
        lines += @buffer.lineEndingForRow(linesRange.end.row - 1) unless lines[lines.length - 1] is '\n'
        @buffer.delete(linesRange)
        @buffer.insert([precedingRow, 0], lines)

        # Restore folds that existed before the lines were moved
        for rangeToRefold in rangesToRefold
          @displayLayer.foldBufferRange(rangeToRefold)

        for selection in selectionsToMove
          newSelectionRanges.push(selection.translate([-insertDelta, 0]))

      @setSelectedBufferRanges(newSelectionRanges, {autoscroll: false, preserveFolds: true})
      @autoIndentSelectedRows() if @shouldAutoIndent()
      @scrollToBufferPosition([newSelectionRanges[0].start.row, 0])

  # Move lines intersecting the most recent selection or muiltiple selections
  # down by one row in screen coordinates.
  moveLineDown: ->
    selections = @getSelectedBufferRanges()
    selections.sort (a, b) -> a.compare(b)
    selections = selections.reverse()

    @transact =>
      @consolidateSelections()
      newSelectionRanges = []

      while selections.length > 0
        # Find selections spanning a contiguous set of lines
        selection = selections.shift()
        selectionsToMove = [selection]

        # if the current selection start row matches the next selections' end row - make them one selection
        while selection.start.row is selections[0]?.end.row
          selectionsToMove.push(selections[0])
          selection.start.row = selections[0].start.row
          selections.shift()

        # Compute the buffer range spanned by all these selections, expanding it
        # so that it includes any folded region that intersects them.
        startRow = selection.start.row
        endRow = selection.end.row
        if selection.end.row > selection.start.row and selection.end.column is 0
          # Don't move the last line of a multi-line selection if the selection ends at column 0
          endRow--

        startRow = @displayLayer.findBoundaryPrecedingBufferRow(startRow)
        endRow = @displayLayer.findBoundaryFollowingBufferRow(endRow + 1)
        linesRange = new Range(Point(startRow, 0), Point(endRow, 0))

        # If selected line range is followed by a fold, one line below on screen
        # could be multiple lines in the buffer. But at the same time, if the
        # next buffer row is wrapped, one line in the buffer can represent many
        # screen rows.
        followingRow = Math.min(@buffer.getLineCount(), @displayLayer.findBoundaryFollowingBufferRow(endRow + 1))
        insertDelta = followingRow - linesRange.end.row

        # Any folds in the text that is moved will need to be re-created.
        # It includes the folds that were intersecting with the selection.
        rangesToRefold = @displayLayer
          .destroyFoldsIntersectingBufferRange(linesRange)
          .map((range) -> range.translate([insertDelta, 0]))

        # Delete lines spanned by selection and insert them on the following correct buffer row
        lines = @buffer.getTextInRange(linesRange)
        if followingRow - 1 is @buffer.getLastRow()
          lines = "\n#{lines}"

        @buffer.insert([followingRow, 0], lines)
        @buffer.delete(linesRange)

        # Restore folds that existed before the lines were moved
        for rangeToRefold in rangesToRefold
          @displayLayer.foldBufferRange(rangeToRefold)

        for selection in selectionsToMove
          newSelectionRanges.push(selection.translate([insertDelta, 0]))

      @setSelectedBufferRanges(newSelectionRanges, {autoscroll: false, preserveFolds: true})
      @autoIndentSelectedRows() if @shouldAutoIndent()
      @scrollToBufferPosition([newSelectionRanges[0].start.row - 1, 0])

  # Move any active selections one column to the left.
  moveSelectionLeft: ->
    selections = @getSelectedBufferRanges()
    noSelectionAtStartOfLine = selections.every((selection) ->
      selection.start.column isnt 0
    )

    translationDelta = [0, -1]
    translatedRanges = []

    if noSelectionAtStartOfLine
      @transact =>
        for selection in selections
          charToLeftOfSelection = new Range(selection.start.translate(translationDelta), selection.start)
          charTextToLeftOfSelection = @buffer.getTextInRange(charToLeftOfSelection)

          @buffer.insert(selection.end, charTextToLeftOfSelection)
          @buffer.delete(charToLeftOfSelection)
          translatedRanges.push(selection.translate(translationDelta))

        @setSelectedBufferRanges(translatedRanges)

  # Move any active selections one column to the right.
  moveSelectionRight: ->
    selections = @getSelectedBufferRanges()
    noSelectionAtEndOfLine = selections.every((selection) =>
      selection.end.column isnt @buffer.lineLengthForRow(selection.end.row)
    )

    translationDelta = [0, 1]
    translatedRanges = []

    if noSelectionAtEndOfLine
      @transact =>
        for selection in selections
          charToRightOfSelection = new Range(selection.end, selection.end.translate(translationDelta))
          charTextToRightOfSelection = @buffer.getTextInRange(charToRightOfSelection)

          @buffer.delete(charToRightOfSelection)
          @buffer.insert(selection.start, charTextToRightOfSelection)
          translatedRanges.push(selection.translate(translationDelta))

        @setSelectedBufferRanges(translatedRanges)

  duplicateLines: ->
    @transact =>
      selections = @getSelectionsOrderedByBufferPosition()
      previousSelectionRanges = []

      i = selections.length - 1
      while i >= 0
        j = i
        previousSelectionRanges[i] = selections[i].getBufferRange()
        if selections[i].isEmpty()
          {start} = selections[i].getScreenRange()
          selections[i].setScreenRange([[start.row, 0], [start.row + 1, 0]], preserveFolds: true)
        [startRow, endRow] = selections[i].getBufferRowRange()
        endRow++
        while i > 0
          [previousSelectionStartRow, previousSelectionEndRow] = selections[i - 1].getBufferRowRange()
          if previousSelectionEndRow is startRow
            startRow = previousSelectionStartRow
            previousSelectionRanges[i - 1] = selections[i - 1].getBufferRange()
            i--
          else
            break

        intersectingFolds = @displayLayer.foldsIntersectingBufferRange([[startRow, 0], [endRow, 0]])
        textToDuplicate = @getTextInBufferRange([[startRow, 0], [endRow, 0]])
        textToDuplicate = '\n' + textToDuplicate if endRow > @getLastBufferRow()
        @buffer.insert([endRow, 0], textToDuplicate)

        insertedRowCount = endRow - startRow

        for k in [i..j] by 1
          selections[k].setBufferRange(previousSelectionRanges[k].translate([insertedRowCount, 0]))

        for fold in intersectingFolds
          foldRange = @displayLayer.bufferRangeForFold(fold)
          @displayLayer.foldBufferRange(foldRange.translate([insertedRowCount, 0]))

        i--

  replaceSelectedText: (options={}, fn) ->
    {selectWordIfEmpty} = options
    @mutateSelectedText (selection) ->
      selection.getBufferRange()
      if selectWordIfEmpty and selection.isEmpty()
        selection.selectWord()
      text = selection.getText()
      selection.deleteSelectedText()
      range = selection.insertText(fn(text))
      selection.setBufferRange(range)

  # Split multi-line selections into one selection per line.
  #
  # Operates on all selections. This method breaks apart all multi-line
  # selections to create multiple single-line selections that cumulatively cover
  # the same original area.
  splitSelectionsIntoLines: ->
    @mergeIntersectingSelections =>
      for selection in @getSelections()
        range = selection.getBufferRange()
        continue if range.isSingleLine()

        {start, end} = range
        @addSelectionForBufferRange([start, [start.row, Infinity]])
        {row} = start
        while ++row < end.row
          @addSelectionForBufferRange([[row, 0], [row, Infinity]])
        @addSelectionForBufferRange([[end.row, 0], [end.row, end.column]]) unless end.column is 0
        selection.destroy()
      return

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
    @replaceSelectedText selectWordIfEmpty: true, (text) -> text.toUpperCase()

  # Extended: Convert the selected text to lower case.
  #
  # For each selection, if the selection is empty, converts the containing word
  # to upper case. Otherwise convert the selected text to upper case.
  lowerCase: ->
    @replaceSelectedText selectWordIfEmpty: true, (text) -> text.toLowerCase()

  # Extended: Toggle line comments for rows intersecting selections.
  #
  # If the current grammar doesn't support comments, does nothing.
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

  # Extended: Similar to {::deleteToBeginningOfWord}, but deletes only back to the
  # previous word boundary.
  deleteToPreviousWordBoundary: ->
    @mutateSelectedText (selection) -> selection.deleteToPreviousWordBoundary()

  # Extended: Similar to {::deleteToEndOfWord}, but deletes only up to the
  # next word boundary.
  deleteToNextWordBoundary: ->
    @mutateSelectedText (selection) -> selection.deleteToNextWordBoundary()

  # Extended: For each selection, if the selection is empty, delete all characters
  # of the containing subword following the cursor. Otherwise delete the selected
  # text.
  deleteToBeginningOfSubword: ->
    @mutateSelectedText (selection) -> selection.deleteToBeginningOfSubword()

  # Extended: For each selection, if the selection is empty, delete all characters
  # of the containing subword following the cursor. Otherwise delete the selected
  # text.
  deleteToEndOfSubword: ->
    @mutateSelectedText (selection) -> selection.deleteToEndOfSubword()

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
    @mergeSelectionsOnSameRows()
    @mutateSelectedText (selection) -> selection.deleteLine()

  ###
  Section: History
  ###

  # Essential: Undo the last change.
  undo: ->
    @avoidMergingSelections => @buffer.undo()
    @getLastSelection().autoscroll()

  # Essential: Redo the last change.
  redo: ->
    @avoidMergingSelections => @buffer.redo()
    @getLastSelection().autoscroll()

  # Extended: Batch multiple operations as a single undo/redo step.
  #
  # Any group of operations that are logically grouped from the perspective of
  # undoing and redoing should be performed in a transaction. If you want to
  # abort the transaction, call {::abortTransaction} to terminate the function's
  # execution and revert any changes performed up to the abortion.
  #
  # * `groupingInterval` (optional) The {Number} of milliseconds for which this
  #   transaction should be considered 'groupable' after it begins. If a transaction
  #   with a positive `groupingInterval` is committed while the previous transaction is
  #   still 'groupable', the two transactions are merged with respect to undo and redo.
  # * `fn` A {Function} to call inside the transaction.
  transact: (groupingInterval, fn) ->
    @buffer.transact(groupingInterval, fn)

  # Deprecated: Start an open-ended transaction.
  beginTransaction: (groupingInterval) ->
    Grim.deprecate('Transactions should be performed via TextEditor::transact only')
    @buffer.beginTransaction(groupingInterval)

  # Deprecated: Commit an open-ended transaction started with {::beginTransaction}.
  commitTransaction: ->
    Grim.deprecate('Transactions should be performed via TextEditor::transact only')
    @buffer.commitTransaction()

  # Extended: Abort an open transaction, undoing any operations performed so far
  # within the transaction.
  abortTransaction: -> @buffer.abortTransaction()

  # Extended: Create a pointer to the current state of the buffer for use
  # with {::revertToCheckpoint} and {::groupChangesSinceCheckpoint}.
  #
  # Returns a checkpoint value.
  createCheckpoint: -> @buffer.createCheckpoint()

  # Extended: Revert the buffer to the state it was in when the given
  # checkpoint was created.
  #
  # The redo stack will be empty following this operation, so changes since the
  # checkpoint will be lost. If the given checkpoint is no longer present in the
  # undo history, no changes will be made to the buffer and this method will
  # return `false`.
  #
  # Returns a {Boolean} indicating whether the operation succeeded.
  revertToCheckpoint: (checkpoint) -> @buffer.revertToCheckpoint(checkpoint)

  # Extended: Group all changes since the given checkpoint into a single
  # transaction for purposes of undo/redo.
  #
  # If the given checkpoint is no longer present in the undo history, no
  # grouping will be performed and this method will return `false`.
  #
  # Returns a {Boolean} indicating whether the operation succeeded.
  groupChangesSinceCheckpoint: (checkpoint) -> @buffer.groupChangesSinceCheckpoint(checkpoint)

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
  screenPositionForBufferPosition: (bufferPosition, options) ->
    if options?.clip?
      Grim.deprecate("The `clip` parameter has been deprecated and will be removed soon. Please, use `clipDirection` instead.")
      options.clipDirection ?= options.clip
    if options?.wrapAtSoftNewlines?
      Grim.deprecate("The `wrapAtSoftNewlines` parameter has been deprecated and will be removed soon. Please, use `clipDirection: 'forward'` instead.")
      options.clipDirection ?= if options.wrapAtSoftNewlines then 'forward' else 'backward'
    if options?.wrapBeyondNewlines?
      Grim.deprecate("The `wrapBeyondNewlines` parameter has been deprecated and will be removed soon. Please, use `clipDirection: 'forward'` instead.")
      options.clipDirection ?= if options.wrapBeyondNewlines then 'forward' else 'backward'

    @displayLayer.translateBufferPosition(bufferPosition, options)

  # Essential: Convert a position in screen-coordinates to buffer-coordinates.
  #
  # The position is clipped via {::clipScreenPosition} prior to the conversion.
  #
  # * `bufferPosition` A {Point} or {Array} of [row, column].
  # * `options` (optional) An options hash for {::clipScreenPosition}.
  #
  # Returns a {Point}.
  bufferPositionForScreenPosition: (screenPosition, options) ->
    if options?.clip?
      Grim.deprecate("The `clip` parameter has been deprecated and will be removed soon. Please, use `clipDirection` instead.")
      options.clipDirection ?= options.clip
    if options?.wrapAtSoftNewlines?
      Grim.deprecate("The `wrapAtSoftNewlines` parameter has been deprecated and will be removed soon. Please, use `clipDirection: 'forward'` instead.")
      options.clipDirection ?= if options.wrapAtSoftNewlines then 'forward' else 'backward'
    if options?.wrapBeyondNewlines?
      Grim.deprecate("The `wrapBeyondNewlines` parameter has been deprecated and will be removed soon. Please, use `clipDirection: 'forward'` instead.")
      options.clipDirection ?= if options.wrapBeyondNewlines then 'forward' else 'backward'

    @displayLayer.translateScreenPosition(screenPosition, options)

  # Essential: Convert a range in buffer-coordinates to screen-coordinates.
  #
  # * `bufferRange` {Range} in buffer coordinates to translate into screen coordinates.
  #
  # Returns a {Range}.
  screenRangeForBufferRange: (bufferRange, options) ->
    bufferRange = Range.fromObject(bufferRange)
    start = @screenPositionForBufferPosition(bufferRange.start, options)
    end = @screenPositionForBufferPosition(bufferRange.end, options)
    new Range(start, end)

  # Essential: Convert a range in screen-coordinates to buffer-coordinates.
  #
  # * `screenRange` {Range} in screen coordinates to translate into buffer coordinates.
  #
  # Returns a {Range}.
  bufferRangeForScreenRange: (screenRange) ->
    screenRange = Range.fromObject(screenRange)
    start = @bufferPositionForScreenPosition(screenRange.start)
    end = @bufferPositionForScreenPosition(screenRange.end)
    new Range(start, end)

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
  #   * `clipDirection` {String} If `'backward'`, returns the first valid
  #     position preceding an invalid position. If `'forward'`, returns the
  #     first valid position following an invalid position. If `'closest'`,
  #     returns the first valid position closest to an invalid position.
  #     Defaults to `'closest'`.
  #
  # Returns a {Point}.
  clipScreenPosition: (screenPosition, options) ->
    if options?.clip?
      Grim.deprecate("The `clip` parameter has been deprecated and will be removed soon. Please, use `clipDirection` instead.")
      options.clipDirection ?= options.clip
    if options?.wrapAtSoftNewlines?
      Grim.deprecate("The `wrapAtSoftNewlines` parameter has been deprecated and will be removed soon. Please, use `clipDirection: 'forward'` instead.")
      options.clipDirection ?= if options.wrapAtSoftNewlines then 'forward' else 'backward'
    if options?.wrapBeyondNewlines?
      Grim.deprecate("The `wrapBeyondNewlines` parameter has been deprecated and will be removed soon. Please, use `clipDirection: 'forward'` instead.")
      options.clipDirection ?= if options.wrapBeyondNewlines then 'forward' else 'backward'

    @displayLayer.clipScreenPosition(screenPosition, options)

  # Extended: Clip the start and end of the given range to valid positions on screen.
  # See {::clipScreenPosition} for more information.
  #
  # * `range` The {Range} to clip.
  # * `options` (optional) See {::clipScreenPosition} `options`.
  #
  # Returns a {Range}.
  clipScreenRange: (screenRange, options) ->
    screenRange = Range.fromObject(screenRange)
    start = @displayLayer.clipScreenPosition(screenRange.start, options)
    end = @displayLayer.clipScreenPosition(screenRange.end, options)
    Range(start, end)

  ###
  Section: Decorations
  ###

  # Essential: Add a decoration that tracks a {DisplayMarker}. When the
  # marker moves, is invalidated, or is destroyed, the decoration will be
  # updated to reflect the marker's state.
  #
  # The following are the supported decorations types:
  #
  # * __line__: Adds your CSS `class` to the line nodes within the range
  #     marked by the marker
  # * __line-number__: Adds your CSS `class` to the line number nodes within the
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
  # * __overlay__: Positions the view associated with the given item at the head
  #     or tail of the given `DisplayMarker`.
  # * __gutter__: A decoration that tracks a {DisplayMarker} in a {Gutter}. Gutter
  #     decorations are created by calling {Gutter::decorateMarker} on the
  #     desired `Gutter` instance.
  # * __block__: Positions the view associated with the given item before or
  #     after the row of the given `TextEditorMarker`.
  #
  # ## Arguments
  #
  # * `marker` A {DisplayMarker} you want this decoration to follow.
  # * `decorationParams` An {Object} representing the decoration e.g.
  #   `{type: 'line-number', class: 'linter-error'}`
  #   * `type` There are several supported decoration types. The behavior of the
  #     types are as follows:
  #     * `line` Adds the given `class` to the lines overlapping the rows
  #        spanned by the `DisplayMarker`.
  #     * `line-number` Adds the given `class` to the line numbers overlapping
  #       the rows spanned by the `DisplayMarker`.
  #     * `highlight` Creates a `.highlight` div with the nested class with up
  #       to 3 nested regions that fill the area spanned by the `DisplayMarker`.
  #     * `overlay` Positions the view associated with the given item at the
  #       head or tail of the given `DisplayMarker`, depending on the `position`
  #       property.
  #     * `gutter` Tracks a {DisplayMarker} in a {Gutter}. Created by calling
  #       {Gutter::decorateMarker} on the desired `Gutter` instance.
  #     * `block` Positions the view associated with the given item before or
  #       after the row of the given `TextEditorMarker`, depending on the `position`
  #       property.
  #   * `class` This CSS class will be applied to the decorated line number,
  #     line, highlight, or overlay.
  #   * `item` (optional) An {HTMLElement} or a model {Object} with a
  #     corresponding view registered. Only applicable to the `gutter`,
  #     `overlay` and `block` decoration types.
  #   * `onlyHead` (optional) If `true`, the decoration will only be applied to
  #     the head of the `DisplayMarker`. Only applicable to the `line` and
  #     `line-number` decoration types.
  #   * `onlyEmpty` (optional) If `true`, the decoration will only be applied if
  #     the associated `DisplayMarker` is empty. Only applicable to the `gutter`,
  #     `line`, and `line-number` decoration types.
  #   * `onlyNonEmpty` (optional) If `true`, the decoration will only be applied
  #     if the associated `DisplayMarker` is non-empty. Only applicable to the
  #     `gutter`, `line`, and `line-number` decoration types.
  #   * `omitEmptyLastRow` (optional) If `false`, the decoration will be applied
  #     to the last row of a non-empty range, even if it ends at column 0.
  #     Defaults to `true`. Only applicable to the `gutter`, `line`, and
  #     `line-number` decoration types.
  #   * `position` (optional) Only applicable to decorations of type `overlay` and `block`.
  #     Controls where the view is positioned relative to the `TextEditorMarker`.
  #     Values can be `'head'` (the default) or `'tail'` for overlay decorations, and
  #     `'before'` (the default) or `'after'` for block decorations.
  #   * `avoidOverflow` (optional) Only applicable to decorations of type
  #      `overlay`. Determines whether the decoration adjusts its horizontal or
  #      vertical position to remain fully visible when it would otherwise
  #      overflow the editor. Defaults to `true`.
  #
  # Returns a {Decoration} object
  decorateMarker: (marker, decorationParams) ->
    @decorationManager.decorateMarker(marker, decorationParams)

  # Essential: Add a decoration to every marker in the given marker layer. Can
  # be used to decorate a large number of markers without having to create and
  # manage many individual decorations.
  #
  # * `markerLayer` A {DisplayMarkerLayer} or {MarkerLayer} to decorate.
  # * `decorationParams` The same parameters that are passed to
  #   {TextEditor::decorateMarker}, except the `type` cannot be `overlay` or `gutter`.
  #
  # Returns a {LayerDecoration}.
  decorateMarkerLayer: (markerLayer, decorationParams) ->
    @decorationManager.decorateMarkerLayer(markerLayer, decorationParams)

  # Deprecated: Get all the decorations within a screen row range on the default
  # layer.
  #
  # * `startScreenRow` the {Number} beginning screen row
  # * `endScreenRow` the {Number} end screen row (inclusive)
  #
  # Returns an {Object} of decorations in the form
  #  `{1: [{id: 10, type: 'line-number', class: 'someclass'}], 2: ...}`
  #   where the keys are {DisplayMarker} IDs, and the values are an array of decoration
  #   params objects attached to the marker.
  # Returns an empty object when no decorations are found
  decorationsForScreenRowRange: (startScreenRow, endScreenRow) ->
    @decorationManager.decorationsForScreenRowRange(startScreenRow, endScreenRow)

  decorationsStateForScreenRowRange: (startScreenRow, endScreenRow) ->
    @decorationManager.decorationsStateForScreenRowRange(startScreenRow, endScreenRow)

  # Extended: Get all decorations.
  #
  # * `propertyFilter` (optional) An {Object} containing key value pairs that
  #   the returned decorations' properties must match.
  #
  # Returns an {Array} of {Decoration}s.
  getDecorations: (propertyFilter) ->
    @decorationManager.getDecorations(propertyFilter)

  # Extended: Get all decorations of type 'line'.
  #
  # * `propertyFilter` (optional) An {Object} containing key value pairs that
  #   the returned decorations' properties must match.
  #
  # Returns an {Array} of {Decoration}s.
  getLineDecorations: (propertyFilter) ->
    @decorationManager.getLineDecorations(propertyFilter)

  # Extended: Get all decorations of type 'line-number'.
  #
  # * `propertyFilter` (optional) An {Object} containing key value pairs that
  #   the returned decorations' properties must match.
  #
  # Returns an {Array} of {Decoration}s.
  getLineNumberDecorations: (propertyFilter) ->
    @decorationManager.getLineNumberDecorations(propertyFilter)

  # Extended: Get all decorations of type 'highlight'.
  #
  # * `propertyFilter` (optional) An {Object} containing key value pairs that
  #   the returned decorations' properties must match.
  #
  # Returns an {Array} of {Decoration}s.
  getHighlightDecorations: (propertyFilter) ->
    @decorationManager.getHighlightDecorations(propertyFilter)

  # Extended: Get all decorations of type 'overlay'.
  #
  # * `propertyFilter` (optional) An {Object} containing key value pairs that
  #   the returned decorations' properties must match.
  #
  # Returns an {Array} of {Decoration}s.
  getOverlayDecorations: (propertyFilter) ->
    @decorationManager.getOverlayDecorations(propertyFilter)

  ###
  Section: Markers
  ###

  # Essential: Create a marker on the default marker layer with the given range
  # in buffer coordinates. This marker will maintain its logical location as the
  # buffer is changed, so if you mark a particular word, the marker will remain
  # over that word even if the word's location in the buffer changes.
  #
  # * `range` A {Range} or range-compatible {Array}
  # * `properties` A hash of key-value pairs to associate with the marker. There
  #   are also reserved property names that have marker-specific meaning.
  #   * `maintainHistory` (optional) {Boolean} Whether to store this marker's
  #     range before and after each change in the undo history. This allows the
  #     marker's position to be restored more accurately for certain undo/redo
  #     operations, but uses more time and memory. (default: false)
  #   * `reversed` (optional) {Boolean} Creates the marker in a reversed
  #     orientation. (default: false)
  #   * `invalidate` (optional) {String} Determines the rules by which changes
  #     to the buffer *invalidate* the marker. (default: 'overlap') It can be
  #     any of the following strategies, in order of fragility:
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
  # Returns a {DisplayMarker}.
  markBufferRange: (bufferRange, options) ->
    @defaultMarkerLayer.markBufferRange(bufferRange, options)

  # Essential: Create a marker on the default marker layer with the given range
  # in screen coordinates. This marker will maintain its logical location as the
  # buffer is changed, so if you mark a particular word, the marker will remain
  # over that word even if the word's location in the buffer changes.
  #
  # * `range` A {Range} or range-compatible {Array}
  # * `properties` A hash of key-value pairs to associate with the marker. There
  #   are also reserved property names that have marker-specific meaning.
  #   * `maintainHistory` (optional) {Boolean} Whether to store this marker's
  #     range before and after each change in the undo history. This allows the
  #     marker's position to be restored more accurately for certain undo/redo
  #     operations, but uses more time and memory. (default: false)
  #   * `reversed` (optional) {Boolean} Creates the marker in a reversed
  #     orientation. (default: false)
  #   * `invalidate` (optional) {String} Determines the rules by which changes
  #     to the buffer *invalidate* the marker. (default: 'overlap') It can be
  #     any of the following strategies, in order of fragility:
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
  # Returns a {DisplayMarker}.
  markScreenRange: (screenRange, options) ->
    @defaultMarkerLayer.markScreenRange(screenRange, options)

  # Essential: Create a marker on the default marker layer with the given buffer
  # position and no tail. To group multiple markers together in their own
  # private layer, see {::addMarkerLayer}.
  #
  # * `bufferPosition` A {Point} or point-compatible {Array}
  # * `options` (optional) An {Object} with the following keys:
  #   * `invalidate` (optional) {String} Determines the rules by which changes
  #     to the buffer *invalidate* the marker. (default: 'overlap') It can be
  #     any of the following strategies, in order of fragility:
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
  # Returns a {DisplayMarker}.
  markBufferPosition: (bufferPosition, options) ->
    @defaultMarkerLayer.markBufferPosition(bufferPosition, options)

  # Essential: Create a marker on the default marker layer with the given screen
  # position and no tail. To group multiple markers together in their own
  # private layer, see {::addMarkerLayer}.
  #
  # * `screenPosition` A {Point} or point-compatible {Array}
  # * `options` (optional) An {Object} with the following keys:
  #   * `invalidate` (optional) {String} Determines the rules by which changes
  #     to the buffer *invalidate* the marker. (default: 'overlap') It can be
  #     any of the following strategies, in order of fragility:
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
  #   * `clipDirection` {String} If `'backward'`, returns the first valid
  #     position preceding an invalid position. If `'forward'`, returns the
  #     first valid position following an invalid position. If `'closest'`,
  #     returns the first valid position closest to an invalid position.
  #     Defaults to `'closest'`.
  #
  # Returns a {DisplayMarker}.
  markScreenPosition: (screenPosition, options) ->
    @defaultMarkerLayer.markScreenPosition(screenPosition, options)

  # Essential: Find all {DisplayMarker}s on the default marker layer that
  # match the given properties.
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
  #
  # Returns an {Array} of {DisplayMarker}s
  findMarkers: (params) ->
    @defaultMarkerLayer.findMarkers(params)

  # Extended: Get the {DisplayMarker} on the default layer for the given
  # marker id.
  #
  # * `id` {Number} id of the marker
  getMarker: (id) ->
    @defaultMarkerLayer.getMarker(id)

  # Extended: Get all {DisplayMarker}s on the default marker layer. Consider
  # using {::findMarkers}
  getMarkers: ->
    @defaultMarkerLayer.getMarkers()

  # Extended: Get the number of markers in the default marker layer.
  #
  # Returns a {Number}.
  getMarkerCount: ->
    @defaultMarkerLayer.getMarkerCount()

  destroyMarker: (id) ->
    @getMarker(id)?.destroy()

  # Essential: Create a marker layer to group related markers.
  #
  # * `options` An {Object} containing the following keys:
  #   * `maintainHistory` A {Boolean} indicating whether marker state should be
  #     restored on undo/redo. Defaults to `false`.
  #   * `persistent` A {Boolean} indicating whether or not this marker layer
  #     should be serialized and deserialized along with the rest of the
  #     buffer. Defaults to `false`. If `true`, the marker layer's id will be
  #     maintained across the serialization boundary, allowing you to retrieve
  #     it via {::getMarkerLayer}.
  #
  # Returns a {DisplayMarkerLayer}.
  addMarkerLayer: (options) ->
    @displayLayer.addMarkerLayer(options)

  # Essential: Get a {DisplayMarkerLayer} by id.
  #
  # * `id` The id of the marker layer to retrieve.
  #
  # Returns a {DisplayMarkerLayer} or `undefined` if no layer exists with the
  # given id.
  getMarkerLayer: (id) ->
    @displayLayer.getMarkerLayer(id)

  # Essential: Get the default {DisplayMarkerLayer}.
  #
  # All marker APIs not tied to an explicit layer interact with this default
  # layer.
  #
  # Returns a {DisplayMarkerLayer}.
  getDefaultMarkerLayer: ->
    @defaultMarkerLayer

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
  # * `options` (optional) An {Object} containing the following keys:
  #   * `autoscroll` Determines whether the editor scrolls to the new cursor's
  #     position. Defaults to true.
  setCursorBufferPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setBufferPosition(position, options)

  # Essential: Get a {Cursor} at given screen coordinates {Point}
  #
  # * `position` A {Point} or {Array} of `[row, column]`
  #
  # Returns the first matched {Cursor} or undefined
  getCursorAtScreenPosition: (position) ->
    if selection = @getSelectionAtScreenPosition(position)
      if selection.getHeadScreenPosition().isEqual(position)
        selection.cursor

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

  # Essential: Move the cursor to the given position in screen coordinates.
  #
  # If there are multiple cursors, they will be consolidated to a single cursor.
  #
  # * `position` A {Point} or {Array} of `[row, column]`
  # * `options` (optional) An {Object} combining options for {::clipScreenPosition} with:
  #   * `autoscroll` Determines whether the editor scrolls to the new cursor's
  #     position. Defaults to true.
  setCursorScreenPosition: (position, options) ->
    if options?.clip?
      Grim.deprecate("The `clip` parameter has been deprecated and will be removed soon. Please, use `clipDirection` instead.")
      options.clipDirection ?= options.clip
    if options?.wrapAtSoftNewlines?
      Grim.deprecate("The `wrapAtSoftNewlines` parameter has been deprecated and will be removed soon. Please, use `clipDirection: 'forward'` instead.")
      options.clipDirection ?= if options.wrapAtSoftNewlines then 'forward' else 'backward'
    if options?.wrapBeyondNewlines?
      Grim.deprecate("The `wrapBeyondNewlines` parameter has been deprecated and will be removed soon. Please, use `clipDirection: 'forward'` instead.")
      options.clipDirection ?= if options.wrapBeyondNewlines then 'forward' else 'backward'

    @moveCursors (cursor) -> cursor.setScreenPosition(position, options)

  # Essential: Add a cursor at the given position in buffer coordinates.
  #
  # * `bufferPosition` A {Point} or {Array} of `[row, column]`
  #
  # Returns a {Cursor}.
  addCursorAtBufferPosition: (bufferPosition, options) ->
    @selectionsMarkerLayer.markBufferPosition(bufferPosition, Object.assign({invalidate: 'never'}, options))
    @getLastSelection().cursor.autoscroll() unless options?.autoscroll is false
    @getLastSelection().cursor

  # Essential: Add a cursor at the position in screen coordinates.
  #
  # * `screenPosition` A {Point} or {Array} of `[row, column]`
  #
  # Returns a {Cursor}.
  addCursorAtScreenPosition: (screenPosition, options) ->
    @selectionsMarkerLayer.markScreenPosition(screenPosition, {invalidate: 'never'})
    @getLastSelection().cursor.autoscroll() unless options?.autoscroll is false
    @getLastSelection().cursor

  # Essential: Returns {Boolean} indicating whether or not there are multiple cursors.
  hasMultipleCursors: ->
    @getCursors().length > 1

  # Essential: Move every cursor up one row in screen coordinates.
  #
  # * `lineCount` (optional) {Number} number of lines to move
  moveUp: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveUp(lineCount, moveToEndOfSelection: true)

  # Essential: Move every cursor down one row in screen coordinates.
  #
  # * `lineCount` (optional) {Number} number of lines to move
  moveDown: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveDown(lineCount, moveToEndOfSelection: true)

  # Essential: Move every cursor left one column.
  #
  # * `columnCount` (optional) {Number} number of columns to move (default: 1)
  moveLeft: (columnCount) ->
    @moveCursors (cursor) -> cursor.moveLeft(columnCount, moveToEndOfSelection: true)

  # Essential: Move every cursor right one column.
  #
  # * `columnCount` (optional) {Number} number of columns to move (default: 1)
  moveRight: (columnCount) ->
    @moveCursors (cursor) -> cursor.moveRight(columnCount, moveToEndOfSelection: true)

  # Essential: Move every cursor to the beginning of its line in buffer coordinates.
  moveToBeginningOfLine: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfLine()

  # Essential: Move every cursor to the beginning of its line in screen coordinates.
  moveToBeginningOfScreenLine: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfScreenLine()

  # Essential: Move every cursor to the first non-whitespace character of its line.
  moveToFirstCharacterOfLine: ->
    @moveCursors (cursor) -> cursor.moveToFirstCharacterOfLine()

  # Essential: Move every cursor to the end of its line in buffer coordinates.
  moveToEndOfLine: ->
    @moveCursors (cursor) -> cursor.moveToEndOfLine()

  # Essential: Move every cursor to the end of its line in screen coordinates.
  moveToEndOfScreenLine: ->
    @moveCursors (cursor) -> cursor.moveToEndOfScreenLine()

  # Essential: Move every cursor to the beginning of its surrounding word.
  moveToBeginningOfWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfWord()

  # Essential: Move every cursor to the end of its surrounding word.
  moveToEndOfWord: ->
    @moveCursors (cursor) -> cursor.moveToEndOfWord()

  # Cursor Extended

  # Extended: Move every cursor to the top of the buffer.
  #
  # If there are multiple cursors, they will be merged into a single cursor.
  moveToTop: ->
    @moveCursors (cursor) -> cursor.moveToTop()

  # Extended: Move every cursor to the bottom of the buffer.
  #
  # If there are multiple cursors, they will be merged into a single cursor.
  moveToBottom: ->
    @moveCursors (cursor) -> cursor.moveToBottom()

  # Extended: Move every cursor to the beginning of the next word.
  moveToBeginningOfNextWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfNextWord()

  # Extended: Move every cursor to the previous word boundary.
  moveToPreviousWordBoundary: ->
    @moveCursors (cursor) -> cursor.moveToPreviousWordBoundary()

  # Extended: Move every cursor to the next word boundary.
  moveToNextWordBoundary: ->
    @moveCursors (cursor) -> cursor.moveToNextWordBoundary()

  # Extended: Move every cursor to the previous subword boundary.
  moveToPreviousSubwordBoundary: ->
    @moveCursors (cursor) -> cursor.moveToPreviousSubwordBoundary()

  # Extended: Move every cursor to the next subword boundary.
  moveToNextSubwordBoundary: ->
    @moveCursors (cursor) -> cursor.moveToNextSubwordBoundary()

  # Extended: Move every cursor to the beginning of the next paragraph.
  moveToBeginningOfNextParagraph: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfNextParagraph()

  # Extended: Move every cursor to the beginning of the previous paragraph.
  moveToBeginningOfPreviousParagraph: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfPreviousParagraph()

  # Extended: Returns the most recently added {Cursor}
  getLastCursor: ->
    @createLastSelectionIfNeeded()
    _.last(@cursors)

  # Extended: Returns the word surrounding the most recently added cursor.
  #
  # * `options` (optional) See {Cursor::getBeginningOfCurrentWordBufferPosition}.
  getWordUnderCursor: (options) ->
    @getTextInBufferRange(@getLastCursor().getCurrentWordBufferRange(options))

  # Extended: Get an Array of all {Cursor}s.
  getCursors: ->
    @createLastSelectionIfNeeded()
    @cursors.slice()

  # Extended: Get all {Cursors}s, ordered by their position in the buffer
  # instead of the order in which they were added.
  #
  # Returns an {Array} of {Selection}s.
  getCursorsOrderedByBufferPosition: ->
    @getCursors().sort (a, b) -> a.compare(b)

  cursorsForScreenRowRange: (startScreenRow, endScreenRow) ->
    cursors = []
    for marker in @selectionsMarkerLayer.findMarkers(intersectsScreenRowRange: [startScreenRow, endScreenRow])
      if cursor = @cursorsByMarkerId.get(marker.id)
        cursors.push(cursor)
    cursors

  # Add a cursor based on the given {DisplayMarker}.
  addCursor: (marker) ->
    cursor = new Cursor(editor: this, marker: marker, showCursorOnSelection: @showCursorOnSelection)
    @cursors.push(cursor)
    @cursorsByMarkerId.set(marker.id, cursor)
    cursor

  moveCursors: (fn) ->
    fn(cursor) for cursor in @getCursors()
    @mergeCursors()

  cursorMoved: (event) ->
    @emitter.emit 'did-change-cursor-position', event

  # Merge cursors that have the same screen position
  mergeCursors: ->
    positions = {}
    for cursor in @getCursors()
      position = cursor.getBufferPosition().toString()
      if positions.hasOwnProperty(position)
        cursor.destroy()
      else
        positions[position] = true
    return

  preserveCursorPositionOnBufferReload: ->
    cursorPosition = null
    @disposables.add @buffer.onWillReload =>
      cursorPosition = @getCursorBufferPosition()
    @disposables.add @buffer.onDidReload =>
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
  #   * `preserveFolds` A {Boolean}, which if `true` preserves the fold settings after the
  #     selection is set.
  setSelectedBufferRange: (bufferRange, options) ->
    @setSelectedBufferRanges([bufferRange], options)

  # Essential: Set the selected ranges in buffer coordinates. If there are multiple
  # selections, they are replaced by new selections with the given ranges.
  #
  # * `bufferRanges` An {Array} of {Range}s or range-compatible {Array}s.
  # * `options` (optional) An options {Object}:
  #   * `reversed` A {Boolean} indicating whether to create the selection in a
  #     reversed orientation.
  #   * `preserveFolds` A {Boolean}, which if `true` preserves the fold settings after the
  #     selection is set.
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
      return

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
      return

  # Essential: Add a selection for the given range in buffer coordinates.
  #
  # * `bufferRange` A {Range}
  # * `options` (optional) An options {Object}:
  #   * `reversed` A {Boolean} indicating whether to create the selection in a
  #     reversed orientation.
  #   * `preserveFolds` A {Boolean}, which if `true` preserves the fold settings after the
  #     selection is set.
  #
  # Returns the added {Selection}.
  addSelectionForBufferRange: (bufferRange, options={}) ->
    unless options.preserveFolds
      @destroyFoldsIntersectingBufferRange(bufferRange)
    @selectionsMarkerLayer.markBufferRange(bufferRange, {invalidate: 'never', reversed: options.reversed ? false})
    @getLastSelection().autoscroll() unless options.autoscroll is false
    @getLastSelection()

  # Essential: Add a selection for the given range in screen coordinates.
  #
  # * `screenRange` A {Range}
  # * `options` (optional) An options {Object}:
  #   * `reversed` A {Boolean} indicating whether to create the selection in a
  #     reversed orientation.
  #   * `preserveFolds` A {Boolean}, which if `true` preserves the fold settings after the
  #     selection is set.
  # Returns the added {Selection}.
  addSelectionForScreenRange: (screenRange, options={}) ->
    @addSelectionForBufferRange(@bufferRangeForScreenRange(screenRange), options)

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
  selectToScreenPosition: (position, options) ->
    lastSelection = @getLastSelection()
    lastSelection.selectToScreenPosition(position, options)
    unless options?.suppressSelectionMerge
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

  # Extended: For each selection, move its cursor to the preceding subword
  # boundary while maintaining the selection's tail position.
  #
  # This method may merge selections that end up intersecting.
  selectToPreviousSubwordBoundary: ->
    @expandSelectionsBackward (selection) -> selection.selectToPreviousSubwordBoundary()

  # Extended: For each selection, move its cursor to the next subword boundary
  # while maintaining the selection's tail position.
  #
  # This method may merge selections that end up intersecting.
  selectToNextSubwordBoundary: ->
    @expandSelectionsForward (selection) -> selection.selectToNextSubwordBoundary()

  # Essential: For each cursor, select the containing line.
  #
  # This method merges selections on successive lines.
  selectLinesContainingCursors: ->
    @expandSelectionsForward (selection) -> selection.selectLine()

  # Essential: Select the word surrounding each cursor.
  selectWordsContainingCursors: ->
    @expandSelectionsForward (selection) -> selection.selectWord()

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
  # * `marker` A {DisplayMarker}
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
    @createLastSelectionIfNeeded()
    _.last(@selections)

  getSelectionAtScreenPosition: (position) ->
    markers = @selectionsMarkerLayer.findMarkers(containsScreenPosition: position)
    if markers.length > 0
      @cursorsByMarkerId.get(markers[0].id).selection

  # Extended: Get current {Selection}s.
  #
  # Returns: An {Array} of {Selection}s.
  getSelections: ->
    @createLastSelectionIfNeeded()
    @selections.slice()

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
      return

  # Calls the given function with each selection, then merges selections in the
  # reversed orientation
  expandSelectionsBackward: (fn) ->
    @mergeIntersectingSelections reversed: true, =>
      fn(selection) for selection in @getSelections()
      return

  finalizeSelections: ->
    selection.finalize() for selection in @getSelections()
    return

  selectionsForScreenRows: (startRow, endRow) ->
    @getSelections().filter (selection) -> selection.intersectsScreenRowRange(startRow, endRow)

  # Merges intersecting selections. If passed a function, it executes
  # the function with merging suppressed, then merges intersecting selections
  # afterward.
  mergeIntersectingSelections: (args...) ->
    @mergeSelections args..., (previousSelection, currentSelection) ->
      exclusive = not currentSelection.isEmpty() and not previousSelection.isEmpty()

      previousSelection.intersectsWith(currentSelection, exclusive)

  mergeSelectionsOnSameRows: (args...) ->
    @mergeSelections args..., (previousSelection, currentSelection) ->
      screenRange = currentSelection.getScreenRange()

      previousSelection.intersectsScreenRowRange(screenRange.start.row, screenRange.end.row)

  avoidMergingSelections: (args...) ->
    @mergeSelections args..., -> false

  mergeSelections: (args...) ->
    mergePredicate = args.pop()
    fn = args.pop() if _.isFunction(_.last(args))
    options = args.pop() ? {}

    return fn?() if @suppressSelectionMerging

    if fn?
      @suppressSelectionMerging = true
      result = fn()
      @suppressSelectionMerging = false

    reducer = (disjointSelections, selection) ->
      adjacentSelection = _.last(disjointSelections)
      if mergePredicate(adjacentSelection, selection)
        adjacentSelection.merge(selection, options)
        disjointSelections
      else
        disjointSelections.concat([selection])

    [head, tail...] = @getSelectionsOrderedByBufferPosition()
    _.reduce(tail, reducer, [head])
    return result if fn?

  # Add a {Selection} based on the given {DisplayMarker}.
  #
  # * `marker` The {DisplayMarker} to highlight
  # * `options` (optional) An {Object} that pertains to the {Selection} constructor.
  #
  # Returns the new {Selection}.
  addSelection: (marker, options={}) ->
    cursor = @addCursor(marker)
    selection = new Selection(Object.assign({editor: this, marker, cursor}, options))
    @selections.push(selection)
    selectionBufferRange = selection.getBufferRange()
    @mergeIntersectingSelections(preserveFolds: options.preserveFolds)

    if selection.destroyed
      for selection in @getSelections()
        if selection.intersectsBufferRange(selectionBufferRange)
          return selection
    else
      @emitter.emit 'did-add-cursor', cursor
      @emitter.emit 'did-add-selection', selection
      selection

  # Remove the given selection.
  removeSelection: (selection) ->
    _.remove(@cursors, selection.cursor)
    _.remove(@selections, selection)
    @cursorsByMarkerId.delete(selection.cursor.marker.id)
    @emitter.emit 'did-remove-cursor', selection.cursor
    @emitter.emit 'did-remove-selection', selection

  # Reduce one or more selections to a single empty selection based on the most
  # recently added cursor.
  clearSelections: (options) ->
    @consolidateSelections()
    @getLastSelection().clear(options)

  # Reduce multiple selections to the least recently added selection.
  consolidateSelections: ->
    selections = @getSelections()
    if selections.length > 1
      selection.destroy() for selection in selections[1...(selections.length)]
      selections[0].autoscroll(center: true)
      true
    else
      false

  # Called by the selection
  selectionRangeChanged: (event) ->
    @emitter.emit 'did-change-selection-range', event

  createLastSelectionIfNeeded: ->
    if @selections.length is 0
      @addSelectionForBufferRange([[0, 0], [0, 0]], autoscroll: false, preserveFolds: true)

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
  # * `options` (optional) {Object}
  #   * `leadingContextLineCount` {Number} default `0`; The number of lines
  #      before the matched line to include in the results object.
  #   * `trailingContextLineCount` {Number} default `0`; The number of lines
  #      after the matched line to include in the results object.
  # * `iterator` A {Function} that's called on each match
  #   * `object` {Object}
  #     * `match` The current regular expression match.
  #     * `matchText` A {String} with the text of the match.
  #     * `range` The {Range} of the match.
  #     * `stop` Call this {Function} to terminate the scan.
  #     * `replace` Call this {Function} with a {String} to replace the match.
  scan: (regex, options={}, iterator) ->
    if _.isFunction(options)
      iterator = options
      options = {}

    @buffer.scan(regex, options, iterator)

  # Essential: Scan regular expression matches in a given range, calling the given
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

  # Essential: Scan regular expression matches in a given range in reverse order,
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
  setSoftTabs: (@softTabs) -> @update({@softTabs})

  # Returns a {Boolean} indicating whether atomic soft tabs are enabled for this editor.
  hasAtomicSoftTabs: -> @displayLayer.atomicSoftTabs

  # Essential: Toggle soft tabs for this editor
  toggleSoftTabs: -> @setSoftTabs(not @getSoftTabs())

  # Essential: Get the on-screen length of tab characters.
  #
  # Returns a {Number}.
  getTabLength: -> @tokenizedBuffer.getTabLength()

  # Essential: Set the on-screen length of tab characters. Setting this to a
  # {Number} This will override the `editor.tabLength` setting.
  #
  # * `tabLength` {Number} length of a single tab. Setting to `null` will
  #   fallback to using the `editor.tabLength` config setting
  setTabLength: (tabLength) -> @update({tabLength})

  # Returns an {Object} representing the current invisible character
  # substitutions for this editor. See {::setInvisibles}.
  getInvisibles: ->
    if not @mini and @showInvisibles and @invisibles?
      @invisibles
    else
      {}

  doesShowIndentGuide: -> @showIndentGuide and not @mini

  getSoftWrapHangingIndentLength: -> @displayLayer.softWrapHangingIndent

  # Extended: Determine if the buffer uses hard or soft tabs.
  #
  # Returns `true` if the first non-comment line with leading whitespace starts
  # with a space character. Returns `false` if it starts with a hard tab (`\t`).
  #
  # Returns a {Boolean} or undefined if no non-comment lines had leading
  # whitespace.
  usesSoftTabs: ->
    for bufferRow in [0..@buffer.getLastRow()]
      continue if @tokenizedBuffer.tokenizedLines[bufferRow]?.isComment()

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
  isSoftWrapped: -> @softWrapped

  # Essential: Enable or disable soft wrapping for this editor.
  #
  # * `softWrapped` A {Boolean}
  #
  # Returns a {Boolean}.
  setSoftWrapped: (softWrapped) ->
    @update({softWrapped})
    @isSoftWrapped()

  getPreferredLineLength: -> @preferredLineLength

  # Essential: Toggle soft wrapping for this editor
  #
  # Returns a {Boolean}.
  toggleSoftWrapped: -> @setSoftWrapped(not @isSoftWrapped())

  # Essential: Gets the column at which column will soft wrap
  getSoftWrapColumn: ->
    if @isSoftWrapped() and not @mini
      if @softWrapAtPreferredLineLength
        Math.min(@getEditorWidthInChars(), @preferredLineLength)
      else
        @getEditorWidthInChars()
    else
      MAX_SCREEN_LINE_LENGTH

  ###
  Section: Indentation
  ###

  # Essential: Get the indentation level of the given buffer row.
  #
  # Determines how deeply the given row is indented based on the soft tabs and
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
  # Determines how deeply the given line is indented based on the soft tabs and
  # tab length settings of this editor. Note that if soft tabs are enabled and
  # the tab length is 2, a row with 4 leading spaces would have an indentation
  # level of 2.
  #
  # * `line` A {String} representing a line of text.
  #
  # Returns a {Number}.
  indentLevelForLine: (line) ->
    @tokenizedBuffer.indentLevelForLine(line)

  # Extended: Indent rows intersecting selections based on the grammar's suggested
  # indent level.
  autoIndentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.autoIndentSelectedRows()

  # Indent all lines intersecting selections. See {Selection::indent} for more
  # information.
  indent: (options={}) ->
    options.autoIndent ?= @shouldAutoIndent()
    @mutateSelectedText (selection) -> selection.indent(options)

  # Constructs the string used for indents.
  buildIndentString: (level, column=0) ->
    if @getSoftTabs()
      tabStopViolation = column % @getTabLength()
      _.multiplyString(" ", Math.floor(level * @getTabLength()) - tabStopViolation)
    else
      excessWhitespace = _.multiplyString(' ', Math.round((level - Math.floor(level)) * @getTabLength()))
      _.multiplyString("\t", Math.floor(level)) + excessWhitespace

  ###
  Section: Grammars
  ###

  # Essential: Get the current {Grammar} of this editor.
  getGrammar: ->
    @tokenizedBuffer.grammar

  # Essential: Set the current {Grammar} of this editor.
  #
  # Assigning a grammar will cause the editor to re-tokenize based on the new
  # grammar.
  #
  # * `grammar` {Grammar}
  setGrammar: (grammar) ->
    @tokenizedBuffer.setGrammar(grammar)

  # Reload the grammar based on the file name.
  reloadGrammar: ->
    @tokenizedBuffer.reloadGrammar()

  # Experimental: Get a notification when async tokenization is completed.
  onDidTokenize: (callback) ->
    @tokenizedBuffer.onDidTokenize(callback)

  ###
  Section: Managing Syntax Scopes
  ###

  # Essential: Returns a {ScopeDescriptor} that includes this editor's language.
  # e.g. `['.source.ruby']`, or `['.source.coffee']`. You can use this with
  # {Config::get} to get language specific config values.
  getRootScopeDescriptor: ->
    @tokenizedBuffer.rootScopeDescriptor

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
    @tokenizedBuffer.scopeDescriptorForPosition(bufferPosition)

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
    @bufferRangeForScopeAtPosition(scopeSelector, @getCursorBufferPosition())

  bufferRangeForScopeAtPosition: (scopeSelector, position) ->
    @tokenizedBuffer.bufferRangeForScopeAtPosition(scopeSelector, position)

  # Extended: Determine if the given row is entirely a comment
  isBufferRowCommented: (bufferRow) ->
    if match = @lineTextForBufferRow(bufferRow).match(/\S/)
      @commentScopeSelector ?= new TextMateScopeSelector('comment.*')
      @commentScopeSelector.matches(@scopeDescriptorForBufferPosition([bufferRow, match.index]).scopes)

  # Get the scope descriptor at the cursor.
  getCursorScope: ->
    @getLastCursor().getScopeDescriptor()

  tokenForBufferPosition: (bufferPosition) ->
    @tokenizedBuffer.tokenForPosition(bufferPosition)

  ###
  Section: Clipboard Operations
  ###

  # Essential: For each selection, copy the selected text.
  copySelectedText: ->
    maintainClipboard = false
    for selection in @getSelectionsOrderedByBufferPosition()
      if selection.isEmpty()
        previousRange = selection.getBufferRange()
        selection.selectLine()
        selection.copy(maintainClipboard, true)
        selection.setBufferRange(previousRange)
      else
        selection.copy(maintainClipboard, false)
      maintainClipboard = true
    return

  # Private: For each selection, only copy highlighted text.
  copyOnlySelectedText: ->
    maintainClipboard = false
    for selection in @getSelectionsOrderedByBufferPosition()
      if not selection.isEmpty()
        selection.copy(maintainClipboard, false)
        maintainClipboard = true
    return

  # Essential: For each selection, cut the selected text.
  cutSelectedText: ->
    maintainClipboard = false
    @mutateSelectedText (selection) ->
      if selection.isEmpty()
        selection.selectLine()
        selection.cut(maintainClipboard, true)
      else
        selection.cut(maintainClipboard, false)
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
    {text: clipboardText, metadata} = @constructor.clipboard.readWithMetadata()
    return false unless @emitWillInsertTextEvent(clipboardText)

    metadata ?= {}
    options.autoIndent = @shouldAutoIndentOnPaste()

    @mutateSelectedText (selection, index) =>
      if metadata.selections?.length is @getSelections().length
        {text, indentBasis, fullLine} = metadata.selections[index]
      else
        {indentBasis, fullLine} = metadata
        text = clipboardText

      delete options.indentBasis
      {cursor} = selection
      if indentBasis?
        containsNewlines = text.indexOf('\n') isnt -1
        if containsNewlines or not cursor.hasPrecedingCharactersOnLine()
          options.indentBasis ?= indentBasis

      range = null
      if fullLine and selection.isEmpty()
        oldPosition = selection.getBufferRange().start
        selection.setBufferRange([[oldPosition.row, 0], [oldPosition.row, 0]])
        range = selection.insertText(text, options)
        newPosition = oldPosition.translate([1, 0])
        selection.setBufferRange([newPosition, newPosition])
      else
        range = selection.insertText(text, options)

      didInsertEvent = {text, range}
      @emitter.emit 'did-insert-text', didInsertEvent

  # Essential: For each selection, if the selection is empty, cut all characters
  # of the containing screen line following the cursor. Otherwise cut the selected
  # text.
  cutToEndOfLine: ->
    maintainClipboard = false
    @mutateSelectedText (selection) ->
      selection.cutToEndOfLine(maintainClipboard)
      maintainClipboard = true

  # Essential: For each selection, if the selection is empty, cut all characters
  # of the containing buffer line following the cursor. Otherwise cut the
  # selected text.
  cutToEndOfBufferLine: ->
    maintainClipboard = false
    @mutateSelectedText (selection) ->
      selection.cutToEndOfBufferLine(maintainClipboard)
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
    @displayLayer.destroyFoldsIntersectingBufferRange(Range(Point(bufferRow, 0), Point(bufferRow, Infinity)))

  # Extended: For each selection, fold the rows it intersects.
  foldSelectedLines: ->
    selection.fold() for selection in @getSelections()
    return

  # Extended: Fold all foldable lines.
  foldAll: ->
    @languageMode.foldAll()

  # Extended: Unfold all existing folds.
  unfoldAll: ->
    @languageMode.unfoldAll()
    @scrollToCursorPosition()

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
    @tokenizedBuffer.isFoldableAtRow(bufferRow)

  # Extended: Determine whether the given row in screen coordinates is foldable.
  #
  # A *foldable* row is a row that *starts* a row range that can be folded.
  #
  # * `bufferRow` A {Number}
  #
  # Returns a {Boolean}.
  isFoldableAtScreenRow: (screenRow) ->
    @isFoldableAtBufferRow(@bufferRowForScreenRow(screenRow))

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
    @displayLayer.foldsIntersectingBufferRange(Range(Point(bufferRow, 0), Point(bufferRow, Infinity))).length > 0

  # Extended: Determine whether the given row in screen coordinates is folded.
  #
  # * `screenRow` A {Number}
  #
  # Returns a {Boolean}.
  isFoldedAtScreenRow: (screenRow) ->
    @isFoldedAtBufferRow(@bufferRowForScreenRow(screenRow))

  # Creates a new fold between two row numbers.
  #
  # startRow - The row {Number} to start folding at
  # endRow - The row {Number} to end the fold
  #
  # Returns the new {Fold}.
  foldBufferRowRange: (startRow, endRow) ->
    @foldBufferRange(Range(Point(startRow, Infinity), Point(endRow, Infinity)))

  foldBufferRange: (range) ->
    @displayLayer.foldBufferRange(range)

  # Remove any {Fold}s found that intersect the given buffer range.
  destroyFoldsIntersectingBufferRange: (bufferRange) ->
    @displayLayer.destroyFoldsIntersectingBufferRange(bufferRange)

  ###
  Section: Gutters
  ###

  # Essential: Add a custom {Gutter}.
  #
  # * `options` An {Object} with the following fields:
  #   * `name` (required) A unique {String} to identify this gutter.
  #   * `priority` (optional) A {Number} that determines stacking order between
  #       gutters. Lower priority items are forced closer to the edges of the
  #       window. (default: -100)
  #   * `visible` (optional) {Boolean} specifying whether the gutter is visible
  #       initially after being created. (default: true)
  #
  # Returns the newly-created {Gutter}.
  addGutter: (options) ->
    @gutterContainer.addGutter(options)

  # Essential: Get this editor's gutters.
  #
  # Returns an {Array} of {Gutter}s.
  getGutters: ->
    @gutterContainer.getGutters()

  getLineNumberGutter: ->
    @lineNumberGutter

  # Essential: Get the gutter with the given name.
  #
  # Returns a {Gutter}, or `null` if no gutter exists for the given name.
  gutterWithName: (name) ->
    @gutterContainer.gutterWithName(name)

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
    @scrollToScreenPosition(@screenPositionForBufferPosition(bufferPosition), options)

  # Essential: Scrolls the editor to the given screen position.
  #
  # * `screenPosition` An object that represents a screen position. It can be either
  #    an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # * `options` (optional) {Object}
  #   * `center` Center the editor around the position if possible. (default: false)
  scrollToScreenPosition: (screenPosition, options) ->
    @scrollToScreenRange(new Range(screenPosition, screenPosition), options)

  scrollToTop: ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::scrollToTop instead.")

    @getElement().scrollToTop()

  scrollToBottom: ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::scrollToTop instead.")

    @getElement().scrollToBottom()

  scrollToScreenRange: (screenRange, options = {}) ->
    screenRange = @clipScreenRange(screenRange)
    scrollEvent = {screenRange, options}
    @emitter.emit "did-request-autoscroll", scrollEvent

  getHorizontalScrollbarHeight: ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::getHorizontalScrollbarHeight instead.")

    @getElement().getHorizontalScrollbarHeight()

  getVerticalScrollbarWidth: ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::getVerticalScrollbarWidth instead.")

    @getElement().getVerticalScrollbarWidth()

  pageUp: ->
    @moveUp(@getRowsPerPage())

  pageDown: ->
    @moveDown(@getRowsPerPage())

  selectPageUp: ->
    @selectUp(@getRowsPerPage())

  selectPageDown: ->
    @selectDown(@getRowsPerPage())

  # Returns the number of rows per page
  getRowsPerPage: ->
    Math.max(@rowsPerPage ? 1, 1)

  setRowsPerPage: (@rowsPerPage) ->

  ###
  Section: Config
  ###

  # Experimental: Supply an object that will provide the editor with settings
  # for specific syntactic scopes. See the `ScopedSettingsDelegate` in
  # `text-editor-registry.js` for an example implementation.
  setScopedSettingsDelegate: (@scopedSettingsDelegate) ->

  # Experimental: Retrieve the {Object} that provides the editor with settings
  # for specific syntactic scopes.
  getScopedSettingsDelegate: -> @scopedSettingsDelegate

  # Experimental: Is auto-indentation enabled for this editor?
  #
  # Returns a {Boolean}.
  shouldAutoIndent: -> @autoIndent

  # Experimental: Is auto-indentation on paste enabled for this editor?
  #
  # Returns a {Boolean}.
  shouldAutoIndentOnPaste: -> @autoIndentOnPaste

  # Experimental: Does this editor allow scrolling past the last line?
  #
  # Returns a {Boolean}.
  getScrollPastEnd: -> @scrollPastEnd

  # Experimental: How fast does the editor scroll in response to mouse wheel
  # movements?
  #
  # Returns a positive {Number}.
  getScrollSensitivity: -> @scrollSensitivity

  # Experimental: Does this editor show cursors while there is a selection?
  #
  # Returns a positive {Boolean}.
  getShowCursorOnSelection: -> @showCursorOnSelection

  # Experimental: Are line numbers enabled for this editor?
  #
  # Returns a {Boolean}
  doesShowLineNumbers: -> @showLineNumbers

  # Experimental: Get the time interval within which text editing operations
  # are grouped together in the editor's undo history.
  #
  # Returns the time interval {Number} in milliseconds.
  getUndoGroupingInterval: -> @undoGroupingInterval

  # Experimental: Get the characters that are *not* considered part of words,
  # for the purpose of word-based cursor movements.
  #
  # Returns a {String} containing the non-word characters.
  getNonWordCharacters: (scopes) ->
    @scopedSettingsDelegate?.getNonWordCharacters?(scopes) ? @nonWordCharacters

  getCommentStrings: (scopes) ->
    @scopedSettingsDelegate?.getCommentStrings?(scopes)

  getIncreaseIndentPattern: (scopes) ->
    @scopedSettingsDelegate?.getIncreaseIndentPattern?(scopes)

  getDecreaseIndentPattern: (scopes) ->
    @scopedSettingsDelegate?.getDecreaseIndentPattern?(scopes)

  getDecreaseNextIndentPattern: (scopes) ->
    @scopedSettingsDelegate?.getDecreaseNextIndentPattern?(scopes)

  getFoldEndPattern: (scopes) ->
    @scopedSettingsDelegate?.getFoldEndPattern?(scopes)

  ###
  Section: Event Handlers
  ###

  handleGrammarChange: ->
    @unfoldAll()
    @emitter.emit 'did-change-grammar', @getGrammar()

  ###
  Section: TextEditor Rendering
  ###

  # Get the Element for the editor.
  getElement: ->
    if @component?
      @component.element
    else
      TextEditorComponent ?= require('./text-editor-component')
      new TextEditorComponent({model: this, styleManager: atom.styles})
      @component.element

  # Essential: Retrieves the greyed out placeholder of a mini editor.
  #
  # Returns a {String}.
  getPlaceholderText: -> @placeholderText

  # Essential: Set the greyed out placeholder of a mini editor. Placeholder text
  # will be displayed when the editor has no content.
  #
  # * `placeholderText` {String} text that is displayed when the editor has no content.
  setPlaceholderText: (placeholderText) -> @update({placeholderText})

  pixelPositionForBufferPosition: (bufferPosition) ->
    Grim.deprecate("This method is deprecated on the model layer. Use `TextEditorElement::pixelPositionForBufferPosition` instead")
    @getElement().pixelPositionForBufferPosition(bufferPosition)

  pixelPositionForScreenPosition: (screenPosition) ->
    Grim.deprecate("This method is deprecated on the model layer. Use `TextEditorElement::pixelPositionForScreenPosition` instead")
    @getElement().pixelPositionForScreenPosition(screenPosition)

  getVerticalScrollMargin: ->
    maxScrollMargin = Math.floor(((@height / @getLineHeightInPixels()) - 1) / 2)
    Math.min(@verticalScrollMargin, maxScrollMargin)

  setVerticalScrollMargin: (@verticalScrollMargin) -> @verticalScrollMargin

  getHorizontalScrollMargin: -> Math.min(@horizontalScrollMargin, Math.floor(((@width / @getDefaultCharWidth()) - 1) / 2))
  setHorizontalScrollMargin: (@horizontalScrollMargin) -> @horizontalScrollMargin

  getLineHeightInPixels: -> @lineHeightInPixels
  setLineHeightInPixels: (@lineHeightInPixels) -> @lineHeightInPixels

  getKoreanCharWidth: -> @koreanCharWidth
  getHalfWidthCharWidth: -> @halfWidthCharWidth
  getDoubleWidthCharWidth: -> @doubleWidthCharWidth
  getDefaultCharWidth: -> @defaultCharWidth

  ratioForCharacter: (character) ->
    if isKoreanCharacter(character)
      @getKoreanCharWidth() / @getDefaultCharWidth()
    else if isHalfWidthCharacter(character)
      @getHalfWidthCharWidth() / @getDefaultCharWidth()
    else if isDoubleWidthCharacter(character)
      @getDoubleWidthCharWidth() / @getDefaultCharWidth()
    else
      1

  setDefaultCharWidth: (defaultCharWidth, doubleWidthCharWidth, halfWidthCharWidth, koreanCharWidth) ->
    doubleWidthCharWidth ?= defaultCharWidth
    halfWidthCharWidth ?= defaultCharWidth
    koreanCharWidth ?= defaultCharWidth
    if defaultCharWidth isnt @defaultCharWidth or doubleWidthCharWidth isnt @doubleWidthCharWidth and halfWidthCharWidth isnt @halfWidthCharWidth and koreanCharWidth isnt @koreanCharWidth
      @defaultCharWidth = defaultCharWidth
      @doubleWidthCharWidth = doubleWidthCharWidth
      @halfWidthCharWidth = halfWidthCharWidth
      @koreanCharWidth = koreanCharWidth
      if @isSoftWrapped()
        @displayLayer.reset({
          softWrapColumn: @getSoftWrapColumn()
        })
    defaultCharWidth

  setHeight: (height, reentrant=false) ->
    if reentrant
      @height = height
    else
      Grim.deprecate("This is now a view method. Call TextEditorElement::setHeight instead.")
      @getElement().setHeight(height)

  getHeight: ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::getHeight instead.")
    @height

  getAutoHeight: -> @autoHeight ? true

  getAutoWidth: -> @autoWidth ? false

  setWidth: (width, fromComponent=false) ->
    if fromComponent
      @update({width})
      @width
    else
      Grim.deprecate("This is now a view method. Call TextEditorElement::setWidth instead.")
      @getElement().setWidth(width)

  getWidth: ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::getWidth instead.")
    @width

  # Experimental: Scroll the editor such that the given screen row is at the
  # top of the visible area.
  setFirstVisibleScreenRow: (screenRow, fromView) ->
    unless fromView
      maxScreenRow = @getScreenLineCount() - 1
      unless @scrollPastEnd
        if @height? and @lineHeightInPixels?
          maxScreenRow -= Math.floor(@height / @lineHeightInPixels)
      screenRow = Math.max(Math.min(screenRow, maxScreenRow), 0)

    unless screenRow is @firstVisibleScreenRow
      @firstVisibleScreenRow = screenRow
      @emitter.emit 'did-change-first-visible-screen-row', screenRow unless fromView

  getFirstVisibleScreenRow: -> @firstVisibleScreenRow

  getLastVisibleScreenRow: ->
    if @height? and @lineHeightInPixels?
      Math.min(@firstVisibleScreenRow + Math.floor(@height / @lineHeightInPixels), @getScreenLineCount() - 1)
    else
      null

  getVisibleRowRange: ->
    if lastVisibleScreenRow = @getLastVisibleScreenRow()
      [@firstVisibleScreenRow, lastVisibleScreenRow]
    else
      null

  setFirstVisibleScreenColumn: (@firstVisibleScreenColumn) ->
  getFirstVisibleScreenColumn: -> @firstVisibleScreenColumn

  getScrollTop: ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::getScrollTop instead.")

    @getElement().getScrollTop()

  setScrollTop: (scrollTop) ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::setScrollTop instead.")

    @getElement().setScrollTop(scrollTop)

  getScrollBottom: ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::getScrollBottom instead.")

    @getElement().getScrollBottom()

  setScrollBottom: (scrollBottom) ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::setScrollBottom instead.")

    @getElement().setScrollBottom(scrollBottom)

  getScrollLeft: ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::getScrollLeft instead.")

    @getElement().getScrollLeft()

  setScrollLeft: (scrollLeft) ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::setScrollLeft instead.")

    @getElement().setScrollLeft(scrollLeft)

  getScrollRight: ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::getScrollRight instead.")

    @getElement().getScrollRight()

  setScrollRight: (scrollRight) ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::setScrollRight instead.")

    @getElement().setScrollRight(scrollRight)

  getScrollHeight: ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::getScrollHeight instead.")

    @getElement().getScrollHeight()

  getScrollWidth: ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::getScrollWidth instead.")

    @getElement().getScrollWidth()

  getMaxScrollTop: ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::getMaxScrollTop instead.")

    @getElement().getMaxScrollTop()

  intersectsVisibleRowRange: (startRow, endRow) ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::intersectsVisibleRowRange instead.")

    @getElement().intersectsVisibleRowRange(startRow, endRow)

  selectionIntersectsVisibleRowRange: (selection) ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::selectionIntersectsVisibleRowRange instead.")

    @getElement().selectionIntersectsVisibleRowRange(selection)

  screenPositionForPixelPosition: (pixelPosition) ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::screenPositionForPixelPosition instead.")

    @getElement().screenPositionForPixelPosition(pixelPosition)

  pixelRectForScreenRange: (screenRange) ->
    Grim.deprecate("This is now a view method. Call TextEditorElement::pixelRectForScreenRange instead.")

    @getElement().pixelRectForScreenRange(screenRange)

  ###
  Section: Utility
  ###

  inspect: ->
    "<TextEditor #{@id}>"

  emitWillInsertTextEvent: (text) ->
    result = true
    cancel = -> result = false
    willInsertEvent = {cancel, text}
    @emitter.emit 'will-insert-text', willInsertEvent
    result

  ###
  Section: Language Mode Delegated Methods
  ###

  suggestedIndentForBufferRow: (bufferRow, options) -> @languageMode.suggestedIndentForBufferRow(bufferRow, options)

  autoIndentBufferRow: (bufferRow, options) -> @languageMode.autoIndentBufferRow(bufferRow, options)

  autoIndentBufferRows: (startRow, endRow) -> @languageMode.autoIndentBufferRows(startRow, endRow)

  autoDecreaseIndentForBufferRow: (bufferRow) -> @languageMode.autoDecreaseIndentForBufferRow(bufferRow)

  toggleLineCommentForBufferRow: (row) -> @languageMode.toggleLineCommentsForBufferRow(row)

  toggleLineCommentsForBufferRows: (start, end) -> @languageMode.toggleLineCommentsForBufferRows(start, end)
