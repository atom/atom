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

module.exports =
EditorComponent = React.createClass
  displayName: 'EditorComponent'
  mixins: [SubscriberMixin]

  pendingScrollTop: null
  pendingScrollLeft: null
  selectOnMouseMove: false
  batchingUpdates: false
  updateRequested: false
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
  scrollViewMeasurementRequested: false
  overflowChangedEventsPaused: false
  overflowChangedWhilePaused: false
  measureLineHeightAndDefaultCharWidthWhenShown: false

  render: ->
    {focused, fontSize, lineHeight, fontFamily, showIndentGuide, showInvisibles, visible} = @state
    {editor, cursorBlinkPeriod, cursorBlinkResumeDelay} = @props
    maxLineNumberDigits = editor.getScreenLineCount().toString().length
    invisibles = if showInvisibles then @state.invisibles else {}

    if @isMounted()
      renderedRowRange = @getRenderedRowRange()
      [renderedStartRow, renderedEndRow] = renderedRowRange
      cursorScreenRanges = @getCursorScreenRanges(renderedRowRange)
      selectionScreenRanges = @getSelectionScreenRanges(renderedRowRange)
      scrollHeight = editor.getScrollHeight()
      scrollWidth = editor.getScrollWidth()
      scrollTop = editor.getScrollTop()
      scrollLeft = editor.getScrollLeft()
      lineHeightInPixels = editor.getLineHeightInPixels()
      defaultCharWidth = editor.getDefaultCharWidth()
      scrollViewHeight = editor.getHeight()
      horizontalScrollbarHeight = editor.getHorizontalScrollbarHeight()
      verticalScrollbarWidth = editor.getVerticalScrollbarWidth()
      verticallyScrollable = editor.verticallyScrollable()
      horizontallyScrollable = editor.horizontallyScrollable()
      hiddenInputStyle = @getHiddenInputPosition()
      hiddenInputStyle.WebkitTransform = 'translateZ(0)'
      if @mouseWheelScreenRow? and not (renderedStartRow <= @mouseWheelScreenRow < renderedEndRow)
        mouseWheelScreenRow = @mouseWheelScreenRow

    className = 'editor editor-colors react'
    className += ' is-focused' if focused

    div className: className, style: {fontSize, lineHeight, fontFamily}, tabIndex: -1,
      GutterComponent {
        ref: 'gutter', editor, renderedRowRange, maxLineNumberDigits, scrollTop,
        scrollHeight, lineHeightInPixels, @pendingChanges, mouseWheelScreenRow
      }

      div ref: 'scrollView', className: 'scroll-view', onMouseDown: @onMouseDown,
        InputComponent
          ref: 'input'
          className: 'hidden-input'
          style: hiddenInputStyle
          onInput: @onInput
          onFocus: @onInputFocused
          onBlur: @onInputBlurred

        CursorsComponent {
          editor, scrollTop, scrollLeft, cursorScreenRanges, cursorBlinkPeriod, cursorBlinkResumeDelay,
          lineHeightInPixels, defaultCharWidth
        }
        LinesComponent {
          ref: 'lines', editor, lineHeightInPixels, defaultCharWidth,
          showIndentGuide, renderedRowRange, @pendingChanges, scrollTop, scrollLeft, @scrollingVertically,
          selectionScreenRanges, scrollHeight, scrollWidth, mouseWheelScreenRow, invisibles,
          visible, scrollViewHeight
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

  componentDidMount: ->
    {editor} = @props

    @observeEditor()
    @listenForDOMEvents()
    @listenForCommands()

    @subscribe atom.themes, 'stylesheet-added stylsheet-removed', @onStylesheetsChanged
    @subscribe scrollbarStyle.changes, @refreshScrollbars

    editor.setVisible(true)

    editor.batchUpdates =>
      @measureLineHeightAndDefaultCharWidth()
      @measureScrollView()
      @measureScrollbars()

  componentWillUnmount: ->
    @unsubscribe()
    window.removeEventListener('resize', @onWindowResize)

  componentWillUpdate: ->
    @props.parentView.trigger 'cursor:moved' if @cursorsMoved

  componentDidUpdate: (prevProps, prevState) ->
    @pendingChanges.length = 0
    @refreshingScrollbars = false
    @measureScrollbars() if @measuringScrollbars
    @measureLineHeightAndCharWidthsIfNeeded(prevState)
    @pauseOverflowChangedEvents()
    @props.parentView.trigger 'editor:display-updated'

  requestUpdate: ->
    if @batchingUpdates
      @updateRequested = true
    else
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

  getSelectionScreenRanges: (renderedRowRange) ->
    {editor} = @props
    [renderedStartRow, renderedEndRow] = renderedRowRange

    selectionScreenRanges = {}
    for selection, index in editor.getSelections()
      screenRange = selection.getScreenRange()

      if not screenRange.isEmpty() and screenRange.intersectsRowRange(renderedStartRow, renderedEndRow)
        selectionScreenRanges[selection.id] = screenRange

      else if index is 0 # Rendering artifacts occur on the lines GPU layer if we remove the last selection
        selectionScreenRanges[selection.id] = new Range(new Point(renderedStartRow, 0), new Point(renderedStartRow, 0))

    selectionScreenRanges

  observeEditor: ->
    {editor} = @props
    @subscribe editor, 'batched-updates-started', @onBatchedUpdatesStarted
    @subscribe editor, 'batched-updates-ended', @onBatchedUpdatesEnded
    @subscribe editor, 'screen-lines-changed', @onScreenLinesChanged
    @subscribe editor, 'cursors-moved', @onCursorsMoved
    @subscribe editor, 'selection-removed selection-screen-range-changed', @onSelectionChanged
    @subscribe editor, 'selection-added', @onSelectionAdded
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

    scrollViewNode = @refs.scrollView.getDOMNode()
    scrollViewNode.addEventListener 'overflowchanged', @onScrollViewOverflowChanged
    scrollViewNode.addEventListener 'scroll', @onScrollViewScroll
    window.addEventListener('resize', @onWindowResize)

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
        'core:select-up': => editor.selectUp()
        'core:select-down': => editor.selectDown()
        'core:select-to-top': => editor.selectToTop()
        'core:select-to-bottom': => editor.selectToBottom()
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
        'editor:fold-selection': => neditor.foldSelectedLines()
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
        'core:page-up': => editor.pageUp()
        'core:page-down': => editor.pageDown()
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

  onFocus: ->
    @refs.input.focus()

  onInputFocused: ->
    @setState(focused: true)

  onInputBlurred: ->
    @setState(focused: false)

  onVerticalScroll: (scrollTop) ->
    {editor} = @props

    return if scrollTop is editor.getScrollTop()

    animationFramePending = @pendingScrollTop?
    @pendingScrollTop = scrollTop
    unless animationFramePending
      requestAnimationFrame =>
        @props.editor.setScrollTop(@pendingScrollTop)
        @pendingScrollTop = null

  onHorizontalScroll: (scrollLeft) ->
    {editor} = @props

    return if scrollLeft is editor.getScrollLeft()

    animationFramePending = @pendingScrollLeft?
    @pendingScrollLeft = scrollLeft
    unless animationFramePending
      requestAnimationFrame =>
        @props.editor.setScrollLeft(@pendingScrollLeft)
        @pendingScrollLeft = null

  onMouseWheel: (event) ->
    event.preventDefault()
    animationFramePending = @pendingHorizontalScrollDelta isnt 0 or @pendingVerticalScrollDelta isnt 0

    # Only scroll in one direction at a time
    {wheelDeltaX, wheelDeltaY} = event
    if Math.abs(wheelDeltaX) > Math.abs(wheelDeltaY)
      # Scrolling horizontally
      @pendingHorizontalScrollDelta -= wheelDeltaX
    else
      # Scrolling vertically
      @pendingVerticalScrollDelta -= wheelDeltaY
      @mouseWheelScreenRow = @screenRowForNode(event.target)
      @clearMouseWheelScreenRowAfterDelay ?= debounce(@clearMouseWheelScreenRow, @mouseWheelScreenRowClearDelay)
      @clearMouseWheelScreenRowAfterDelay()

    unless animationFramePending
      requestAnimationFrame =>
        {editor} = @props
        editor.setScrollTop(editor.getScrollTop() + @pendingVerticalScrollDelta)
        editor.setScrollLeft(editor.getScrollLeft() + @pendingHorizontalScrollDelta)
        @pendingVerticalScrollDelta = 0
        @pendingHorizontalScrollDelta = 0

  onScrollViewOverflowChanged: ->
    if @overflowChangedEventsPaused
      @overflowChangedWhilePaused = true
    else
      @requestScrollViewMeasurement()

  onWindowResize: ->
    @requestScrollViewMeasurement()

  onScrollViewScroll: ->
    console.warn "EditorScrollView scroll position changed, and it shouldn't have. If you can reproduce this, please report it."
    scrollViewNode = @refs.scrollView.getDOMNode()
    scrollViewNode.scrollTop = 0
    scrollViewNode.scrollLeft = 0

  onInput: (char, replaceLastCharacter) ->
    {editor} = @props

    if replaceLastCharacter
      editor.transact ->
        editor.selectLeft()
        editor.insertText(char)
    else
      editor.insertText(char)

  onMouseDown: (event) ->
    {editor} = @props
    {detail, shiftKey, metaKey} = event
    screenPosition = @screenPositionForMouseEvent(event)

    if shiftKey
      editor.selectToScreenPosition(screenPosition)
    else if metaKey
      editor.addCursorAtScreenPosition(screenPosition)
    else
      editor.setCursorScreenPosition(screenPosition)
      switch detail
        when 2 then editor.selectWord()
        when 3 then editor.selectLine()

    @selectToMousePositionUntilMouseUp(event)

  onStylesheetsChanged: (stylesheet) ->
    @refreshScrollbars() if @containsScrollbarSelector(stylesheet)

  onBatchedUpdatesStarted: ->
    @batchingUpdates = true

  onBatchedUpdatesEnded: ->
    updateRequested = @updateRequested
    @updateRequested = false
    @batchingUpdates = false
    if updateRequested
      @requestUpdate()

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
    @onStoppedScrollingAfterDelay ?= debounce(@onStoppedScrolling, 100)
    @onStoppedScrollingAfterDelay()

  onStoppedScrolling: ->
    @scrollingVertically = false
    @mouseWheelScreenRow = null
    @requestUpdate()

  onStoppedScrollingAfterDelay: null # created lazily

  onCursorsMoved: ->
    @cursorsMoved = true

  selectToMousePositionUntilMouseUp: (event) ->
    {editor} = @props
    dragging = false
    lastMousePosition = {}

    animationLoop = =>
      requestAnimationFrame =>
        if dragging
          @selectToMousePosition(lastMousePosition)
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

  selectToMousePosition: (event) ->
    @props.editor.selectToScreenPosition(@screenPositionForMouseEvent(event))

  requestScrollViewMeasurement: ->
    return if @measurementPending

    @scrollViewMeasurementRequested = true
    requestAnimationFrame =>
      @scrollViewMeasurementRequested = false
      @measureScrollView()

  # Measure explicitly-styled height and width and relay them to the model. If
  # these values aren't explicitly styled, we assume the editor is unconstrained
  # and use the scrollHeight / scrollWidth as its height and width in
  # calculations.
  measureScrollView: ->
    return unless @isMounted()

    {editor} = @props
    editorNode = @getDOMNode()
    scrollViewNode = @refs.scrollView.getDOMNode()
    {position} = getComputedStyle(editorNode)
    {width, height} = editorNode.style

    if position is 'absolute' or height
      clientHeight =  scrollViewNode.clientHeight
      editor.setHeight(clientHeight) if clientHeight > 0

    if position is 'absolute' or width
      clientWidth = scrollViewNode.clientWidth
      editor.setWidth(clientWidth) if clientWidth > 0

  measureLineHeightAndCharWidthsIfNeeded: (prevState) ->
    if not isEqualForProperties(prevState, @state, 'lineHeight', 'fontSize', 'fontFamily')
      {editor} = @props

      editor.batchUpdates =>
        oldDefaultCharWidth = editor.getDefaultCharWidth()

        if @state.visible
          @measureLineHeightAndDefaultCharWidth()
        else
          @measureLineHeightAndDefaultCharWidthWhenShown = true

        unless oldDefaultCharWidth is editor.getDefaultCharWidth()
          @remeasureCharacterWidths()
          @measureGutter()

    else if @measureLineHeightAndDefaultCharWidthWhenShown and @state.visible and not prevState.visible
      @measureLineHeightAndDefaultCharWidth()

  measureLineHeightAndDefaultCharWidth: ->
    @measureLineHeightAndDefaultCharWidthWhenShown = false
    @refs.lines.measureLineHeightAndDefaultCharWidth()

  remeasureCharacterWidths: ->
    @refs.lines.remeasureCharacterWidths()

  measureGutter: ->
    oldGutterWidth = @gutterWidth
    @gutterWidth = @refs.gutter.getDOMNode().offsetWidth
    @requestUpdate() if @gutterWidth isnt oldGutterWidth

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
    @requestUpdate()

    # Next, we display only the scrollbar corner so we can measure the new
    # scrollbar dimensions. The ::measuringScrollbars property will be set back
    # to false after the scrollbars are measured.
    @measuringScrollbars = true
    @requestUpdate()

    # Finally, we restore the scrollbars based on the newly-measured dimensions
    # if the editor's content and dimensions require them to be visible.
    @requestUpdate()

  pauseOverflowChangedEvents: ->
    @overflowChangedEventsPaused = true
    @resumeOverflowChangedEventsAfterDelay ?= debounce(@resumeOverflowChangedEvents, 500)
    @resumeOverflowChangedEventsAfterDelay()

  resumeOverflowChangedEvents: ->
    if @overflowChangedWhilePaused
      @overflowChangedWhilePaused = false
      @requestScrollViewMeasurement()

  resumeOverflowChangedEventsAfterDelay: null

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

  setFontSize: (fontSize) ->
    @setState({fontSize})

  setLineHeight: (lineHeight) ->
    @setState({lineHeight})

  setFontFamily: (fontFamily) ->
    @setState({fontFamily})

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

  screenPositionForMouseEvent: (event) ->
    pixelPosition = @pixelPositionForMouseEvent(event)
    @props.editor.screenPositionForPixelPosition(pixelPosition)

  pixelPositionForMouseEvent: (event) ->
    {editor} = @props
    {clientX, clientY} = event

    scrollViewClientRect = @refs.scrollView.getDOMNode().getBoundingClientRect()
    top = clientY - scrollViewClientRect.top + editor.getScrollTop()
    left = clientX - scrollViewClientRect.left + editor.getScrollLeft()
    {top, left}
