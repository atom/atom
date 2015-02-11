_ = require 'underscore-plus'
React = require 'react-atom-fork'
{div, span} = require 'reactionary-atom-fork'
{debounce, defaults, isEqualForProperties} = require 'underscore-plus'
scrollbarStyle = require 'scrollbar-style'
{Range, Point} = require 'text-buffer'
grim = require 'grim'
{CompositeDisposable} = require 'event-kit'
ipc = require 'ipc'

TextEditorPresenter = require './text-editor-presenter'
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

  visible: false
  pendingScrollTop: null
  pendingScrollLeft: null
  selectOnMouseMove: false
  updateRequested: false
  updatesPaused: false
  updateRequestedWhilePaused: false
  cursorMoved: false
  selectionChanged: false
  scrollSensitivity: 0.4
  heightAndWidthMeasurementRequested: false
  inputEnabled: true
  domPollingInterval: 100
  domPollingIntervalId: null
  domPollingPaused: false
  measureScrollbarsWhenShown: true
  measureLineHeightAndDefaultCharWidthWhenShown: true
  remeasureCharacterWidthsWhenShown: false
  stylingChangeAnimationFrameRequested: false
  gutterComponent: null

  render: ->
    {focused, showLineNumbers} = @state
    {editor, cursorBlinkPeriod, cursorBlinkResumeDelay, hostElement, useShadowDOM} = @props
    hasSelection = editor.getLastSelection()? and !editor.getLastSelection().isEmpty()
    style = {}

    @performedInitialMeasurement = false if editor.isDestroyed()

    if @performedInitialMeasurement
      hiddenInputStyle = @getHiddenInputPosition()
      hiddenInputStyle.WebkitTransform = 'translateZ(0)'
      style.height = @presenter.state.height if @presenter.state.height?

    if useShadowDOM
      className = 'editor-contents--private'
    else
      className = 'editor-contents'
    className += ' is-focused' if focused
    className += ' has-selection' if hasSelection

    div {className, style},
      div ref: 'scrollView', className: 'scroll-view',
        InputComponent
          ref: 'input'
          className: 'hidden-input'
          style: hiddenInputStyle

        ScrollbarComponent
          ref: 'horizontalScrollbar'
          className: 'horizontal-scrollbar'
          orientation: 'horizontal'
          presenter: @presenter
          onScroll: @onHorizontalScroll

      ScrollbarComponent
        ref: 'verticalScrollbar'
        className: 'vertical-scrollbar'
        orientation: 'vertical'
        presenter: @presenter
        onScroll: @onVerticalScroll

      # Also used to measure the height/width of scrollbars after the initial render
      ScrollbarCornerComponent
        ref: 'scrollbarCorner'
        presenter: @presenter
        measuringScrollbars: @measuringScrollbars

  getInitialState: -> {}

  getDefaultProps: ->
    cursorBlinkPeriod: 800
    cursorBlinkResumeDelay: 100

  componentWillMount: ->
    @props.editor.manageScrollPosition = true
    @observeConfig()
    @setScrollSensitivity(atom.config.get('editor.scrollSensitivity'))

    {editor, lineOverdrawMargin, cursorBlinkPeriod, cursorBlinkResumeDelay}  = @props
    lineOverdrawMargin ?= 15

    @presenter = new TextEditorPresenter
      model: editor
      scrollTop: editor.getScrollTop()
      scrollLeft: editor.getScrollLeft()
      lineOverdrawMargin: lineOverdrawMargin
      cursorBlinkPeriod: cursorBlinkPeriod
      cursorBlinkResumeDelay: cursorBlinkResumeDelay
      stoppedScrollingDelay: 200
    @presenter.onDidUpdateState(@requestUpdate)

  componentDidMount: ->
    {editor, stylesElement, hostElement, useShadowDOM} = @props

    @mountGutterComponent() if @gutterVisible

    @linesComponent = new LinesComponent({@presenter, hostElement, useShadowDOM})
    scrollViewNode = @refs.scrollView.getDOMNode()
    horizontalScrollbarNode = @refs.horizontalScrollbar.getDOMNode()
    scrollViewNode.insertBefore(@linesComponent.domNode, horizontalScrollbarNode)
    @linesComponent.updateSync(@isVisible())

    @observeEditor()
    @listenForDOMEvents()

    @subscribe stylesElement.onDidAddStyleElement @onStylesheetsChanged
    @subscribe stylesElement.onDidUpdateStyleElement @onStylesheetsChanged
    @subscribe stylesElement.onDidRemoveStyleElement @onStylesheetsChanged
    unless atom.themes.isInitialLoadComplete()
      @subscribe atom.themes.onDidChangeActiveThemes @onAllThemesLoaded
    @subscribe scrollbarStyle.changes, @refreshScrollbars

    @domPollingIntervalId = setInterval(@pollDOM, @domPollingInterval)
    @updateParentViewFocusedClassIfNeeded({})
    @updateParentViewMiniClass()
    @checkForVisibilityChange()

  componentWillUnmount: ->
    {editor, hostElement} = @props

    @unsubscribe()
    @presenter.destroy()
    @scopedConfigSubscriptions.dispose()
    window.removeEventListener 'resize', @requestHeightAndWidthMeasurement
    clearInterval(@domPollingIntervalId)
    @domPollingIntervalId = null

  componentDidUpdate: (prevProps, prevState) ->
    cursorMoved = @cursorMoved
    selectionChanged = @selectionChanged
    @cursorMoved = false
    @selectionChanged = false

    if @gutterVisible
      @mountGutterComponent() unless @gutterComponent?
      @gutterComponent.updateSync()
    else
      @gutterComponent?.domNode?.remove()
      @gutterComponent = null

    @linesComponent.updateSync(@isVisible())

    if @props.editor.isAlive()
      @updateParentViewFocusedClassIfNeeded(prevState)
      @updateParentViewMiniClass()
      @props.hostElement.__spacePenView.trigger 'cursor:moved' if cursorMoved
      @props.hostElement.__spacePenView.trigger 'selection:changed' if selectionChanged
      @props.hostElement.__spacePenView.trigger 'editor:display-updated'

  mountGutterComponent: ->
    {editor} = @props
    @gutterComponent = new GutterComponent({@presenter, editor, onMouseDown: @onGutterMouseDown})
    node = @getDOMNode()
    node.insertBefore(@gutterComponent.domNode, node.firstChild)

  becameVisible: ->
    @updatesPaused = true
    @measureScrollbars() if @measureScrollbarsWhenShown
    @sampleFontStyling()
    @sampleBackgroundColors()
    @measureHeightAndWidth()
    @measureLineHeightAndDefaultCharWidth() if @measureLineHeightAndDefaultCharWidthWhenShown
    @remeasureCharacterWidths() if @remeasureCharacterWidthsWhenShown
    @props.editor.setVisible(true)
    @performedInitialMeasurement = true
    @updatesPaused = false
    @forceUpdate() if @canUpdate()

  requestUpdate: ->
    return unless @canUpdate()

    if @updatesPaused
      @updateRequestedWhilePaused = true
      return

    if @props.hostElement.isUpdatedSynchronously()
      @forceUpdate()
    else unless @updateRequested
      @updateRequested = true
      requestAnimationFrame =>
        @updateRequested = false
        @forceUpdate() if @canUpdate()

  canUpdate: ->
    @isMounted() and @props.editor.isAlive()

  requestAnimationFrame: (fn) ->
    @updatesPaused = true
    @pauseDOMPolling()
    requestAnimationFrame =>
      fn()
      @updatesPaused = false
      if @updateRequestedWhilePaused and @canUpdate()
        @updateRequestedWhilePaused = false
        @forceUpdate()

  getTopmostDOMNode: ->
    @props.hostElement

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

  observeEditor: ->
    {editor} = @props
    @subscribe editor.onDidChangeGutterVisible(@updateGutterVisible)
    @subscribe editor.onDidChangeMini(@setMini)
    @subscribe editor.observeGrammar(@onGrammarChanged)
    @subscribe editor.observeCursors(@onCursorAdded)
    @subscribe editor.observeSelections(@onSelectionAdded)

  listenForDOMEvents: ->
    node = @getDOMNode()
    node.addEventListener 'mousewheel', @onMouseWheel
    node.addEventListener 'textInput', @onTextInput
    @refs.scrollView.getDOMNode().addEventListener 'mousedown', @onMouseDown

    scrollViewNode = @refs.scrollView.getDOMNode()
    scrollViewNode.addEventListener 'scroll', @onScrollViewScroll
    window.addEventListener 'resize', @requestHeightAndWidthMeasurement

    @listenForIMEEvents()
    @trackSelectionClipboard() if process.platform is 'linux'

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

  # Listen for selection changes and store the currently selected text
  # in the selection clipboard. This is only applicable on Linux.
  trackSelectionClipboard: ->
    timeoutId = null
    {editor} = @props
    writeSelectedTextToSelectionClipboard = ->
      return if editor.isDestroyed()
      if selectedText = editor.getSelectedText()
        # This uses ipc.send instead of clipboard.writeText because
        # clipboard.writeText is a sync ipc call on Linux and that
        # will slow down selections.
        ipc.send('write-text-to-selection-clipboard', selectedText)
    @subscribe editor.onDidChangeSelectionRange ->
      clearTimeout(timeoutId)
      timeoutId = setTimeout(writeSelectedTextToSelectionClipboard)

  observeConfig: ->
    @subscribe atom.config.onDidChange 'editor.fontSize', @sampleFontStyling
    @subscribe atom.config.onDidChange 'editor.fontFamily', @sampleFontStyling
    @subscribe atom.config.onDidChange 'editor.lineHeight', @sampleFontStyling

  onGrammarChanged: ->
    {editor} = @props

    @scopedConfigSubscriptions?.dispose()
    @scopedConfigSubscriptions = subscriptions = new CompositeDisposable

    scopeDescriptor = editor.getRootScopeDescriptor()

    subscriptions.add atom.config.observe 'editor.showIndentGuide', scope: scopeDescriptor, @requestUpdate
    subscriptions.add atom.config.observe 'editor.showLineNumbers', scope: scopeDescriptor, @updateGutterVisible
    subscriptions.add atom.config.observe 'editor.scrollSensitivity', scope: scopeDescriptor, @setScrollSensitivity

  focused: ->
    if @isMounted()
      @setState(focused: true)
      @refs.input.focus()

  blurred: ->
    if @isMounted()
      @setState(focused: false)

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

    insertedRange = editor.transact atom.config.get('editor.undoGroupingInterval'), ->
      editor.insertText(event.data)
    inputNode.value = event.data if insertedRange

  onVerticalScroll: (scrollTop) ->
    {editor} = @props

    return if @updateRequested or scrollTop is editor.getScrollTop()

    animationFramePending = @pendingScrollTop?
    @pendingScrollTop = scrollTop
    unless animationFramePending
      @requestAnimationFrame =>
        pendingScrollTop = @pendingScrollTop
        @pendingScrollTop = null
        @presenter.setScrollTop(pendingScrollTop)

  onHorizontalScroll: (scrollLeft) ->
    {editor} = @props

    return if @updateRequested or scrollLeft is editor.getScrollLeft()

    animationFramePending = @pendingScrollLeft?
    @pendingScrollLeft = scrollLeft
    unless animationFramePending
      @requestAnimationFrame =>
        @presenter.setScrollLeft(@pendingScrollLeft)
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
      @presenter.setScrollLeft(previousScrollLeft - Math.round(wheelDeltaX * @scrollSensitivity))
      event.preventDefault() unless previousScrollLeft is editor.getScrollLeft()
    else
      # Scrolling vertically
      @presenter.setMouseWheelScreenRow(@screenRowForNode(event.target))
      previousScrollTop = @presenter.scrollTop
      @presenter.setScrollTop(previousScrollTop - Math.round(wheelDeltaY * @scrollSensitivity))
      event.preventDefault() unless previousScrollTop is editor.getScrollTop()

  onScrollViewScroll: ->
    if @isMounted()
      console.warn "TextEditorScrollView scrolled when it shouldn't have."
      scrollViewNode = @refs.scrollView.getDOMNode()
      scrollViewNode.scrollTop = 0
      scrollViewNode.scrollLeft = 0

  onMouseDown: (event) ->
    unless event.button is 0 or (event.button is 1 and process.platform is 'linux')
      # Only handle mouse down events for left mouse button on all platforms
      # and middle mouse button on Linux since it pastes the selection clipboard
      return

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

  onStylesheetsChanged: (styleElement) ->
    return unless @performedInitialMeasurement
    return unless atom.themes.isInitialLoadComplete()

    # This delay prevents the styling from going haywire when stylesheets are
    # reloaded in dev mode. It seems like a workaround for a browser bug, but
    # not totally sure.

    unless @stylingChangeAnimationFrameRequested
      @stylingChangeAnimationFrameRequested = true
      requestAnimationFrame =>
        @stylingChangeAnimationFrameRequested = false
        if @isMounted()
          @refreshScrollbars() if not styleElement.sheet? or @containsScrollbarSelector(styleElement.sheet)
          @handleStylingChange()

  onAllThemesLoaded: ->
    @refreshScrollbars()
    @handleStylingChange()

  handleStylingChange: ->
    @sampleFontStyling()
    @sampleBackgroundColors()
    @remeasureCharacterWidths()

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

  onCursorAdded: (cursor) ->
    @subscribe cursor.onDidChangePosition @onCursorMoved

  onCursorMoved: ->
    @cursorMoved = true
    @requestUpdate()

  handleDragUntilMouseUp: (event, dragHandler) ->
    {editor} = @props
    dragging = false
    lastMousePosition = {}
    animationLoop = =>
      @requestAnimationFrame =>
        if dragging and @isMounted()
          screenPosition = @screenPositionForMouseEvent(lastMousePosition)
          dragHandler(screenPosition)
          animationLoop()
        else if not @isMounted()
          stopDragging()

    onMouseMove = (event) ->
      lastMousePosition.clientX = event.clientX
      lastMousePosition.clientY = event.clientY

      # Start the animation loop when the mouse moves prior to a mouseup event
      unless dragging
        dragging = true
        animationLoop()

      # Stop dragging when cursor enters dev tools because we can't detect mouseup
      onMouseUp() if event.which is 0

    onMouseUp = (event) ->
      stopDragging()
      editor.finalizeSelections()
      pasteSelectionClipboard(event)

    stopDragging = ->
      dragging = false
      window.removeEventListener('mousemove', onMouseMove)
      window.removeEventListener('mouseup', onMouseUp)

    pasteSelectionClipboard = (event) ->
      if event?.which is 2 and process.platform is 'linux'
        if selection = require('clipboard').readText('selection')
          editor.insertText(selection)

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

    {editor, hostElement} = @props
    scrollViewNode = @refs.scrollView.getDOMNode()
    {position} = getComputedStyle(hostElement)
    {height} = hostElement.style

    if position is 'absolute' or height
      @presenter.setAutoHeight(false)
      height =  hostElement.offsetHeight
      if height > 0
        @presenter.setExplicitHeight(height)
    else
      @presenter.setAutoHeight(true)
      @presenter.setExplicitHeight(null)

    clientWidth = scrollViewNode.clientWidth
    paddingLeft = parseInt(getComputedStyle(scrollViewNode).paddingLeft)
    clientWidth -= paddingLeft
    if clientWidth > 0
      @presenter.setContentFrameWidth(clientWidth)

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
    {hostElement} = @props
    {backgroundColor} = getComputedStyle(hostElement)

    @presenter.setBackgroundColor(backgroundColor)

    if @gutterComponent?
      gutterBackgroundColor = getComputedStyle(@gutterComponent.domNode).backgroundColor
      @presenter.setGutterBackgroundColor(gutterBackgroundColor)

  measureLineHeightAndDefaultCharWidth: ->
    if @isVisible()
      @measureLineHeightAndDefaultCharWidthWhenShown = false
      @linesComponent.measureLineHeightAndDefaultCharWidth()
    else
      @measureLineHeightAndDefaultCharWidthWhenShown = true

  remeasureCharacterWidths: ->
    if @isVisible()
      @remeasureCharacterWidthsWhenShown = false
      @linesComponent.remeasureCharacterWidths()
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

    @presenter.setVerticalScrollbarWidth(width)
    @presenter.setHorizontalScrollbarHeight(height)

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

  consolidateSelections: (e) ->
    e.abortKeyBinding() unless @props.editor.consolidateSelections()

  lineNodeForScreenRow: (screenRow) -> @linesComponent.lineNodeForScreenRow(screenRow)

  lineNumberNodeForScreenRow: (screenRow) -> @gutterComponent.lineNumberNodeForScreenRow(screenRow)

  screenRowForNode: (node) ->
    while node?
      if screenRow = node.dataset.screenRow
        return parseInt(screenRow)
      node = node.parentElement
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
    atom.config.set("editor.showIndentGuide", showIndentGuide)

  setMini: ->
    @updateGutterVisible()
    @requestUpdate()

  updateGutterVisible: ->
    gutterVisible = not @props.editor.isMini() and @props.editor.isGutterVisible() and atom.config.get('editor.showLineNumbers')
    if gutterVisible isnt @gutterVisible
      @gutterVisible = gutterVisible
      @requestUpdate()

  # Deprecated
  setInvisibles: (invisibles={}) ->
    grim.deprecate "Use config.set('editor.invisibles', invisibles) instead"
    atom.config.set('editor.invisibles', invisibles)

  # Deprecated
  setShowInvisibles: (showInvisibles) ->
    atom.config.set('editor.showInvisibles', showInvisibles)

  setScrollSensitivity: (scrollSensitivity) ->
    if scrollSensitivity = parseInt(scrollSensitivity)
      @scrollSensitivity = Math.abs(scrollSensitivity) / 100

  screenPositionForMouseEvent: (event) ->
    pixelPosition = @pixelPositionForMouseEvent(event)
    @props.editor.screenPositionForPixelPosition(pixelPosition)

  pixelPositionForMouseEvent: (event) ->
    {editor} = @props
    {clientX, clientY} = event

    linesClientRect = @linesComponent.domNode.getBoundingClientRect()
    top = clientY - linesClientRect.top
    left = clientX - linesClientRect.left
    {top, left}

  getModel: ->
    @props.editor

  isInputEnabled: -> @inputEnabled

  setInputEnabled: (@inputEnabled) -> @inputEnabled

  updateParentViewFocusedClassIfNeeded: (prevState) ->
    if prevState.focused isnt @state.focused
      @props.hostElement.classList.toggle('is-focused', @state.focused)
      @props.rootElement.classList.toggle('is-focused', @state.focused)

  updateParentViewMiniClass: ->
    @props.hostElement.classList.toggle('mini', @props.editor.isMini())
    @props.rootElement.classList.toggle('mini', @props.editor.isMini())

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
