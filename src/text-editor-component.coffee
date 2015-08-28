_ = require 'underscore-plus'
scrollbarStyle = require 'scrollbar-style'
{Range, Point} = require 'text-buffer'
grim = require 'grim'
{CompositeDisposable} = require 'event-kit'
ipc = require 'ipc'

TextEditorPresenter = require './text-editor-presenter'
GutterContainerComponent = require './gutter-container-component'
InputComponent = require './input-component'
LinesComponent = require './lines-component'
ScrollbarComponent = require './scrollbar-component'
ScrollbarCornerComponent = require './scrollbar-corner-component'
OverlayManager = require './overlay-manager'

module.exports =
class TextEditorComponent
  scrollSensitivity: 0.4
  cursorBlinkPeriod: 800
  cursorBlinkResumeDelay: 100
  tileSize: 12

  pendingScrollTop: null
  pendingScrollLeft: null
  updateRequested: false
  updatesPaused: false
  updateRequestedWhilePaused: false
  heightAndWidthMeasurementRequested: false
  cursorMoved: false
  selectionChanged: false
  inputEnabled: true
  measureScrollbarsWhenShown: true
  measureLineHeightAndDefaultCharWidthWhenShown: true
  remeasureCharacterWidthsWhenShown: false
  stylingChangeAnimationFrameRequested: false
  gutterComponent: null
  mounted: true

  constructor: ({@editor, @hostElement, @rootElement, @stylesElement, @useShadowDOM, tileSize}) ->
    @tileSize = tileSize if tileSize?
    @disposables = new CompositeDisposable

    @observeConfig()
    @setScrollSensitivity(atom.config.get('editor.scrollSensitivity'))

    @presenter = new TextEditorPresenter
      model: @editor
      scrollTop: @editor.getScrollTop()
      scrollLeft: @editor.getScrollLeft()
      tileSize: tileSize
      cursorBlinkPeriod: @cursorBlinkPeriod
      cursorBlinkResumeDelay: @cursorBlinkResumeDelay
      stoppedScrollingDelay: 200

    @presenter.onDidUpdateState(@requestUpdate)

    @domNode = document.createElement('div')
    if @useShadowDOM
      @domNode.classList.add('editor-contents--private')

      insertionPoint = document.createElement('content')
      insertionPoint.setAttribute('select', 'atom-overlay')
      @domNode.appendChild(insertionPoint)
      @overlayManager = new OverlayManager(@presenter, @hostElement)
    else
      @domNode.classList.add('editor-contents')
      @overlayManager = new OverlayManager(@presenter, @domNode)

    @scrollViewNode = document.createElement('div')
    @scrollViewNode.classList.add('scroll-view')
    @domNode.appendChild(@scrollViewNode)

    @mountGutterContainerComponent() if @presenter.getState().gutters.length

    @hiddenInputComponent = new InputComponent
    @scrollViewNode.appendChild(@hiddenInputComponent.getDomNode())

    @linesComponent = new LinesComponent({@presenter, @hostElement, @useShadowDOM})
    @scrollViewNode.appendChild(@linesComponent.getDomNode())

    @horizontalScrollbarComponent = new ScrollbarComponent({orientation: 'horizontal', onScroll: @onHorizontalScroll})
    @scrollViewNode.appendChild(@horizontalScrollbarComponent.getDomNode())

    @verticalScrollbarComponent = new ScrollbarComponent({orientation: 'vertical', onScroll: @onVerticalScroll})
    @domNode.appendChild(@verticalScrollbarComponent.getDomNode())

    @scrollbarCornerComponent = new ScrollbarCornerComponent
    @domNode.appendChild(@scrollbarCornerComponent.getDomNode())

    @observeEditor()
    @listenForDOMEvents()

    @disposables.add @stylesElement.onDidAddStyleElement @onStylesheetsChanged
    @disposables.add @stylesElement.onDidUpdateStyleElement @onStylesheetsChanged
    @disposables.add @stylesElement.onDidRemoveStyleElement @onStylesheetsChanged
    unless atom.themes.isInitialLoadComplete()
      @disposables.add atom.themes.onDidChangeActiveThemes @onAllThemesLoaded
    @disposables.add scrollbarStyle.onDidChangePreferredScrollbarStyle @refreshScrollbars

    @disposables.add atom.views.pollDocument(@pollDOM)

    @updateSync()
    @checkForVisibilityChange()

  destroy: ->
    @mounted = false
    @disposables.dispose()
    @presenter.destroy()
    @gutterContainerComponent?.destroy()

  getDomNode: ->
    @domNode

  updateSync: ->
    @oldState ?= {}
    @newState = @presenter.getState()

    cursorMoved = @cursorMoved
    selectionChanged = @selectionChanged
    @cursorMoved = false
    @selectionChanged = false

    if @editor.getLastSelection()? and not @editor.getLastSelection().isEmpty()
      @domNode.classList.add('has-selection')
    else
      @domNode.classList.remove('has-selection')

    if @newState.focused isnt @oldState.focused
      @domNode.classList.toggle('is-focused', @newState.focused)

    @performedInitialMeasurement = false if @editor.isDestroyed()

    if @performedInitialMeasurement
      if @newState.height isnt @oldState.height
        if @newState.height?
          @domNode.style.height = @newState.height + 'px'
        else
          @domNode.style.height = ''

    if @newState.gutters.length
      @mountGutterContainerComponent() unless @gutterContainerComponent?
      @gutterContainerComponent.updateSync(@newState)
    else
      @gutterContainerComponent?.getDomNode()?.remove()
      @gutterContainerComponent = null

    @hiddenInputComponent.updateSync(@newState)
    @linesComponent.updateSync(@newState)
    @horizontalScrollbarComponent.updateSync(@newState)
    @verticalScrollbarComponent.updateSync(@newState)
    @scrollbarCornerComponent.updateSync(@newState)

    @overlayManager?.render(@newState)

    if @editor.isAlive()
      @updateParentViewFocusedClassIfNeeded()
      @updateParentViewMiniClass()
      if grim.includeDeprecatedAPIs
        @hostElement.__spacePenView.trigger 'cursor:moved' if cursorMoved
        @hostElement.__spacePenView.trigger 'selection:changed' if selectionChanged
        @hostElement.__spacePenView.trigger 'editor:display-updated'

  readAfterUpdateSync: =>
    @linesComponent.measureCharactersInNewLines() if @isVisible() and not @newState.content.scrollingVertically
    @overlayManager?.measureOverlays()

  mountGutterContainerComponent: ->
    @gutterContainerComponent = new GutterContainerComponent({@editor, @onLineNumberGutterMouseDown})
    @domNode.insertBefore(@gutterContainerComponent.getDomNode(), @domNode.firstChild)

  becameVisible: ->
    @updatesPaused = true
    @measureScrollbars() if @measureScrollbarsWhenShown
    @sampleFontStyling()
    @sampleBackgroundColors()
    @measureWindowSize()
    @measureDimensions()
    @measureLineHeightAndDefaultCharWidth() if @measureLineHeightAndDefaultCharWidthWhenShown
    @remeasureCharacterWidths() if @remeasureCharacterWidthsWhenShown
    @editor.setVisible(true)
    @performedInitialMeasurement = true
    @updatesPaused = false
    @updateSync() if @canUpdate()

  requestUpdate: =>
    return unless @canUpdate()

    if @updatesPaused
      @updateRequestedWhilePaused = true
      return

    if @hostElement.isUpdatedSynchronously()
      @updateSync()
    else unless @updateRequested
      @updateRequested = true
      atom.views.updateDocument =>
        @updateRequested = false
        @updateSync() if @canUpdate()
      atom.views.readDocument(@readAfterUpdateSync)

  canUpdate: ->
    @mounted and @editor.isAlive()

  requestAnimationFrame: (fn) ->
    @updatesPaused = true
    requestAnimationFrame =>
      fn()
      @updatesPaused = false
      if @updateRequestedWhilePaused and @canUpdate()
        @updateRequestedWhilePaused = false
        @updateSync()

  getTopmostDOMNode: ->
    @hostElement

  observeEditor: ->
    @disposables.add @editor.observeGrammar(@onGrammarChanged)
    @disposables.add @editor.observeCursors(@onCursorAdded)
    @disposables.add @editor.observeSelections(@onSelectionAdded)

  listenForDOMEvents: ->
    @domNode.addEventListener 'mousewheel', @onMouseWheel
    @domNode.addEventListener 'textInput', @onTextInput
    @scrollViewNode.addEventListener 'mousedown', @onMouseDown
    @scrollViewNode.addEventListener 'scroll', @onScrollViewScroll

    @listenForIMEEvents()
    @trackSelectionClipboard() if process.platform is 'linux'

  listenForIMEEvents: ->
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

    checkpoint = null
    @domNode.addEventListener 'compositionstart', =>
      checkpoint = @editor.createCheckpoint()
    @domNode.addEventListener 'compositionupdate', (event) =>
      @editor.insertText(event.data, select: true)
    @domNode.addEventListener 'compositionend', (event) =>
      @editor.revertToCheckpoint(checkpoint)
      event.target.value = ''

  # Listen for selection changes and store the currently selected text
  # in the selection clipboard. This is only applicable on Linux.
  trackSelectionClipboard: ->
    timeoutId = null
    writeSelectedTextToSelectionClipboard = =>
      return if @editor.isDestroyed()
      if selectedText = @editor.getSelectedText()
        # This uses ipc.send instead of clipboard.writeText because
        # clipboard.writeText is a sync ipc call on Linux and that
        # will slow down selections.
        ipc.send('write-text-to-selection-clipboard', selectedText)
    @disposables.add @editor.onDidChangeSelectionRange ->
      clearTimeout(timeoutId)
      timeoutId = setTimeout(writeSelectedTextToSelectionClipboard)

  observeConfig: ->
    @disposables.add atom.config.onDidChange 'editor.fontSize', @sampleFontStyling
    @disposables.add atom.config.onDidChange 'editor.fontFamily', @sampleFontStyling
    @disposables.add atom.config.onDidChange 'editor.lineHeight', @sampleFontStyling

  onGrammarChanged: =>
    if @scopedConfigDisposables?
      @scopedConfigDisposables.dispose()
      @disposables.remove(@scopedConfigDisposables)

    @scopedConfigDisposables = new CompositeDisposable
    @disposables.add(@scopedConfigDisposables)

    scope = @editor.getRootScopeDescriptor()
    @scopedConfigDisposables.add atom.config.observe 'editor.scrollSensitivity', {scope}, @setScrollSensitivity

  focused: ->
    if @mounted
      @presenter.setFocused(true)
      @hiddenInputComponent.getDomNode().focus()

  blurred: ->
    if @mounted
      @presenter.setFocused(false)

  onTextInput: (event) =>
    event.stopPropagation()

    # If we prevent the insertion of a space character, then the browser
    # interprets the spacebar keypress as a page-down command.
    event.preventDefault() unless event.data is ' '

    return unless @isInputEnabled()

    inputNode = event.target

    # Work around of the accented character suggestion feature in OS X.
    # Text input fires before a character is inserted, and if the browser is
    # replacing the previous un-accented character with an accented variant, it
    # will select backward over it.
    selectedLength = inputNode.selectionEnd - inputNode.selectionStart
    @editor.selectLeft() if selectedLength is 1

    insertedRange = @editor.insertText(event.data, groupUndo: true)
    inputNode.value = event.data if insertedRange

  onVerticalScroll: (scrollTop) =>
    return if @updateRequested or scrollTop is @editor.getScrollTop()

    animationFramePending = @pendingScrollTop?
    @pendingScrollTop = scrollTop
    unless animationFramePending
      @requestAnimationFrame =>
        pendingScrollTop = @pendingScrollTop
        @pendingScrollTop = null
        @presenter.setScrollTop(pendingScrollTop)

  onHorizontalScroll: (scrollLeft) =>
    return if @updateRequested or scrollLeft is @editor.getScrollLeft()

    animationFramePending = @pendingScrollLeft?
    @pendingScrollLeft = scrollLeft
    unless animationFramePending
      @requestAnimationFrame =>
        @presenter.setScrollLeft(@pendingScrollLeft)
        @pendingScrollLeft = null

  onMouseWheel: (event) =>
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
      previousScrollLeft = @presenter.getScrollLeft()
      @presenter.setScrollLeft(previousScrollLeft - Math.round(wheelDeltaX * @scrollSensitivity))
      event.preventDefault() unless previousScrollLeft is @presenter.getScrollLeft()
    else
      # Scrolling vertically
      @presenter.setMouseWheelScreenRow(@screenRowForNode(event.target))
      previousScrollTop = @presenter.getScrollTop()
      @presenter.setScrollTop(previousScrollTop - Math.round(wheelDeltaY * @scrollSensitivity))
      event.preventDefault() unless previousScrollTop is @presenter.getScrollTop()

  onScrollViewScroll: =>
    if @mounted
      console.warn "TextEditorScrollView scrolled when it shouldn't have."
      @scrollViewNode.scrollTop = 0
      @scrollViewNode.scrollLeft = 0

  onMouseDown: (event) =>
    unless event.button is 0 or (event.button is 1 and process.platform is 'linux')
      # Only handle mouse down events for left mouse button on all platforms
      # and middle mouse button on Linux since it pastes the selection clipboard
      return

    return if event.target?.classList.contains('horizontal-scrollbar')

    {detail, shiftKey, metaKey, ctrlKey} = event

    # CTRL+click brings up the context menu on OSX, so don't handle those either
    return if ctrlKey and process.platform is 'darwin'

    # Prevent focusout event on hidden input if editor is already focused
    event.preventDefault() if @oldState.focused

    screenPosition = @screenPositionForMouseEvent(event)

    if event.target?.classList.contains('fold-marker')
      bufferRow = @editor.bufferRowForScreenRow(screenPosition.row)
      @editor.unfoldBufferRow(bufferRow)
      return

    switch detail
      when 1
        if shiftKey
          @editor.selectToScreenPosition(screenPosition)
        else if metaKey or (ctrlKey and process.platform isnt 'darwin')
          cursorAtScreenPosition = @editor.getCursorAtScreenPosition(screenPosition)
          if cursorAtScreenPosition and @editor.hasMultipleCursors()
            cursorAtScreenPosition.destroy()
          else
            @editor.addCursorAtScreenPosition(screenPosition, autoscroll: false)
        else
          @editor.setCursorScreenPosition(screenPosition, autoscroll: false)
      when 2
        @editor.getLastSelection().selectWord(autoscroll: false)
      when 3
        @editor.getLastSelection().selectLine(null, autoscroll: false)

    @handleDragUntilMouseUp (screenPosition) =>
      @editor.selectToScreenPosition(screenPosition, suppressSelectionMerge: true, autoscroll: false)

  onLineNumberGutterMouseDown: (event) =>
    return unless event.button is 0 # only handle the left mouse button

    {shiftKey, metaKey, ctrlKey} = event

    if shiftKey
      @onGutterShiftClick(event)
    else if metaKey or (ctrlKey and process.platform isnt 'darwin')
      @onGutterMetaClick(event)
    else
      @onGutterClick(event)

  onGutterClick: (event) =>
    clickedScreenRow = @screenPositionForMouseEvent(event).row
    clickedBufferRow = @editor.bufferRowForScreenRow(clickedScreenRow)
    initialScreenRange = @editor.screenRangeForBufferRange([[clickedBufferRow, 0], [clickedBufferRow + 1, 0]])
    @editor.setSelectedScreenRange(initialScreenRange, preserveFolds: true, autoscroll: false)
    @handleGutterDrag(initialScreenRange)

  onGutterMetaClick: (event) =>
    clickedScreenRow = @screenPositionForMouseEvent(event).row
    clickedBufferRow = @editor.bufferRowForScreenRow(clickedScreenRow)
    initialScreenRange = @editor.screenRangeForBufferRange([[clickedBufferRow, 0], [clickedBufferRow + 1, 0]])
    @editor.addSelectionForScreenRange(initialScreenRange, preserveFolds: true, autoscroll: false)
    @handleGutterDrag(initialScreenRange)

  onGutterShiftClick: (event) =>
    tailScreenPosition = @editor.getLastSelection().getTailScreenPosition()
    clickedScreenRow = @screenPositionForMouseEvent(event).row
    clickedBufferRow = @editor.bufferRowForScreenRow(clickedScreenRow)
    clickedLineScreenRange = @editor.screenRangeForBufferRange([[clickedBufferRow, 0], [clickedBufferRow + 1, 0]])

    if clickedScreenRow < tailScreenPosition.row
      @editor.selectToScreenPosition(clickedLineScreenRange.start, suppressSelectionMerge: true, autoscroll: false)
    else
      @editor.selectToScreenPosition(clickedLineScreenRange.end, suppressSelectionMerge: true, autoscroll: false)

    @handleGutterDrag(new Range(tailScreenPosition, tailScreenPosition))

  handleGutterDrag: (initialRange) ->
    @handleDragUntilMouseUp (screenPosition) =>
      dragRow = screenPosition.row
      if dragRow < initialRange.start.row
        startPosition = @editor.clipScreenPosition([dragRow, 0], skipSoftWrapIndentation: true)
        screenRange = new Range(startPosition, startPosition).union(initialRange)
        @editor.getLastSelection().setScreenRange(screenRange, reversed: true, autoscroll: false, preserveFolds: true)
      else
        endPosition = [dragRow + 1, 0]
        screenRange = new Range(endPosition, endPosition).union(initialRange)
        @editor.getLastSelection().setScreenRange(screenRange, reversed: false, autoscroll: false, preserveFolds: true)

  onStylesheetsChanged: (styleElement) =>
    return unless @performedInitialMeasurement
    return unless atom.themes.isInitialLoadComplete()

    # This delay prevents the styling from going haywire when stylesheets are
    # reloaded in dev mode. It seems like a workaround for a browser bug, but
    # not totally sure.

    unless @stylingChangeAnimationFrameRequested
      @stylingChangeAnimationFrameRequested = true
      requestAnimationFrame =>
        @stylingChangeAnimationFrameRequested = false
        if @mounted
          @refreshScrollbars() if not styleElement.sheet? or @containsScrollbarSelector(styleElement.sheet)
          @handleStylingChange()

  onAllThemesLoaded: =>
    @refreshScrollbars()
    @handleStylingChange()

  handleStylingChange: =>
    @sampleFontStyling()
    @sampleBackgroundColors()
    @remeasureCharacterWidths()

  onSelectionAdded: (selection) =>
    selectionDisposables = new CompositeDisposable
    selectionDisposables.add selection.onDidChangeRange => @onSelectionChanged(selection)
    selectionDisposables.add selection.onDidDestroy =>
      @onSelectionChanged(selection)
      selectionDisposables.dispose()
      @disposables.remove(selectionDisposables)

    @disposables.add(selectionDisposables)

    if @editor.selectionIntersectsVisibleRowRange(selection)
      @selectionChanged = true

  onSelectionChanged: (selection) =>
    if @editor.selectionIntersectsVisibleRowRange(selection)
      @selectionChanged = true

  onCursorAdded: (cursor) =>
    @disposables.add cursor.onDidChangePosition @onCursorMoved

  onCursorMoved: =>
    @cursorMoved = true

  handleDragUntilMouseUp: (dragHandler) =>
    dragging = false
    lastMousePosition = {}
    animationLoop = =>
      @requestAnimationFrame =>
        if dragging and @mounted
          linesClientRect = @linesComponent.getDomNode().getBoundingClientRect()
          autoscroll(lastMousePosition, linesClientRect)
          screenPosition = @screenPositionForMouseEvent(lastMousePosition, linesClientRect)
          dragHandler(screenPosition)
          animationLoop()
        else if not @mounted
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

    onMouseUp = (event) =>
      if dragging
        stopDragging()
        @editor.finalizeSelections()
        @editor.mergeIntersectingSelections()
      pasteSelectionClipboard(event)

    stopDragging = ->
      dragging = false
      window.removeEventListener('mousemove', onMouseMove)
      window.removeEventListener('mouseup', onMouseUp)
      willInsertTextSubscription.dispose()

    autoscroll = (mouseClientPosition) =>
      editorClientRect = @domNode.getBoundingClientRect()

      if mouseClientPosition.clientY < editorClientRect.top
        mouseYDelta = editorClientRect.top - mouseClientPosition.clientY
        yDirection = -1
      else if mouseClientPosition.clientY > editorClientRect.bottom
        mouseYDelta = mouseClientPosition.clientY - editorClientRect.bottom
        yDirection = 1

      if mouseClientPosition.clientX < editorClientRect.left
        mouseXDelta = editorClientRect.left - mouseClientPosition.clientX
        xDirection = -1
      else if mouseClientPosition.clientX > editorClientRect.right
        mouseXDelta = mouseClientPosition.clientX - editorClientRect.right
        xDirection = 1

      if mouseYDelta?
        @presenter.setScrollTop(@presenter.getScrollTop() + yDirection * scaleScrollDelta(mouseYDelta))

      if mouseXDelta?
        @presenter.setScrollLeft(@presenter.getScrollLeft() + xDirection * scaleScrollDelta(mouseXDelta))

    scaleScrollDelta = (scrollDelta) ->
      Math.pow(scrollDelta / 2, 3) / 280

    pasteSelectionClipboard = (event) =>
      if event?.which is 2 and process.platform is 'linux'
        if selection = require('./safe-clipboard').readText('selection')
          @editor.insertText(selection)

    window.addEventListener('mousemove', onMouseMove)
    window.addEventListener('mouseup', onMouseUp)
    willInsertTextSubscription = @editor.onWillInsertText(onMouseUp)

  isVisible: ->
    @domNode.offsetHeight > 0 or @domNode.offsetWidth > 0

  pollDOM: =>
    unless @checkForVisibilityChange()
      @sampleBackgroundColors()
      @measureDimensions()
      @sampleFontStyling()
      @overlayManager?.measureOverlays()

  checkForVisibilityChange: ->
    if @isVisible()
      if @wasVisible
        false
      else
        @becameVisible()
        @wasVisible = true
    else
      @wasVisible = false

  # Measure explicitly-styled height and width and relay them to the model. If
  # these values aren't explicitly styled, we assume the editor is unconstrained
  # and use the scrollHeight / scrollWidth as its height and width in
  # calculations.
  measureDimensions: ->
    return unless @mounted

    {position} = getComputedStyle(@hostElement)
    {height} = @hostElement.style

    if position is 'absolute' or height
      @presenter.setAutoHeight(false)
      height =  @hostElement.offsetHeight
      if height > 0
        @presenter.setExplicitHeight(height)
    else
      @presenter.setAutoHeight(true)
      @presenter.setExplicitHeight(null)

    clientWidth = @scrollViewNode.clientWidth
    paddingLeft = parseInt(getComputedStyle(@scrollViewNode).paddingLeft)
    clientWidth -= paddingLeft
    if clientWidth > 0
      @presenter.setContentFrameWidth(clientWidth)

    @presenter.setGutterWidth(@gutterContainerComponent?.getDomNode().offsetWidth ? 0)
    @presenter.setBoundingClientRect(@hostElement.getBoundingClientRect())

  measureWindowSize: ->
    return unless @mounted

    # FIXME: on Ubuntu (via xvfb) `window.innerWidth` reports an incorrect value
    # when window gets resized through `atom.setWindowDimensions({width:
    # windowWidth, height: windowHeight})`.
    @presenter.setWindowSize(window.innerWidth, window.innerHeight)

  sampleFontStyling: =>
    oldFontSize = @fontSize
    oldFontFamily = @fontFamily
    oldLineHeight = @lineHeight

    {@fontSize, @fontFamily, @lineHeight} = getComputedStyle(@getTopmostDOMNode())

    if @fontSize isnt oldFontSize or @fontFamily isnt oldFontFamily or @lineHeight isnt oldLineHeight
      @measureLineHeightAndDefaultCharWidth()

    if (@fontSize isnt oldFontSize or @fontFamily isnt oldFontFamily) and @performedInitialMeasurement
      @remeasureCharacterWidths()

  sampleBackgroundColors: (suppressUpdate) ->
    {backgroundColor} = getComputedStyle(@hostElement)

    @presenter.setBackgroundColor(backgroundColor)

    lineNumberGutter = @gutterContainerComponent?.getLineNumberGutterComponent()
    if lineNumberGutter
      gutterBackgroundColor = getComputedStyle(lineNumberGutter.getDomNode()).backgroundColor
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

    cornerNode = @scrollbarCornerComponent.getDomNode()
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

  refreshScrollbars: =>
    if @isVisible()
      @measureScrollbarsWhenShown = false
    else
      @measureScrollbarsWhenShown = true
      return

    verticalNode = @verticalScrollbarComponent.getDomNode()
    horizontalNode = @horizontalScrollbarComponent.getDomNode()
    cornerNode = @scrollbarCornerComponent.getDomNode()

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
    e.abortKeyBinding() unless @editor.consolidateSelections()

  lineNodeForScreenRow: (screenRow) ->
    tileRow = @presenter.tileForRow(screenRow)
    tileComponent = @linesComponent.getComponentForTile(tileRow)

    tileComponent?.lineNodeForScreenRow(screenRow)

  lineNumberNodeForScreenRow: (screenRow) ->
    tileRow = @presenter.tileForRow(screenRow)
    gutterComponent = @gutterContainerComponent.getLineNumberGutterComponent()
    tileComponent = gutterComponent.getComponentForTile(tileRow)

    tileComponent?.lineNumberNodeForScreenRow(screenRow)

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

  setScrollSensitivity: (scrollSensitivity) =>
    if scrollSensitivity = parseInt(scrollSensitivity)
      @scrollSensitivity = Math.abs(scrollSensitivity) / 100

  screenPositionForMouseEvent: (event, linesClientRect) ->
    pixelPosition = @pixelPositionForMouseEvent(event, linesClientRect)
    @editor.screenPositionForPixelPosition(pixelPosition)

  pixelPositionForMouseEvent: (event, linesClientRect) ->
    {clientX, clientY} = event

    linesClientRect ?= @linesComponent.getDomNode().getBoundingClientRect()
    top = clientY - linesClientRect.top + @presenter.scrollTop
    left = clientX - linesClientRect.left + @presenter.scrollLeft
    bottom = linesClientRect.top + @presenter.scrollTop + linesClientRect.height - clientY
    right = linesClientRect.left + @presenter.scrollLeft + linesClientRect.width - clientX

    {top, left, bottom, right}

  getModel: ->
    @editor

  isInputEnabled: -> @inputEnabled

  setInputEnabled: (@inputEnabled) -> @inputEnabled

  updateParentViewFocusedClassIfNeeded: ->
    if @oldState.focused isnt @newState.focused
      @hostElement.classList.toggle('is-focused', @newState.focused)
      @rootElement.classList.toggle('is-focused', @newState.focused)
      @oldState.focused = @newState.focused

  updateParentViewMiniClass: ->
    @hostElement.classList.toggle('mini', @editor.isMini())
    @rootElement.classList.toggle('mini', @editor.isMini())

if grim.includeDeprecatedAPIs
  TextEditorComponent::setInvisibles = (invisibles={}) ->
    grim.deprecate "Use config.set('editor.invisibles', invisibles) instead"
    atom.config.set('editor.invisibles', invisibles)

  TextEditorComponent::setShowInvisibles = (showInvisibles) ->
    grim.deprecate "Use config.set('editor.showInvisibles', showInvisibles) instead"
    atom.config.set('editor.showInvisibles', showInvisibles)
