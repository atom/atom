React = require 'react-atom-fork'
{div, span} = require 'reactionary-atom-fork'
{debounce, defaults} = require 'underscore-plus'
scrollbarStyle = require 'scrollbar-style'

GutterComponent = require './gutter-component'
EditorScrollViewComponent = require './editor-scroll-view-component'
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

  render: ->
    {focused, fontSize, lineHeight, fontFamily, showIndentGuide, showInvisibles, visible} = @state
    {editor, cursorBlinkPeriod, cursorBlinkResumeDelay} = @props
    maxLineNumberDigits = editor.getScreenLineCount().toString().length
    invisibles = if showInvisibles then @state.invisibles else {}

    if @isMounted()
      renderedRowRange = @getRenderedRowRange()
      scrollHeight = editor.getScrollHeight()
      scrollWidth = editor.getScrollWidth()
      scrollTop = editor.getScrollTop()
      scrollLeft = editor.getScrollLeft()
      lineHeightInPixels = editor.getLineHeightInPixels()
      scrollViewHeight = editor.getHeight()
      horizontalScrollbarHeight = editor.getHorizontalScrollbarHeight()
      verticalScrollbarWidth = editor.getVerticalScrollbarWidth()
      verticallyScrollable = editor.verticallyScrollable()
      horizontallyScrollable = editor.horizontallyScrollable()

    className = 'editor editor-colors react'
    className += ' is-focused' if focused

    div className: className, style: {fontSize, lineHeight, fontFamily}, tabIndex: -1,
      GutterComponent {
        ref: 'gutter', editor, renderedRowRange, maxLineNumberDigits,
        scrollTop, scrollHeight, lineHeight, lineHeightInPixels, fontSize, fontFamily,
        @pendingChanges, onWidthChanged: @onGutterWidthChanged, @mouseWheelScreenRow
      }

      EditorScrollViewComponent {
        ref: 'scrollView', editor, fontSize, fontFamily, showIndentGuide,
        lineHeight, lineHeightInPixels, renderedRowRange, @pendingChanges,
        scrollTop, scrollLeft, scrollHeight, scrollWidth, @scrollingVertically,
        @cursorsMoved, @selectionChanged, @selectionAdded, cursorBlinkPeriod,
        cursorBlinkResumeDelay, @onInputFocused, @onInputBlurred, @mouseWheelScreenRow,
        invisibles, visible, scrollViewHeight
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

  getRenderedRowRange: ->
    {editor, lineOverdrawMargin} = @props
    [visibleStartRow, visibleEndRow] = editor.getVisibleRowRange()
    renderedStartRow = Math.max(0, visibleStartRow - lineOverdrawMargin)
    renderedEndRow = Math.min(editor.getScreenLineCount(), visibleEndRow + lineOverdrawMargin)
    [renderedStartRow, renderedEndRow]

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
    @observeEditor()
    @listenForDOMEvents()
    @listenForCommands()
    @measureScrollbars()
    @subscribe atom.themes, 'stylesheet-added stylsheet-removed', @onStylesheetsChanged
    @subscribe scrollbarStyle.changes, @refreshScrollbars
    @props.editor.setVisible(true)
    @requestUpdate()

  componentWillUnmount: ->
    @unsubscribe()
    @getDOMNode().removeEventListener 'mousewheel', @onMouseWheel

  componentWillUpdate: ->
    @props.parentView.trigger 'cursor:moved' if @cursorsMoved

  componentDidUpdate: ->
    @pendingChanges.length = 0
    @cursorsMoved = false
    @selectionChanged = false
    @selectionAdded = false
    @refreshingScrollbars = false
    @measureScrollbars() if @measuringScrollbars
    @props.parentView.trigger 'editor:display-updated'

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

  measureScrollbars: ->
    @measuringScrollbars = false

    {editor} = @props
    scrollbarCornerNode = @refs.scrollbarCorner.getDOMNode()
    width = (scrollbarCornerNode.offsetWidth - scrollbarCornerNode.clientWidth) or 15
    height = (scrollbarCornerNode.offsetHeight - scrollbarCornerNode.clientHeight) or 15
    editor.setVerticalScrollbarWidth(width)
    editor.setHorizontalScrollbarHeight(height)

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

  onFocus: ->
    @refs.scrollView.focus()

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
    screenRow = @screenRowForNode(event.target)
    @mouseWheelScreenRow = screenRow if screenRow?
    animationFramePending = @pendingHorizontalScrollDelta isnt 0 or @pendingVerticalScrollDelta isnt 0

    # Only scroll in one direction at a time
    {wheelDeltaX, wheelDeltaY} = event
    if Math.abs(wheelDeltaX) > Math.abs(wheelDeltaY)
      @pendingHorizontalScrollDelta -= wheelDeltaX
    else
      @pendingVerticalScrollDelta -= wheelDeltaY

    unless animationFramePending
      requestAnimationFrame =>
        {editor} = @props
        editor.setScrollTop(editor.getScrollTop() + @pendingVerticalScrollDelta)
        editor.setScrollLeft(editor.getScrollLeft() + @pendingHorizontalScrollDelta)
        @pendingVerticalScrollDelta = 0
        @pendingHorizontalScrollDelta = 0

  screenRowForNode: (node) ->
    while node isnt document
      if screenRow = node.dataset.screenRow
        return parseInt(screenRow)
      node = node.parentNode
    null

  onStylesheetsChanged: (stylesheet) ->
    @refreshScrollbars() if @containsScrollbarSelector(stylesheet)

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
    @stopScrollingAfterDelay ?= debounce(@onStoppedScrolling, 100)
    @stopScrollingAfterDelay()

  onStoppedScrolling: ->
    @scrollingVertically = false
    @mouseWheelScreenRow = null
    @requestUpdate()

  stopScrollingAfterDelay: null # created lazily

  onCursorsMoved: ->
    @cursorsMoved = true

  onGutterWidthChanged: (@gutterWidth) ->
    @requestUpdate()

  requestUpdate: ->
    if @batchingUpdates
      @updateRequested = true
    else
      @forceUpdate()

  measureHeightAndWidth: ->
    @refs.scrollView.measureHeightAndWidth()

  consolidateSelections: (e) ->
    e.abortKeyBinding() unless @props.editor.consolidateSelections()

  lineNodeForScreenRow: (screenRow) -> @refs.scrollView.lineNodeForScreenRow(screenRow)

  lineNumberNodeForScreenRow: (screenRow) -> @refs.gutter.lineNumberNodeForScreenRow(screenRow)

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
