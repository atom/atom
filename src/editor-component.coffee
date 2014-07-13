React = require 'react-atom-fork'
{div, span} = require 'reactionary-atom-fork'
{debounce, defaults, isEqualForProperties} = require 'underscore-plus'
scrollbarStyle = require 'scrollbar-style'
{Range, Point} = require 'text-buffer'

GutterComponent = require './gutter-component'
InputComponent = require './input-component'
CursorsComponent = require './cursors-component'
LinesComponent = require './lines-component'
ScrollbarComponent = require './scrollbar-component'
ScrollbarCornerComponent = require './scrollbar-corner-component'
SubscriberMixin = require './subscriber-mixin'

DummyHighlightDecoration = {id: 'dummy', startPixelPosition: {top: 0, left: 0}, endPixelPosition: {top: 0, left: 0}, decorations: [{class: 'dummy'}]}

module.exports =
EditorComponent = React.createClass
  displayName: 'EditorComponent'
  mixins: [SubscriberMixin]

  statics:
    performSyncUpdates: false

  pendingScrollTop: null
  pendingScrollLeft: null
  selectOnMouseMove: false
  updateRequested: false
  updatesPaused: false
  updateRequestedWhilePaused: false
  cursorsMoved: false
  selectionChanged: false
  selectionAdded: false
  scrollingVertically: false
  gutterWidth: 0
  refreshingScrollbars: false
  measuringScrollbars: true
  pendingVerticalScrollDelta: 0
  pendingHorizontalScrollDelta: 0
  mouseWheelScreenRow: null
  mouseWheelScreenRowClearDelay: 150
  scrollSensitivity: 0.4
  scrollViewMeasurementRequested: false
  measureLineHeightAndDefaultCharWidthWhenShown: false
  remeasureCharacterWidthsIfVisibleAfterNextUpdate: false
  inputEnabled: true
  scrollViewMeasurementInterval: 100
  scopedCharacterWidthsChangeCount: null
  scrollViewMeasurementPaused: false
  autoHeight: false

  render: ->
    {focused, fontSize, lineHeight, fontFamily, showIndentGuide, showInvisibles, showLineNumbers, visible} = @state
    {editor, mini, cursorBlinkPeriod, cursorBlinkResumeDelay} = @props
    maxLineNumberDigits = editor.getLineCount().toString().length
    invisibles = if showInvisibles and not mini then @state.invisibles else {}
    hasSelection = editor.getSelection()? and !editor.getSelection().isEmpty()
    style = {fontSize, fontFamily}
    style.lineHeight = lineHeight unless mini

    if @isMounted()
      renderedRowRange = @getRenderedRowRange()
      [renderedStartRow, renderedEndRow] = renderedRowRange
      cursorPixelRects = @getCursorPixelRects(renderedRowRange)

      decorations = editor.decorationsForScreenRowRange(renderedStartRow, renderedEndRow)
      highlightDecorations = @getHighlightDecorations(decorations)
      lineDecorations = @getLineDecorations(decorations)

      scrollHeight = editor.getScrollHeight()
      scrollWidth = editor.getScrollWidth()
      scrollTop = editor.getScrollTop()
      scrollLeft = editor.getScrollLeft()
      lineHeightInPixels = editor.getLineHeightInPixels()
      defaultCharWidth = editor.getDefaultCharWidth()
      scrollViewHeight = editor.getHeight()
      lineWidth = Math.max(scrollWidth, editor.getWidth())
      horizontalScrollbarHeight = editor.getHorizontalScrollbarHeight()
      verticalScrollbarWidth = editor.getVerticalScrollbarWidth()
      verticallyScrollable = editor.verticallyScrollable()
      horizontallyScrollable = editor.horizontallyScrollable()
      hiddenInputStyle = @getHiddenInputPosition()
      hiddenInputStyle.WebkitTransform = 'translateZ(0)' if @useHardwareAcceleration
      if @mouseWheelScreenRow? and not (renderedStartRow <= @mouseWheelScreenRow < renderedEndRow)
        mouseWheelScreenRow = @mouseWheelScreenRow
      style.height = scrollViewHeight if @autoHeight

    className = 'editor-contents editor-colors'
    className += ' is-focused' if focused
    className += ' has-selection' if hasSelection

    div {className, style, tabIndex: -1},
      if not mini and showLineNumbers
        GutterComponent {
          ref: 'gutter', onMouseDown: @onGutterMouseDown, onWidthChanged: @onGutterWidthChanged,
          lineDecorations, defaultCharWidth, editor, renderedRowRange, maxLineNumberDigits, scrollViewHeight,
          scrollTop, scrollHeight, lineHeightInPixels, @pendingChanges, mouseWheelScreenRow, @useHardwareAcceleration
        }

      div ref: 'scrollView', className: 'scroll-view', onMouseDown: @onMouseDown,
        InputComponent
          ref: 'input'
          className: 'hidden-input'
          style: hiddenInputStyle
          onFocus: @onInputFocused
          onBlur: @onInputBlurred

        CursorsComponent {
          scrollTop, scrollLeft, cursorPixelRects, cursorBlinkPeriod, cursorBlinkResumeDelay,
          lineHeightInPixels, defaultCharWidth, @scopedCharacterWidthsChangeCount, @useHardwareAcceleration
        }
        LinesComponent {
          ref: 'lines',
          editor, lineHeightInPixels, defaultCharWidth, lineDecorations, highlightDecorations,
          showIndentGuide, renderedRowRange, @pendingChanges, scrollTop, scrollLeft,
          @scrollingVertically, scrollHeight, scrollWidth, mouseWheelScreenRow, invisibles,
          visible, scrollViewHeight, @scopedCharacterWidthsChangeCount, lineWidth, @useHardwareAcceleration
        }

      ScrollbarComponent
        ref: 'verticalScrollbar'
        className: 'vertical-scrollbar'
        orientation: 'vertical'
        onScroll: @onVerticalScroll
        scrollTop: scrollTop
        scrollHeight: scrollHeight
        visible: verticallyScrollable and not @refreshingScrollbars and not @measuringScrollbars
        scrollableInOppositeDirection: horizontallyScrollable
        verticalScrollbarWidth: verticalScrollbarWidth
        horizontalScrollbarHeight: horizontalScrollbarHeight

      ScrollbarComponent
        ref: 'horizontalScrollbar'
        className: 'horizontal-scrollbar'
        orientation: 'horizontal'
        onScroll: @onHorizontalScroll
        scrollLeft: scrollLeft
        scrollWidth: scrollWidth + @gutterWidth
        visible: horizontallyScrollable and not @refreshingScrollbars and not @measuringScrollbars
        scrollableInOppositeDirection: verticallyScrollable
        verticalScrollbarWidth: verticalScrollbarWidth
        horizontalScrollbarHeight: horizontalScrollbarHeight

      # Also used to measure the height/width of scrollbars after the initial render
      ScrollbarCornerComponent
        ref: 'scrollbarCorner'
        visible: not @refreshingScrollbars and (@measuringScrollbars or horizontallyScrollable and verticallyScrollable)
        measuringScrollbars: @measuringScrollbars
        height: horizontalScrollbarHeight
        width: verticalScrollbarWidth

  getPageRows: ->
    {editor} = @props
    Math.max(1, Math.ceil(editor.getHeight() / editor.getLineHeightInPixels()))

  getInitialState: ->
    visible: true

  getDefaultProps: ->
    cursorBlinkPeriod: 800
    cursorBlinkResumeDelay: 100
    lineOverdrawMargin: 8

  componentWillMount: ->
    @pendingChanges = []
    @props.editor.manageScrollPosition = true
    @observeConfig()
    @setScrollSensitivity(atom.config.get('editor.scrollSensitivity'))

  componentDidMount: ->
    {editor} = @props

    @scrollViewMeasurementIntervalId = setInterval(@measureScrollView, @scrollViewMeasurementInterval)

    @observeEditor()
    @listenForDOMEvents()
    @listenForCommands()

    @subscribe atom.themes, 'stylesheet-added stylsheet-removed', @onStylesheetsChanged
    @subscribe scrollbarStyle.changes, @refreshScrollbars

    editor.setVisible(true)

    @measureLineHeightAndDefaultCharWidth()
    @measureScrollView()
    @measureScrollbars()

  componentWillUnmount: ->
    @props.parentView.trigger 'editor:will-be-removed', [@props.parentView]
    @unsubscribe()
    clearInterval(@scrollViewMeasurementIntervalId)
    @scrollViewMeasurementIntervalId = null

  componentDidUpdate: (prevProps, prevState) ->
    cursorsMoved = @cursorsMoved
    selectionChanged = @selectionChanged
    @pendingChanges.length = 0
    @cursorsMoved = false
    @selectionChanged = false
    @refreshingScrollbars = false

    if @props.editor.isAlive()
      @updateParentViewFocusedClassIfNeeded(prevState)
      @updateParentViewMiniClassIfNeeded(prevState)
      @props.parentView.trigger 'cursor:moved' if cursorsMoved
      @props.parentView.trigger 'selection:changed' if selectionChanged
      @props.parentView.trigger 'editor:display-updated'

    @measureScrollbars() if @measuringScrollbars
    @measureLineHeightAndCharWidthsIfNeeded(prevState)
    @remeasureCharacterWidthsIfNeeded(prevState)

  requestUpdate: ->
    if @updatesPaused
      @updateRequestedWhilePaused = true
      return

    if @performSyncUpdates ? EditorComponent.performSyncUpdates
      @forceUpdate()
    else unless @updateRequested
      @updateRequested = true
      setImmediate =>
        @updateRequested = false
        @forceUpdate() if @isMounted()

  requestAnimationFrame: (fn) ->
    @updatesPaused = true
    @pauseScrollViewMeasurement()
    requestAnimationFrame =>
      fn()
      @updatesPaused = false
      if @updateRequestedWhilePaused and @isMounted()
        @updateRequestedWhilePaused = false
        @forceUpdate()

  getRenderedRowRange: ->
    {editor, lineOverdrawMargin} = @props
    [visibleStartRow, visibleEndRow] = editor.getVisibleRowRange()
    renderedStartRow = Math.max(0, visibleStartRow - lineOverdrawMargin)
    renderedEndRow = Math.min(editor.getScreenLineCount(), visibleEndRow + lineOverdrawMargin)
    [renderedStartRow, renderedEndRow]

  getHiddenInputPosition: ->
    {editor} = @props
    {focused} = @state
    return {top: 0, left: 0} unless @isMounted() and focused and editor.getCursor()?

    {top, left, height, width} = editor.getCursor().getPixelRect()
    width = 2 if width is 0 # Prevent autoscroll at the end of longest line
    top -= editor.getScrollTop()
    left -= editor.getScrollLeft()
    top = Math.max(0, Math.min(editor.getHeight() - height, top))
    left = Math.max(0, Math.min(editor.getWidth() - width, left))
    {top, left}

  getCursorScreenRanges: (renderedRowRange) ->
    {editor} = @props
    [renderedStartRow, renderedEndRow] = renderedRowRange

    cursorScreenRanges = {}
    for selection in editor.getSelections() when selection.isEmpty()
      {cursor} = selection
      screenRange = cursor.getScreenRange()
      if renderedStartRow <= screenRange.start.row < renderedEndRow
        cursorScreenRanges[cursor.id] = screenRange
    cursorScreenRanges

  getCursorPixelRects: (renderedRowRange) ->
    {editor} = @props
    [renderedStartRow, renderedEndRow] = renderedRowRange

    cursorPixelRects = {}
    for selection in editor.getSelections() when selection.isEmpty()
      {cursor} = selection
      screenRange = cursor.getScreenRange()
      if renderedStartRow <= screenRange.start.row < renderedEndRow
        cursorPixelRects[cursor.id] = editor.pixelRectForScreenRange(screenRange)
    cursorPixelRects

  getLineDecorations: (decorationsByMarkerId) ->
    {editor} = @props
    decorationsByScreenRow = {}
    for markerId, decorations of decorationsByMarkerId
      marker = editor.getMarker(markerId)
      screenRange = null
      headScreenRow = null
      if marker.isValid()
        for decoration in decorations
          if decoration.isType('gutter') or decoration.isType('line')
            decorationParams = decoration.getParams()
            screenRange ?= marker.getScreenRange()
            headScreenRow ?= marker.getHeadScreenPosition().row
            startRow = screenRange.start.row
            endRow = screenRange.end.row
            endRow-- if not screenRange.isEmpty() and screenRange.end.column == 0
            for screenRow in [startRow..endRow]
              continue if decorationParams.onlyHead and screenRow isnt headScreenRow
              if screenRange.isEmpty()
                continue if decorationParams.onlyNonEmpty
              else
                continue if decorationParams.onlyEmpty

              decorationsByScreenRow[screenRow] ?= {}
              decorationsByScreenRow[screenRow][decoration.id] = decorationParams

    decorationsByScreenRow

  getHighlightDecorations: (decorationsByMarkerId) ->
    {editor} = @props
    filteredDecorations = {}
    for markerId, decorations of decorationsByMarkerId
      marker = editor.getMarker(markerId)
      screenRange = marker.getScreenRange()
      if marker.isValid() and not screenRange.isEmpty()
        for decoration in decorations
          if decoration.isType('highlight')
            decorationParams = decoration.getParams()
            filteredDecorations[markerId] ?=
              id: markerId
              startPixelPosition: editor.pixelPositionForScreenPosition(screenRange.start)
              endPixelPosition: editor.pixelPositionForScreenPosition(screenRange.end)
              decorations: []
            filteredDecorations[markerId].decorations.push decorationParams

    # At least in Chromium 31, removing the last highlight causes a rendering
    # artifact where chunks of the lines disappear, so we always leave this
    # dummy highlight in place to prevent that.
    filteredDecorations['dummy'] = DummyHighlightDecoration

    filteredDecorations

  observeEditor: ->
    {editor} = @props
    @subscribe editor, 'screen-lines-changed', @onScreenLinesChanged
    @subscribe editor, 'cursors-moved', @onCursorsMoved
    @subscribe editor, 'selection-removed selection-screen-range-changed', @onSelectionChanged
    @subscribe editor, 'selection-added', @onSelectionAdded
    @subscribe editor, 'decoration-added', @onDecorationChanged
    @subscribe editor, 'decoration-removed', @onDecorationChanged
    @subscribe editor, 'decoration-changed', @onDecorationChanged
    @subscribe editor, 'decoration-updated', @onDecorationChanged
    @subscribe editor, 'character-widths-changed', @onCharacterWidthsChanged
    @subscribe editor.$scrollTop.changes, @onScrollTopChanged
    @subscribe editor.$scrollLeft.changes, @requestUpdate
    @subscribe editor.$height.changes, @requestUpdate
    @subscribe editor.$width.changes, @requestUpdate
    @subscribe editor.$defaultCharWidth.changes, @requestUpdate
    @subscribe editor.$lineHeightInPixels.changes, @requestUpdate

  listenForDOMEvents: ->
    node = @getDOMNode()
    node.addEventListener 'mousewheel', @onMouseWheel
    node.addEventListener 'focus', @onFocus # For some reason, React's built in focus events seem to bubble
    node.addEventListener 'textInput', @onTextInput

    scrollViewNode = @refs.scrollView.getDOMNode()
    scrollViewNode.addEventListener 'scroll', @onScrollViewScroll
    window.addEventListener 'resize', @requestScrollViewMeasurement

    @listenForIMEEvents()

  listenForIMEEvents: ->
    node = @getDOMNode()
    {editor} = @props

    # The IME composition events work like this:
    #
    # User types 's', chromium pops up the completion helper
    #   1. compositionstart fired
    #   2. compositionupdate fired; event.data == 's'
    # User hits arrow keys to move around in completion helper
    #   3. compositionupdate fired; event.data == 's' for each arry key press
    # User escape to cancel
    #   4. compositionend fired
    # OR User chooses a completion
    #   4. compositionend fired
    #   5. textInput fired; event.data == the completion string

    selectedText = null
    node.addEventListener 'compositionstart', ->
      selectedText = editor.getSelectedText()
    node.addEventListener 'compositionupdate', (event) ->
      editor.insertText(event.data, select: true, undo: 'skip')
    node.addEventListener 'compositionend', (event) ->
      editor.insertText(selectedText, select: true, undo: 'skip')
      event.target.value = ''

  listenForCommands: ->
    {parentView, editor, mini} = @props

    @addCommandListeners
      'core:move-left': => editor.moveCursorLeft()
      'core:move-right': => editor.moveCursorRight()
      'core:select-left': => editor.selectLeft()
      'core:select-right': => editor.selectRight()
      'core:select-all': => editor.selectAll()
      'core:backspace': => editor.backspace()
      'core:delete': => editor.delete()
      'core:undo': => editor.undo()
      'core:redo': => editor.redo()
      'core:cut': => editor.cutSelectedText()
      'core:copy': => editor.copySelectedText()
      'core:paste': => editor.pasteText()
      'editor:move-to-previous-word': => editor.moveCursorToPreviousWord()
      'editor:select-word': => editor.selectWord()
      'editor:consolidate-selections': @consolidateSelections
      'editor:delete-to-beginning-of-word': => editor.deleteToBeginningOfWord()
      'editor:delete-to-beginning-of-line': => editor.deleteToBeginningOfLine()
      'editor:delete-to-end-of-line': => editor.deleteToEndOfLine()
      'editor:delete-to-end-of-word': => editor.deleteToEndOfWord()
      'editor:delete-line': => editor.deleteLine()
      'editor:cut-to-end-of-line': => editor.cutToEndOfLine()
      'editor:move-to-beginning-of-next-paragraph': => editor.moveCursorToBeginningOfNextParagraph()
      'editor:move-to-beginning-of-previous-paragraph': => editor.moveCursorToBeginningOfPreviousParagraph()
      'editor:move-to-beginning-of-screen-line': => editor.moveCursorToBeginningOfScreenLine()
      'editor:move-to-beginning-of-line': => editor.moveCursorToBeginningOfLine()
      'editor:move-to-end-of-screen-line': => editor.moveCursorToEndOfScreenLine()
      'editor:move-to-end-of-line': => editor.moveCursorToEndOfLine()
      'editor:move-to-first-character-of-line': => editor.moveCursorToFirstCharacterOfLine()
      'editor:move-to-beginning-of-word': => editor.moveCursorToBeginningOfWord()
      'editor:move-to-end-of-word': => editor.moveCursorToEndOfWord()
      'editor:move-to-beginning-of-next-word': => editor.moveCursorToBeginningOfNextWord()
      'editor:move-to-previous-word-boundary': => editor.moveCursorToPreviousWordBoundary()
      'editor:move-to-next-word-boundary': => editor.moveCursorToNextWordBoundary()
      'editor:select-to-beginning-of-next-paragraph': => editor.selectToBeginningOfNextParagraph()
      'editor:select-to-beginning-of-previous-paragraph': => editor.selectToBeginningOfPreviousParagraph()
      'editor:select-to-end-of-line': => editor.selectToEndOfLine()
      'editor:select-to-beginning-of-line': => editor.selectToBeginningOfLine()
      'editor:select-to-end-of-word': => editor.selectToEndOfWord()
      'editor:select-to-beginning-of-word': => editor.selectToBeginningOfWord()
      'editor:select-to-beginning-of-next-word': => editor.selectToBeginningOfNextWord()
      'editor:select-to-next-word-boundary': => editor.selectToNextWordBoundary()
      'editor:select-to-previous-word-boundary': => editor.selectToPreviousWordBoundary()
      'editor:select-to-first-character-of-line': => editor.selectToFirstCharacterOfLine()
      'editor:select-line': => editor.selectLine()
      'editor:transpose': => editor.transpose()
      'editor:upper-case': => editor.upperCase()
      'editor:lower-case': => editor.lowerCase()

    unless mini
      @addCommandListeners
        'core:move-up': => editor.moveCursorUp()
        'core:move-down': => editor.moveCursorDown()
        'core:move-to-top': => editor.moveCursorToTop()
        'core:move-to-bottom': => editor.moveCursorToBottom()
        'core:page-up': => editor.pageUp()
        'core:page-down': => editor.pageDown()
        'core:select-up': => editor.selectUp()
        'core:select-down': => editor.selectDown()
        'core:select-to-top': => editor.selectToTop()
        'core:select-to-bottom': => editor.selectToBottom()
        'core:select-page-up': => editor.selectPageUp()
        'core:select-page-down': => editor.selectPageDown()
        'editor:indent': => editor.indent()
        'editor:auto-indent': => editor.autoIndentSelectedRows()
        'editor:indent-selected-rows': => editor.indentSelectedRows()
        'editor:outdent-selected-rows': => editor.outdentSelectedRows()
        'editor:newline': => editor.insertNewline()
        'editor:newline-below': => editor.insertNewlineBelow()
        'editor:newline-above': => editor.insertNewlineAbove()
        'editor:add-selection-below': => editor.addSelectionBelow()
        'editor:add-selection-above': => editor.addSelectionAbove()
        'editor:split-selections-into-lines': => editor.splitSelectionsIntoLines()
        'editor:toggle-soft-tabs': => editor.toggleSoftTabs()
        'editor:toggle-soft-wrap': => editor.toggleSoftWrap()
        'editor:fold-all': => editor.foldAll()
        'editor:unfold-all': => editor.unfoldAll()
        'editor:fold-current-row': => editor.foldCurrentRow()
        'editor:unfold-current-row': => editor.unfoldCurrentRow()
        'editor:fold-selection': => editor.foldSelectedLines()
        'editor:fold-at-indent-level-1': => editor.foldAllAtIndentLevel(0)
        'editor:fold-at-indent-level-2': => editor.foldAllAtIndentLevel(1)
        'editor:fold-at-indent-level-3': => editor.foldAllAtIndentLevel(2)
        'editor:fold-at-indent-level-4': => editor.foldAllAtIndentLevel(3)
        'editor:fold-at-indent-level-5': => editor.foldAllAtIndentLevel(4)
        'editor:fold-at-indent-level-6': => editor.foldAllAtIndentLevel(5)
        'editor:fold-at-indent-level-7': => editor.foldAllAtIndentLevel(6)
        'editor:fold-at-indent-level-8': => editor.foldAllAtIndentLevel(7)
        'editor:fold-at-indent-level-9': => editor.foldAllAtIndentLevel(8)
        'editor:toggle-line-comments': => editor.toggleLineCommentsInSelection()
        'editor:log-cursor-scope': => editor.logCursorScope()
        'editor:checkout-head-revision': => editor.checkoutHead()
        'editor:copy-path': => editor.copyPathToClipboard()
        'editor:move-line-up': => editor.moveLineUp()
        'editor:move-line-down': => editor.moveLineDown()
        'editor:duplicate-lines': => editor.duplicateLines()
        'editor:join-lines': => editor.joinLines()
        'editor:toggle-indent-guide': => atom.config.toggle('editor.showIndentGuide')
        'editor:toggle-line-numbers': =>  atom.config.toggle('editor.showLineNumbers')
        'editor:scroll-to-cursor': => editor.scrollToCursorPosition()
        'benchmark:scroll': @runScrollBenchmark

  addCommandListeners: (listenersByCommandName) ->
    {parentView} = @props

    for command, listener of listenersByCommandName
      parentView.command command, listener

  observeConfig: ->
    @subscribe atom.config.observe 'editor.fontFamily', @setFontFamily
    @subscribe atom.config.observe 'editor.fontSize', @setFontSize
    @subscribe atom.config.observe 'editor.lineHeight', @setLineHeight
    @subscribe atom.config.observe 'editor.showIndentGuide', @setShowIndentGuide
    @subscribe atom.config.observe 'editor.invisibles', @setInvisibles
    @subscribe atom.config.observe 'editor.showInvisibles', @setShowInvisibles
    @subscribe atom.config.observe 'editor.showLineNumbers', @setShowLineNumbers
    @subscribe atom.config.observe 'editor.scrollSensitivity', @setScrollSensitivity
    @subscribe atom.config.observe 'editor.useHardwareAcceleration', @setUseHardwareAcceleration

  onFocus: ->
    @refs.input.focus()

  onTextInput: (event) ->
    return unless @isInputEnabled()

    {editor} = @props
    inputNode = event.target

    # Work around of the accented character suggestion feature in OS X.
    # Text input fires before a character is inserted, and if the browser is
    # replacing the previous un-accented character with an accented variant, it
    # will select backward over it.
    selectedLength = inputNode.selectionEnd - inputNode.selectionStart
    editor.selectLeft() if selectedLength is 1

    editor.insertText(event.data)
    inputNode.value = event.data

    # If we prevent the insertion of a space character, then the browser
    # interprets the spacebar keypress as a page-down command.
    event.preventDefault() unless event.data is ' '

  onInputFocused: ->
    @setState(focused: true)

  onInputBlurred: ->
    @setState(focused: false)

  onVerticalScroll: (scrollTop) ->
    {editor} = @props

    return if @updateRequested or scrollTop is editor.getScrollTop()

    animationFramePending = @pendingScrollTop?
    @pendingScrollTop = scrollTop
    unless animationFramePending
      @requestAnimationFrame =>
        pendingScrollTop = @pendingScrollTop
        @pendingScrollTop = null
        @props.editor.setScrollTop(pendingScrollTop)

  onHorizontalScroll: (scrollLeft) ->
    {editor} = @props

    return if @updateRequested or scrollLeft is editor.getScrollLeft()

    animationFramePending = @pendingScrollLeft?
    @pendingScrollLeft = scrollLeft
    unless animationFramePending
      @requestAnimationFrame =>
        @props.editor.setScrollLeft(@pendingScrollLeft)
        @pendingScrollLeft = null

  onMouseWheel: (event) ->
    event.preventDefault()
    animationFramePending = @pendingHorizontalScrollDelta isnt 0 or @pendingVerticalScrollDelta isnt 0

    # Only scroll in one direction at a time
    {wheelDeltaX, wheelDeltaY} = event
    if Math.abs(wheelDeltaX) > Math.abs(wheelDeltaY)
      # Scrolling horizontally
      @pendingHorizontalScrollDelta -= Math.round(wheelDeltaX * @scrollSensitivity)
    else
      # Scrolling vertically
      @pendingVerticalScrollDelta -= Math.round(wheelDeltaY * @scrollSensitivity)
      @mouseWheelScreenRow = @screenRowForNode(event.target)
      @clearMouseWheelScreenRowAfterDelay ?= debounce(@clearMouseWheelScreenRow, @mouseWheelScreenRowClearDelay)
      @clearMouseWheelScreenRowAfterDelay()

    unless animationFramePending
      @requestAnimationFrame =>
        {editor} = @props
        editor.setScrollTop(editor.getScrollTop() + @pendingVerticalScrollDelta)
        editor.setScrollLeft(editor.getScrollLeft() + @pendingHorizontalScrollDelta)
        @pendingVerticalScrollDelta = 0
        @pendingHorizontalScrollDelta = 0

  onScrollViewScroll: ->
    if @isMounted()
      console.warn "EditorScrollView scrolled when it shouldn't have."
      scrollViewNode = @refs.scrollView.getDOMNode()
      scrollViewNode.scrollTop = 0
      scrollViewNode.scrollLeft = 0

  onMouseDown: (event) ->
    return unless event.button is 0 # only handle the left mouse button

    {editor} = @props
    {detail, shiftKey, metaKey, ctrlKey} = event
    screenPosition = @screenPositionForMouseEvent(event)

    if event.target?.classList.contains('fold-marker')
      bufferRow = editor.bufferRowForScreenRow(screenPosition.row)
      editor.unfoldBufferRow(bufferRow)
      return

    switch detail
      when 1
        if shiftKey
          editor.selectToScreenPosition(screenPosition)
        else if metaKey or (ctrlKey and process.platform isnt 'darwin')
          editor.addCursorAtScreenPosition(screenPosition)
        else
          editor.setCursorScreenPosition(screenPosition)
      when 2
        editor.getLastSelection().selectWord()
      when 3
        editor.getLastSelection().selectLine()

    @handleDragUntilMouseUp event, (screenPosition) ->
      editor.selectToScreenPosition(screenPosition)

  onGutterMouseDown: (event) ->
    return unless event.button is 0 # only handle the left mouse button

    if event.shiftKey
      @onGutterShiftClick(event)
    else
      @onGutterClick(event)

  onGutterClick: (event) ->
    {editor} = @props
    clickedRow = @screenPositionForMouseEvent(event).row

    editor.setCursorScreenPosition([clickedRow, 0])

    @handleDragUntilMouseUp event, (screenPosition) ->
      dragRow = screenPosition.row
      if dragRow < clickedRow # dragging up
        editor.setSelectedScreenRange([[dragRow, 0], [clickedRow + 1, 0]])
      else
        editor.setSelectedScreenRange([[clickedRow, 0], [dragRow + 1, 0]])

  onGutterShiftClick: (event) ->
    {editor} = @props
    clickedRow = @screenPositionForMouseEvent(event).row
    tailPosition = editor.getSelection().getTailScreenPosition()

    if clickedRow < tailPosition.row
      editor.selectToScreenPosition([clickedRow, 0])
    else
      editor.selectToScreenPosition([clickedRow + 1, 0])

    @handleDragUntilMouseUp event, (screenPosition) ->
      dragRow = screenPosition.row
      if dragRow < tailPosition.row # dragging up
        editor.setSelectedScreenRange([[dragRow, 0], tailPosition])
      else
        editor.setSelectedScreenRange([tailPosition, [dragRow + 1, 0]])

  onStylesheetsChanged: (stylesheet) ->
    @refreshScrollbars() if @containsScrollbarSelector(stylesheet)
    @remeasureCharacterWidthsIfVisibleAfterNextUpdate = true
    @requestUpdate() if @state.visible

  onScreenLinesChanged: (change) ->
    {editor} = @props
    @pendingChanges.push(change)
    @requestUpdate() if editor.intersectsVisibleRowRange(change.start, change.end + 1) # TODO: Use closed-open intervals for change events

  onSelectionChanged: (selection) ->
    {editor} = @props
    if editor.selectionIntersectsVisibleRowRange(selection)
      @selectionChanged = true
      @requestUpdate()

  onSelectionAdded: (selection) ->
    {editor} = @props
    if editor.selectionIntersectsVisibleRowRange(selection)
      @selectionChanged = true
      @selectionAdded = true
      @requestUpdate()

  onScrollTopChanged: ->
    @scrollingVertically = true
    @requestUpdate()
    @onStoppedScrollingAfterDelay ?= debounce(@onStoppedScrolling, 200)
    @onStoppedScrollingAfterDelay()

  onStoppedScrolling: ->
    return unless @isMounted()

    @scrollingVertically = false
    @mouseWheelScreenRow = null
    @requestUpdate()

  onStoppedScrollingAfterDelay: null # created lazily

  onCursorsMoved: ->
    @cursorsMoved = true
    @requestUpdate()

  onDecorationChanged: ->
    @requestUpdate()

  onCharacterWidthsChanged: (@scopedCharacterWidthsChangeCount) ->
    @requestUpdate()

  handleDragUntilMouseUp: (event, dragHandler) ->
    {editor} = @props
    dragging = false
    lastMousePosition = {}
    animationLoop = =>
      @requestAnimationFrame =>
        if dragging
          screenPosition = @screenPositionForMouseEvent(lastMousePosition)
          dragHandler(screenPosition)
          animationLoop()

    onMouseMove = (event) ->
      lastMousePosition.clientX = event.clientX
      lastMousePosition.clientY = event.clientY

      # Start the animation loop when the mouse moves prior to a mouseup event
      unless dragging
        dragging = true
        animationLoop()

      # Stop dragging when cursor enters dev tools because we can't detect mouseup
      onMouseUp() if event.which is 0

    onMouseUp = ->
      dragging = false
      window.removeEventListener('mousemove', onMouseMove)
      window.removeEventListener('mouseup', onMouseUp)
      editor.finalizeSelections()

    window.addEventListener('mousemove', onMouseMove)
    window.addEventListener('mouseup', onMouseUp)

  pauseScrollViewMeasurement: ->
    @scrollViewMeasurementPaused = true
    @resumeScrollViewMeasurementAfterDelay ?= debounce(@resumeScrollViewMeasurement, 100)
    @resumeScrollViewMeasurementAfterDelay()

  resumeScrollViewMeasurement: ->
    @scrollViewMeasurementPaused = false

  resumeScrollViewMeasurementAfterDelay: null # created lazily

  requestScrollViewMeasurement: ->
    return if @scrollViewMeasurementRequested

    @scrollViewMeasurementRequested = true
    requestAnimationFrame =>
      @scrollViewMeasurementRequested = false
      @measureScrollView()

  # Measure explicitly-styled height and width and relay them to the model. If
  # these values aren't explicitly styled, we assume the editor is unconstrained
  # and use the scrollHeight / scrollWidth as its height and width in
  # calculations.
  measureScrollView: ->
    return if @scrollViewMeasurementPaused
    return unless @isMounted()

    {editor, parentView} = @props
    parentNode = parentView.element
    scrollViewNode = @refs.scrollView.getDOMNode()
    {position} = getComputedStyle(parentNode)
    {height} = parentNode.style

    if position is 'absolute' or height
      if @autoHeight
        @autoHeight = false
        @forceUpdate()

      clientHeight =  scrollViewNode.clientHeight
      editor.setHeight(clientHeight) if clientHeight > 0
    else
      editor.setHeight(null)
      @autoHeight = true

    clientWidth = scrollViewNode.clientWidth
    paddingLeft = parseInt(getComputedStyle(scrollViewNode).paddingLeft)
    clientWidth -= paddingLeft
    editor.setWidth(clientWidth) if clientWidth > 0

  measureLineHeightAndCharWidthsIfNeeded: (prevState) ->
    if not isEqualForProperties(prevState, @state, 'lineHeight', 'fontSize', 'fontFamily')
      if @state.visible
        @measureLineHeightAndDefaultCharWidth()
      else
        @measureLineHeightAndDefaultCharWidthWhenShown = true
    else if @measureLineHeightAndDefaultCharWidthWhenShown and @state.visible and not prevState.visible
      @measureLineHeightAndDefaultCharWidth()

  measureLineHeightAndDefaultCharWidth: ->
    @measureLineHeightAndDefaultCharWidthWhenShown = false
    @refs.lines.measureLineHeightAndDefaultCharWidth()

  remeasureCharacterWidthsIfNeeded: (prevState) ->
    if not isEqualForProperties(prevState, @state, 'fontSize', 'fontFamily')
      if @state.visible
        @remeasureCharacterWidths()
      else
        @remeasureCharacterWidthsIfVisibleAfterNextUpdate = true
    else if @remeasureCharacterWidthsIfVisibleAfterNextUpdate and @state.visible
      @remeasureCharacterWidthsIfVisibleAfterNextUpdate = false
      @remeasureCharacterWidths()

  remeasureCharacterWidths: ->
    @refs.lines.remeasureCharacterWidths()

  onGutterWidthChanged: (@gutterWidth) ->
    @requestUpdate()

  measureScrollbars: ->
    @measuringScrollbars = false

    {editor} = @props
    scrollbarCornerNode = @refs.scrollbarCorner.getDOMNode()
    width = (scrollbarCornerNode.offsetWidth - scrollbarCornerNode.clientWidth) or 15
    height = (scrollbarCornerNode.offsetHeight - scrollbarCornerNode.clientHeight) or 15
    editor.setVerticalScrollbarWidth(width)
    editor.setHorizontalScrollbarHeight(height)

  containsScrollbarSelector: (stylesheet) ->
    for rule in stylesheet.cssRules
      if rule.selectorText?.indexOf('scrollbar') > -1
        return true
    false

  refreshScrollbars: ->
    # Believe it or not, proper handling of changes to scrollbar styles requires
    # three DOM updates.

    # Scrollbar style changes won't apply to scrollbars that are already
    # visible, so first we need to hide scrollbars so we can redisplay them and
    # force Chromium to apply updates.
    @refreshingScrollbars = true
    @forceUpdate()

    # Next, we display only the scrollbar corner so we can measure the new
    # scrollbar dimensions. The ::measuringScrollbars property will be set back
    # to false after the scrollbars are measured.
    @measuringScrollbars = true
    @forceUpdate()

    # Finally, we restore the scrollbars based on the newly-measured dimensions
    # if the editor's content and dimensions require them to be visible.
    @forceUpdate()

  clearMouseWheelScreenRow: ->
    if @mouseWheelScreenRow?
      @mouseWheelScreenRow = null
      @requestUpdate()

  clearMouseWheelScreenRowAfterDelay: null # created lazily

  consolidateSelections: (e) ->
    e.abortKeyBinding() unless @props.editor.consolidateSelections()

  lineNodeForScreenRow: (screenRow) -> @refs.lines.lineNodeForScreenRow(screenRow)

  lineNumberNodeForScreenRow: (screenRow) -> @refs.gutter.lineNumberNodeForScreenRow(screenRow)

  screenRowForNode: (node) ->
    while node isnt document
      if screenRow = node.dataset.screenRow
        return parseInt(screenRow)
      node = node.parentNode
    null

  hide: ->
    @setState(visible: false)

  show: ->
    @setState(visible: true)

  getFontSize: ->
    @state.fontSize

  setFontSize: (fontSize) ->
    @setState({fontSize})

  getFontFamily: ->
    @state.fontFamily

  setFontFamily: (fontFamily) ->
    @setState({fontFamily})

  setLineHeight: (lineHeight) ->
    @setState({lineHeight})

  setShowIndentGuide: (showIndentGuide) ->
    @setState({showIndentGuide})

  # Public: Defines which characters are invisible.
  #
  # invisibles - An {Object} defining the invisible characters:
  #   :eol   - The end of line invisible {String} (default: `\u00ac`).
  #   :space - The space invisible {String} (default: `\u00b7`).
  #   :tab   - The tab invisible {String} (default: `\u00bb`).
  #   :cr    - The carriage return invisible {String} (default: `\u00a4`).
  setInvisibles: (invisibles={}) ->
    defaults invisibles,
      eol: '\u00ac'
      space: '\u00b7'
      tab: '\u00bb'
      cr: '\u00a4'

    @setState({invisibles})

  setShowInvisibles: (showInvisibles) ->
    @setState({showInvisibles})

  setShowLineNumbers: (showLineNumbers) ->
    @setState({showLineNumbers})

  setScrollSensitivity: (scrollSensitivity) ->
    if scrollSensitivity = parseInt(scrollSensitivity)
      @scrollSensitivity = Math.abs(scrollSensitivity) / 100

  setUseHardwareAcceleration: (useHardwareAcceleration=true) ->
    unless @useHardwareAcceleration is useHardwareAcceleration
      @useHardwareAcceleration = useHardwareAcceleration
      @requestUpdate()

  screenPositionForMouseEvent: (event) ->
    pixelPosition = @pixelPositionForMouseEvent(event)
    @props.editor.screenPositionForPixelPosition(pixelPosition)

  pixelPositionForMouseEvent: (event) ->
    {editor} = @props
    {clientX, clientY} = event

    linesClientRect = @refs.lines.getDOMNode().getBoundingClientRect()
    top = clientY - linesClientRect.top
    left = clientX - linesClientRect.left
    {top, left}

  getModel: ->
    @props.editor

  isInputEnabled: -> @inputEnabled

  setInputEnabled: (@inputEnabled) -> @inputEnabled

  updateParentViewFocusedClassIfNeeded: (prevState) ->
    if prevState.focused isnt @state.focused
      @props.parentView.toggleClass('is-focused', @props.focused)

  updateParentViewMiniClassIfNeeded: (prevProps) ->
    if prevProps.mini isnt @props.mini
      @props.parentView.toggleClass('mini', @props.mini)

  runScrollBenchmark: ->
    unless process.env.NODE_ENV is 'production'
      ReactPerf = require 'react-atom-fork/lib/ReactDefaultPerf'
      ReactPerf.start()

    node = @getDOMNode()

    scroll = (delta, done) ->
      dispatchMouseWheelEvent = ->
        node.dispatchEvent(new WheelEvent('mousewheel', wheelDeltaX: -0, wheelDeltaY: -delta))

      stopScrolling = ->
        clearInterval(interval)
        done?()

      interval = setInterval(dispatchMouseWheelEvent, 10)
      setTimeout(stopScrolling, 500)

    console.timeline('scroll')
    scroll 50, ->
      scroll 100, ->
        scroll 200, ->
          scroll 400, ->
            scroll 800, ->
              scroll 1600, ->
                console.timelineEnd('scroll')
                unless process.env.NODE_ENV is 'production'
                  ReactPerf.stop()
                  console.log "Inclusive"
                  ReactPerf.printInclusive()
                  console.log "Exclusive"
                  ReactPerf.printExclusive()
                  console.log "Wasted"
                  ReactPerf.printWasted()
