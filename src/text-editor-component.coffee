_ = require 'underscore-plus'
React = require 'react-atom-fork'
{div, span} = require 'reactionary-atom-fork'
{debounce, defaults, isEqualForProperties} = require 'underscore-plus'
scrollbarStyle = require 'scrollbar-style'
{Range, Point} = require 'text-buffer'
grim = require 'grim'
{CompositeDisposable} = require 'event-kit'

GutterComponent = require './gutter-component'
InputComponent = require './input-component'
LinesComponent = require './lines-component'
ScrollbarComponent = require './scrollbar-component'
ScrollbarCornerComponent = require './scrollbar-corner-component'
SubscriberMixin = require './subscriber-mixin'

module.exports =
TextEditorComponent = React.createClass
  displayName: 'TextEditorComponent'
  mixins: [SubscriberMixin]

  statics:
    performSyncUpdates: false

  visible: false
  autoHeight: false
  backgroundColor: null
  gutterBackgroundColor: null
  pendingScrollTop: null
  pendingScrollLeft: null
  selectOnMouseMove: false
  updateRequested: false
  updatesPaused: false
  updateRequestedWhilePaused: false
  cursorMoved: false
  selectionChanged: false
  scrollingVertically: false
  mouseWheelScreenRow: null
  mouseWheelScreenRowClearDelay: 150
  scrollSensitivity: 0.4
  heightAndWidthMeasurementRequested: false
  inputEnabled: true
  scopedCharacterWidthsChangeCount: null
  domPollingInterval: 100
  domPollingIntervalId: null
  domPollingPaused: false
  measureScrollbarsWhenShown: true
  measureLineHeightAndDefaultCharWidthWhenShown: true
  remeasureCharacterWidthsWhenShown: false

  render: ->
    {focused, showIndentGuide, showLineNumbers, visible} = @state
    {editor, mini, cursorBlinkPeriod, cursorBlinkResumeDelay} = @props
    maxLineNumberDigits = editor.getLineCount().toString().length
    hasSelection = editor.getLastSelection()? and !editor.getLastSelection().isEmpty()
    style = {}

    if @performedInitialMeasurement
      renderedRowRange = @getRenderedRowRange()
      [renderedStartRow, renderedEndRow] = renderedRowRange
      cursorPixelRects = @getCursorPixelRects(renderedRowRange)

      tokenizedLines = editor.tokenizedLinesForScreenRows(renderedStartRow, renderedEndRow - 1)

      decorations = editor.decorationsForScreenRowRange(renderedStartRow, renderedEndRow)
      highlightDecorations = @getHighlightDecorations(decorations)
      lineDecorations = @getLineDecorations(decorations)
      placeholderText = editor.getPlaceholderText() if editor.isEmpty()
      visible = @isVisible()

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

    className = 'editor-contents'
    className += ' is-focused' if focused
    className += ' has-selection' if hasSelection

    div {className, style, tabIndex: -1},
      if @shouldRenderGutter()
        GutterComponent {
          ref: 'gutter', onMouseDown: @onGutterMouseDown, lineDecorations,
          defaultCharWidth, editor, renderedRowRange, maxLineNumberDigits, scrollViewHeight,
          scrollTop, scrollHeight, lineHeightInPixels, @pendingChanges, mouseWheelScreenRow,
          @useHardwareAcceleration, @performedInitialMeasurement, @backgroundColor, @gutterBackgroundColor
        }

      div ref: 'scrollView', className: 'scroll-view', onMouseDown: @onMouseDown,
        InputComponent
          ref: 'input'
          className: 'hidden-input'
          style: hiddenInputStyle
          onFocus: @onInputFocused
          onBlur: @onInputBlurred

        LinesComponent {
          ref: 'lines',
          editor, lineHeightInPixels, defaultCharWidth, tokenizedLines, lineDecorations, highlightDecorations,
          showIndentGuide, renderedRowRange, @pendingChanges, scrollTop, scrollLeft,
          @scrollingVertically, scrollHeight, scrollWidth, mouseWheelScreenRow,
          visible, scrollViewHeight, @scopedCharacterWidthsChangeCount, lineWidth, @useHardwareAcceleration,
          placeholderText, @performedInitialMeasurement, @backgroundColor, cursorPixelRects,
          cursorBlinkPeriod, cursorBlinkResumeDelay, mini
        }

        ScrollbarComponent
          ref: 'horizontalScrollbar'
          className: 'horizontal-scrollbar'
          orientation: 'horizontal'
          onScroll: @onHorizontalScroll
          scrollLeft: scrollLeft
          scrollWidth: scrollWidth
          visible: horizontallyScrollable
          scrollableInOppositeDirection: verticallyScrollable
          verticalScrollbarWidth: verticalScrollbarWidth
          horizontalScrollbarHeight: horizontalScrollbarHeight
          useHardwareAcceleration: @useHardwareAcceleration

      ScrollbarComponent
        ref: 'verticalScrollbar'
        className: 'vertical-scrollbar'
        orientation: 'vertical'
        onScroll: @onVerticalScroll
        scrollTop: scrollTop
        scrollHeight: scrollHeight
        visible: verticallyScrollable
        scrollableInOppositeDirection: horizontallyScrollable
        verticalScrollbarWidth: verticalScrollbarWidth
        horizontalScrollbarHeight: horizontalScrollbarHeight
        useHardwareAcceleration: @useHardwareAcceleration

      # Also used to measure the height/width of scrollbars after the initial render
      ScrollbarCornerComponent
        ref: 'scrollbarCorner'
        visible: horizontallyScrollable and verticallyScrollable
        measuringScrollbars: @measuringScrollbars
        height: horizontalScrollbarHeight
        width: verticalScrollbarWidth

  getPageRows: ->
    {editor} = @props
    Math.max(1, Math.ceil(editor.getHeight() / editor.getLineHeightInPixels()))

  shouldRenderGutter: ->
    not @props.mini and @state.showLineNumbers

  getInitialState: -> {}

  getDefaultProps: ->
    cursorBlinkPeriod: 800
    cursorBlinkResumeDelay: 100
    lineOverdrawMargin: 15

  componentWillMount: ->
    @pendingChanges = []
    @props.editor.manageScrollPosition = true
    @observeConfig()
    @setScrollSensitivity(atom.config.get('editor.scrollSensitivity'))

  componentDidMount: ->
    {editor} = @props

    @observeEditor()
    @listenForDOMEvents()

    @subscribe atom.themes.onDidAddStylesheet @onStylesheetsChanged
    @subscribe atom.themes.onDidUpdateStylesheet @onStylesheetsChanged
    @subscribe atom.themes.onDidRemoveStylesheet @onStylesheetsChanged
    unless atom.themes.isInitialLoadComplete()
      @subscribe atom.themes.onDidReloadAll @onStylesheetsChanged
    @subscribe scrollbarStyle.changes, @refreshScrollbars

    @domPollingIntervalId = setInterval(@pollDOM, @domPollingInterval)
    @updateParentViewFocusedClassIfNeeded({})
    @updateParentViewMiniClassIfNeeded({})
    @checkForVisibilityChange()

  componentWillUnmount: ->
    {editor, parentView} = @props

    parentView.__spacePenView.trigger 'editor:will-be-removed', [parentView.__spacePenView]
    @unsubscribe()
    window.removeEventListener 'resize', @requestHeightAndWidthMeasurement
    clearInterval(@domPollingIntervalId)
    @domPollingIntervalId = null

  componentWillReceiveProps: (newProps) ->
    @props.editor.setMini(newProps.mini)

  componentDidUpdate: (prevProps, prevState) ->
    cursorMoved = @cursorMoved
    selectionChanged = @selectionChanged
    @pendingChanges.length = 0
    @cursorMoved = false
    @selectionChanged = false

    if @props.editor.isAlive()
      @updateParentViewFocusedClassIfNeeded(prevState)
      @updateParentViewMiniClassIfNeeded(prevState)
      @props.parentView.__spacePenView.trigger 'cursor:moved' if cursorMoved
      @props.parentView.__spacePenView.trigger 'selection:changed' if selectionChanged
      @props.parentView.__spacePenView.trigger 'editor:display-updated'

  becameVisible: ->
    @updatesPaused = true
    @sampleFontStyling()
    @sampleBackgroundColors()
    @measureHeightAndWidth()
    @measureScrollbars() if @measureScrollbarsWhenShown
    @measureLineHeightAndDefaultCharWidth() if @measureLineHeightAndDefaultCharWidthWhenShown
    @remeasureCharacterWidths() if @remeasureCharacterWidthsWhenShown
    @props.editor.setVisible(true)
    @performedInitialMeasurement = true
    @updatesPaused = false
    @forceUpdate() if @updateRequestedWhilePaused

  requestUpdate: ->
    return unless @isMounted()

    if @updatesPaused
      @updateRequestedWhilePaused = true
      return

    if @performSyncUpdates ? TextEditorComponent.performSyncUpdates
      @forceUpdate()
    else unless @updateRequested
      @updateRequested = true
      requestAnimationFrame =>
        @updateRequested = false
        @forceUpdate() if @isMounted()

  requestAnimationFrame: (fn) ->
    @updatesPaused = true
    @pauseDOMPolling()
    requestAnimationFrame =>
      fn()
      @updatesPaused = false
      if @updateRequestedWhilePaused and @isMounted()
        @updateRequestedWhilePaused = false
        @forceUpdate()

  getTopmostDOMNode: ->
    @props.parentView

  getRenderedRowRange: ->
    {editor, lineOverdrawMargin} = @props
    [visibleStartRow, visibleEndRow] = editor.getVisibleRowRange()
    renderedStartRow = Math.max(0, visibleStartRow - lineOverdrawMargin)
    renderedEndRow = Math.min(editor.getScreenLineCount(), visibleEndRow + lineOverdrawMargin)
    [renderedStartRow, renderedEndRow]

  getHiddenInputPosition: ->
    {editor} = @props
    {focused} = @state
    return {top: 0, left: 0} unless @isMounted() and focused and editor.getLastCursor()?

    {top, left, height, width} = editor.getLastCursor().getPixelRect()
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
    {editor, mini} = @props
    return {} if mini

    decorationsByScreenRow = {}
    for markerId, decorations of decorationsByMarkerId
      marker = editor.getMarker(markerId)
      screenRange = null
      headScreenRow = null
      if marker.isValid()
        for decoration in decorations
          if decoration.isType('gutter') or decoration.isType('line')
            decorationParams = decoration.getProperties()
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
            decorationParams = decoration.getProperties()
            filteredDecorations[markerId] ?=
              id: markerId
              startPixelPosition: editor.pixelPositionForScreenPosition(screenRange.start)
              endPixelPosition: editor.pixelPositionForScreenPosition(screenRange.end)
              decorations: []
            filteredDecorations[markerId].decorations.push decorationParams

    filteredDecorations

  observeEditor: ->
    {editor} = @props
    @subscribe editor.onDidChange(@onScreenLinesChanged)
    @subscribe editor.observeGrammar(@onGrammarChanged)
    @subscribe editor.observeCursors(@onCursorAdded)
    @subscribe editor.observeSelections(@onSelectionAdded)
    @subscribe editor.observeDecorations(@onDecorationAdded)
    @subscribe editor.onDidRemoveDecoration(@onDecorationRemoved)
    @subscribe editor.onDidChangeCharacterWidths(@onCharacterWidthsChanged)
    @subscribe editor.onDidChangePlaceholderText(@onPlaceholderTextChanged)
    @subscribe editor.$scrollTop.changes, @onScrollTopChanged
    @subscribe editor.$scrollLeft.changes, @requestUpdate
    @subscribe editor.$verticalScrollbarWidth.changes, @requestUpdate
    @subscribe editor.$horizontalScrollbarHeight.changes, @requestUpdate
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
    window.addEventListener 'resize', @requestHeightAndWidthMeasurement

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

  observeConfig: ->
    @subscribe atom.config.observe 'editor.useHardwareAcceleration', @setUseHardwareAcceleration

  onGrammarChanged: ->
    {editor} = @props

    @scopedConfigSubscriptions?.dispose()
    @scopedConfigSubscriptions = subscriptions = new CompositeDisposable

    scopeDescriptor = editor.getRootScopeDescriptor()

    subscriptions.add atom.config.observe scopeDescriptor, 'editor.showIndentGuide', @setShowIndentGuide
    subscriptions.add atom.config.observe scopeDescriptor, 'editor.showLineNumbers', @setShowLineNumbers
    subscriptions.add atom.config.observe scopeDescriptor, 'editor.scrollSensitivity', @setScrollSensitivity

  onFocus: ->
    @refs.input.focus() if @isMounted()

  onTextInput: (event) ->
    event.stopPropagation()

    # If we prevent the insertion of a space character, then the browser
    # interprets the spacebar keypress as a page-down command.
    event.preventDefault() unless event.data is ' '

    return unless @isInputEnabled()

    {editor} = @props
    inputNode = event.target

    # Work around of the accented character suggestion feature in OS X.
    # Text input fires before a character is inserted, and if the browser is
    # replacing the previous un-accented character with an accented variant, it
    # will select backward over it.
    selectedLength = inputNode.selectionEnd - inputNode.selectionStart
    editor.selectLeft() if selectedLength is 1

    inputNode.value = event.data if editor.insertText(event.data)

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
    {editor} = @props

    # Only scroll in one direction at a time
    {wheelDeltaX, wheelDeltaY} = event

    # Ctrl+MouseWheel adjusts font size.
    if event.ctrlKey and atom.config.get('editor.zoomFontWhenCtrlScrolling')
      if wheelDeltaY > 0
        atom.workspace.increaseFontSize()
      else if wheelDeltaY < 0
        atom.workspace.decreaseFontSize()
      event.preventDefault()
      return

    if Math.abs(wheelDeltaX) > Math.abs(wheelDeltaY)
      # Scrolling horizontally
      previousScrollLeft = editor.getScrollLeft()
      editor.setScrollLeft(previousScrollLeft - Math.round(wheelDeltaX * @scrollSensitivity))
      event.preventDefault() unless previousScrollLeft is editor.getScrollLeft()
    else
      # Scrolling vertically
      @mouseWheelScreenRow = @screenRowForNode(event.target)
      @clearMouseWheelScreenRowAfterDelay ?= debounce(@clearMouseWheelScreenRow, @mouseWheelScreenRowClearDelay)
      @clearMouseWheelScreenRowAfterDelay()
      previousScrollTop = editor.getScrollTop()
      editor.setScrollTop(previousScrollTop - Math.round(wheelDeltaY * @scrollSensitivity))
      event.preventDefault() unless previousScrollTop is editor.getScrollTop()

  onScrollViewScroll: ->
    if @isMounted()
      console.warn "TextEditorScrollView scrolled when it shouldn't have."
      scrollViewNode = @refs.scrollView.getDOMNode()
      scrollViewNode.scrollTop = 0
      scrollViewNode.scrollLeft = 0

  onMouseDown: (event) ->
    return unless event.button is 0 # only handle the left mouse button
    return if event.target?.classList.contains('horizontal-scrollbar')

    {editor} = @props
    {detail, shiftKey, metaKey, ctrlKey} = event

    # CTRL+click brings up the context menu on OSX, so don't handle those either
    return if ctrlKey and process.platform is 'darwin'

    # Prevent focusout event on hidden input if editor is already focused
    event.preventDefault() if @state.focused

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

    {shiftKey, metaKey, ctrlKey} = event

    if shiftKey
      @onGutterShiftClick(event)
    else if metaKey or (ctrlKey and process.platform isnt 'darwin')
      @onGutterMetaClick(event)
    else
      @onGutterClick(event)

  onGutterClick: (event) ->
    {editor} = @props
    clickedRow = @screenPositionForMouseEvent(event).row

    editor.setSelectedScreenRange([[clickedRow, 0], [clickedRow + 1, 0]], preserveFolds: true)

    @handleDragUntilMouseUp event, (screenPosition) ->
      dragRow = screenPosition.row
      if dragRow < clickedRow # dragging up
        editor.setSelectedScreenRange([[dragRow, 0], [clickedRow + 1, 0]], preserveFolds: true)
      else
        editor.setSelectedScreenRange([[clickedRow, 0], [dragRow + 1, 0]], preserveFolds: true)

  onGutterMetaClick: (event) ->
    {editor} = @props
    clickedRow = @screenPositionForMouseEvent(event).row

    bufferRange = editor.bufferRangeForScreenRange([[clickedRow, 0], [clickedRow + 1, 0]])
    rowSelection = editor.addSelectionForBufferRange(bufferRange, preserveFolds: true)

    @handleDragUntilMouseUp event, (screenPosition) ->
      dragRow = screenPosition.row

      if dragRow < clickedRow # dragging up
        rowSelection.setScreenRange([[dragRow, 0], [clickedRow + 1, 0]], preserveFolds: true)
      else
        rowSelection.setScreenRange([[clickedRow, 0], [dragRow + 1, 0]], preserveFolds: true)

      # After updating the selected screen range, merge overlapping selections
      editor.mergeIntersectingSelections(preserveFolds: true)

      # The merge process will possibly destroy the current selection because
      # it will be merged into another one. Therefore, we need to obtain a
      # reference to the new selection that contains the originally selected row
      rowSelection = _.find editor.getSelections(), (selection) ->
        selection.intersectsBufferRange(bufferRange)

  onGutterShiftClick: (event) ->
    {editor} = @props
    clickedRow = @screenPositionForMouseEvent(event).row
    tailPosition = editor.getLastSelection().getTailScreenPosition()

    if clickedRow < tailPosition.row
      editor.selectToScreenPosition([clickedRow, 0])
    else
      editor.selectToScreenPosition([clickedRow + 1, 0])

    @handleDragUntilMouseUp event, (screenPosition) ->
      dragRow = screenPosition.row
      if dragRow < tailPosition.row # dragging up
        editor.setSelectedScreenRange([[dragRow, 0], tailPosition], preserveFolds: true)
      else
        editor.setSelectedScreenRange([tailPosition, [dragRow + 1, 0]], preserveFolds: true)

  onStylesheetsChanged: (stylesheet) ->
    return unless @performedInitialMeasurement
    return unless atom.themes.isInitialLoadComplete()

    @refreshScrollbars() if not stylesheet? or @containsScrollbarSelector(stylesheet)
    @sampleFontStyling()
    @sampleBackgroundColors()
    @remeasureCharacterWidths()

  onScreenLinesChanged: (change) ->
    {editor} = @props
    @pendingChanges.push(change)
    @requestUpdate() if editor.intersectsVisibleRowRange(change.start, change.end + 1) # TODO: Use closed-open intervals for change events

  onSelectionAdded: (selection) ->
    {editor} = @props

    @subscribe selection.onDidChangeRange => @onSelectionChanged(selection)
    @subscribe selection.onDidDestroy =>
      @onSelectionChanged(selection)
      @unsubscribe(selection)

    if editor.selectionIntersectsVisibleRowRange(selection)
      @selectionChanged = true
      @requestUpdate()

  onSelectionChanged: (selection) ->
    {editor} = @props
    if editor.selectionIntersectsVisibleRowRange(selection)
      @selectionChanged = true
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

  onCursorAdded: (cursor) ->
    @subscribe cursor.onDidChangePosition @onCursorMoved

  onCursorMoved: ->
    @cursorMoved = true
    @requestUpdate()

  onDecorationAdded: (decoration) ->
    @subscribe decoration.onDidChangeProperties(@onDecorationChanged)
    @subscribe decoration.getMarker().onDidChange(@onDecorationChanged)
    @requestUpdate()

  onDecorationChanged: ->
    @requestUpdate()

  onDecorationRemoved: ->
    @requestUpdate()

  onCharacterWidthsChanged: (@scopedCharacterWidthsChangeCount) ->
    @requestUpdate()

  onPlaceholderTextChanged: ->
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

  isVisible: ->
    node = @getDOMNode()
    node.offsetHeight > 0 or node.offsetWidth > 0

  pauseDOMPolling: ->
    @domPollingPaused = true
    @resumeDOMPollingAfterDelay ?= debounce(@resumeDOMPolling, 100)
    @resumeDOMPollingAfterDelay()

  resumeDOMPolling: ->
    @domPollingPaused = false

  resumeDOMPollingAfterDelay: null # created lazily

  pollDOM: ->
    return if @domPollingPaused or @updateRequested or not @isMounted()

    unless @checkForVisibilityChange()
      @sampleBackgroundColors()
      @measureHeightAndWidth()
      @sampleFontStyling()

  checkForVisibilityChange: ->
    if @isVisible()
      if @wasVisible
        false
      else
        @becameVisible()
        @wasVisible = true
    else
      @wasVisible = false

  requestHeightAndWidthMeasurement: ->
    return if @heightAndWidthMeasurementRequested

    @heightAndWidthMeasurementRequested = true
    requestAnimationFrame =>
      @heightAndWidthMeasurementRequested = false
      @measureHeightAndWidth()

  # Measure explicitly-styled height and width and relay them to the model. If
  # these values aren't explicitly styled, we assume the editor is unconstrained
  # and use the scrollHeight / scrollWidth as its height and width in
  # calculations.
  measureHeightAndWidth: ->
    return unless @isMounted()

    {editor, parentView} = @props
    scrollViewNode = @refs.scrollView.getDOMNode()
    {position} = getComputedStyle(parentView)
    {height} = parentView.style

    if position is 'absolute' or height
      if @autoHeight
        @autoHeight = false
        @forceUpdate() unless @updatesPaused

      clientHeight =  scrollViewNode.clientHeight
      editor.setHeight(clientHeight) if clientHeight > 0
    else
      editor.setHeight(null)
      @autoHeight = true

    clientWidth = scrollViewNode.clientWidth
    paddingLeft = parseInt(getComputedStyle(scrollViewNode).paddingLeft)
    clientWidth -= paddingLeft
    editor.setWidth(clientWidth) if clientWidth > 0

  sampleFontStyling: ->
    oldFontSize = @fontSize
    oldFontFamily = @fontFamily
    oldLineHeight = @lineHeight

    {@fontSize, @fontFamily, @lineHeight} = getComputedStyle(@getTopmostDOMNode())

    if @fontSize isnt oldFontSize or @fontFamily isnt oldFontFamily or @lineHeight isnt oldLineHeight
      @measureLineHeightAndDefaultCharWidth()

    if (@fontSize isnt oldFontSize or @fontFamily isnt oldFontFamily) and @performedInitialMeasurement
      @remeasureCharacterWidths()

  sampleBackgroundColors: (suppressUpdate) ->
    {parentView} = @props
    {showLineNumbers} = @state
    {backgroundColor} = getComputedStyle(parentView)

    if backgroundColor isnt @backgroundColor
      @backgroundColor = backgroundColor
      @requestUpdate() unless suppressUpdate

    if @shouldRenderGutter()
      gutterBackgroundColor = getComputedStyle(@refs.gutter.getDOMNode()).backgroundColor
      if gutterBackgroundColor isnt @gutterBackgroundColor
        @gutterBackgroundColor = gutterBackgroundColor
        @requestUpdate() unless suppressUpdate

  measureLineHeightAndDefaultCharWidth: ->
    if @isVisible()
      @measureLineHeightAndDefaultCharWidthWhenShown = false
      @refs.lines.measureLineHeightAndDefaultCharWidth()
    else
      @measureLineHeightAndDefaultCharWidthWhenShown = true

  remeasureCharacterWidths: ->
    if @isVisible()
      @remeasureCharacterWidthsWhenShown = false
      @refs.lines.remeasureCharacterWidths()
    else
      @remeasureCharacterWidthsWhenShown = true

  measureScrollbars: ->
    @measureScrollbarsWhenShown = false

    {editor} = @props
    cornerNode = @refs.scrollbarCorner.getDOMNode()
    originalDisplayValue = cornerNode.style.display

    cornerNode.style.display = 'block'

    width = (cornerNode.offsetWidth - cornerNode.clientWidth) or 15
    height = (cornerNode.offsetHeight - cornerNode.clientHeight) or 15

    editor.setVerticalScrollbarWidth(width)
    editor.setHorizontalScrollbarHeight(height)

    cornerNode.style.display = originalDisplayValue

  containsScrollbarSelector: (stylesheet) ->
    for rule in stylesheet.cssRules
      if rule.selectorText?.indexOf('scrollbar') > -1
        return true
    false

  refreshScrollbars: ->
    if @isVisible()
      @measureScrollbarsWhenShown = false
    else
      @measureScrollbarsWhenShown = true
      return

    {verticalScrollbar, horizontalScrollbar, scrollbarCorner} = @refs

    verticalNode = verticalScrollbar.getDOMNode()
    horizontalNode = horizontalScrollbar.getDOMNode()
    cornerNode = scrollbarCorner.getDOMNode()

    originalVerticalDisplayValue = verticalNode.style.display
    originalHorizontalDisplayValue = horizontalNode.style.display
    originalCornerDisplayValue = cornerNode.style.display

    # First, hide all scrollbars in case they are visible so they take on new
    # styles when they are shown again.
    verticalNode.style.display = 'none'
    horizontalNode.style.display = 'none'
    cornerNode.style.display = 'none'

    # Force a reflow
    cornerNode.offsetWidth

    # Now measure the new scrollbar dimensions
    @measureScrollbars()

    # Now restore the display value for all scrollbars, since they were
    # previously hidden
    verticalNode.style.display = originalVerticalDisplayValue
    horizontalNode.style.display = originalHorizontalDisplayValue
    cornerNode.style.display = originalCornerDisplayValue

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

  getFontSize: ->
    parseInt(getComputedStyle(@getTopmostDOMNode()).fontSize)

  setFontSize: (fontSize) ->
    @getTopmostDOMNode().style.fontSize = fontSize + 'px'
    @sampleFontStyling()

  getFontFamily: ->
    getComputedStyle(@getTopmostDOMNode()).fontFamily

  setFontFamily: (fontFamily) ->
    @getTopmostDOMNode().style.fontFamily = fontFamily
    @sampleFontStyling()

  setLineHeight: (lineHeight) ->
    @getTopmostDOMNode().style.lineHeight = lineHeight
    @sampleFontStyling()

  setShowIndentGuide: (showIndentGuide) ->
    @setState({showIndentGuide})

  # Deprecated
  setInvisibles: (invisibles={}) ->
    grim.deprecate "Use config.set('editor.invisibles', invisibles) instead"
    atom.config.set('editor.invisibles', invisibles)

  # Deprecated
  setShowInvisibles: (showInvisibles) ->
    atom.config.set('editor.showInvisibles', showInvisibles)

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
      @props.parentView.classList.toggle('is-focused', @state.focused)

  updateParentViewMiniClassIfNeeded: (prevProps) ->
    if prevProps.mini isnt @props.mini
      @props.parentView.classList.toggle('mini', @props.mini)

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
