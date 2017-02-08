scrollbarStyle = require 'scrollbar-style'
{Range, Point} = require 'text-buffer'
{CompositeDisposable, Disposable} = require 'event-kit'
{ipcRenderer} = require 'electron'
Grim = require 'grim'
elementResizeDetector = require('element-resize-detector')({strategy: 'scroll'})

TextEditorPresenter = require './text-editor-presenter'
GutterContainerComponent = require './gutter-container-component'
InputComponent = require './input-component'
LinesComponent = require './lines-component'
OffScreenBlockDecorationsComponent = require './off-screen-block-decorations-component'
ScrollbarComponent = require './scrollbar-component'
ScrollbarCornerComponent = require './scrollbar-corner-component'
OverlayManager = require './overlay-manager'
DOMElementPool = require './dom-element-pool'
LinesYardstick = require './lines-yardstick'
LineTopIndex = require 'line-top-index'

module.exports =
class TextEditorComponent
  cursorBlinkPeriod: 800
  cursorBlinkResumeDelay: 100
  tileSize: 12

  pendingScrollTop: null
  pendingScrollLeft: null
  updateRequested: false
  updatesPaused: false
  updateRequestedWhilePaused: false
  heightAndWidthMeasurementRequested: false
  inputEnabled: true
  measureScrollbarsWhenShown: true
  measureLineHeightAndDefaultCharWidthWhenShown: true
  stylingChangeAnimationFrameRequested: false
  gutterComponent: null
  mounted: true
  initialized: false

  Object.defineProperty @prototype, "domNode",
    get: -> @domNodeValue
    set: (domNode) ->
      @assert domNode?, "TextEditorComponent::domNode was set to null."
      @domNodeValue = domNode

  constructor: ({@editor, @hostElement, tileSize, @views, @themes, @styles, @assert, hiddenInputElement}) ->
    @tileSize = tileSize if tileSize?
    @disposables = new CompositeDisposable

    lineTopIndex = new LineTopIndex({
      defaultLineHeight: @editor.getLineHeightInPixels()
    })
    @presenter = new TextEditorPresenter
      model: @editor
      tileSize: tileSize
      cursorBlinkPeriod: @cursorBlinkPeriod
      cursorBlinkResumeDelay: @cursorBlinkResumeDelay
      stoppedScrollingDelay: 200
      lineTopIndex: lineTopIndex
      autoHeight: @editor.getAutoHeight()

    @presenter.onDidUpdateState(@requestUpdate)

    @domElementPool = new DOMElementPool
    @domNode = document.createElement('div')
    @domNode.classList.add('editor-contents--private')

    @overlayManager = new OverlayManager(@presenter, @domNode, @views)

    @scrollViewNode = document.createElement('div')
    @scrollViewNode.classList.add('scroll-view')
    @domNode.appendChild(@scrollViewNode)

    @hiddenInputComponent = new InputComponent(hiddenInputElement)
    @scrollViewNode.appendChild(hiddenInputElement)
    # Add a getModel method to the hidden input component to make it easy to
    # access the editor in response to DOM events or when using
    # document.activeElement.
    hiddenInputElement.getModel = => @editor

    @linesComponent = new LinesComponent({@presenter, @domElementPool, @assert, @grammars, @views})
    @scrollViewNode.appendChild(@linesComponent.getDomNode())

    @offScreenBlockDecorationsComponent = new OffScreenBlockDecorationsComponent({@presenter, @views})
    @scrollViewNode.appendChild(@offScreenBlockDecorationsComponent.getDomNode())

    @linesYardstick = new LinesYardstick(@editor, @linesComponent, lineTopIndex)
    @presenter.setLinesYardstick(@linesYardstick)

    @horizontalScrollbarComponent = new ScrollbarComponent({orientation: 'horizontal', onScroll: @onHorizontalScroll})
    @scrollViewNode.appendChild(@horizontalScrollbarComponent.getDomNode())

    @verticalScrollbarComponent = new ScrollbarComponent({orientation: 'vertical', onScroll: @onVerticalScroll})
    @domNode.appendChild(@verticalScrollbarComponent.getDomNode())

    @scrollbarCornerComponent = new ScrollbarCornerComponent
    @domNode.appendChild(@scrollbarCornerComponent.getDomNode())

    @observeEditor()
    @listenForDOMEvents()

    @disposables.add @styles.onDidAddStyleElement @onStylesheetsChanged
    @disposables.add @styles.onDidUpdateStyleElement @onStylesheetsChanged
    @disposables.add @styles.onDidRemoveStyleElement @onStylesheetsChanged
    unless @themes.isInitialLoadComplete()
      @disposables.add @themes.onDidChangeActiveThemes @onAllThemesLoaded
    @disposables.add scrollbarStyle.onDidChangePreferredScrollbarStyle @refreshScrollbars

    @disposables.add @views.pollDocument(@pollDOM)

    @updateSync()
    @initialized = true

  destroy: ->
    @mounted = false
    @disposables.dispose()
    @presenter.destroy()
    @gutterContainerComponent?.destroy()
    @domElementPool.clear()

    @verticalScrollbarComponent.destroy()
    @horizontalScrollbarComponent.destroy()

    @onVerticalScroll = null
    @onHorizontalScroll = null

    @intersectionObserver?.disconnect()

  didAttach: ->
    @intersectionObserver = new IntersectionObserver((entries) =>
      if entries[entries.length - 1].intersectionRatio isnt 0
        @becameVisible()
    )
    @intersectionObserver.observe(@domNode)

    measureDimensions = @measureDimensions.bind(this)
    elementResizeDetector.listenTo(@domNode, measureDimensions)
    @disposables.add(new Disposable => elementResizeDetector.removeListener(@domNode, measureDimensions))

  getDomNode: ->
    @domNode

  updateSync: ->
    @updateSyncPreMeasurement()

    @oldState ?= {width: null}
    @newState = @presenter.getPostMeasurementState()

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

      if @newState.width isnt @oldState.width
        if @newState.width?
          @hostElement.style.width = @newState.width + 'px'
        else
          @hostElement.style.width = ''
        @oldState.width = @newState.width

    if @newState.gutters.length
      @mountGutterContainerComponent() unless @gutterContainerComponent?
      @gutterContainerComponent.updateSync(@newState)
    else
      @gutterContainerComponent?.getDomNode()?.remove()
      @gutterContainerComponent = null

    @hiddenInputComponent.updateSync(@newState)
    @offScreenBlockDecorationsComponent.updateSync(@newState)
    @linesComponent.updateSync(@newState)
    @horizontalScrollbarComponent.updateSync(@newState)
    @verticalScrollbarComponent.updateSync(@newState)
    @scrollbarCornerComponent.updateSync(@newState)

    @overlayManager?.render(@newState)

    if @clearPoolAfterUpdate
      @domElementPool.clear()
      @clearPoolAfterUpdate = false

    if @editor.isAlive()
      @updateParentViewFocusedClassIfNeeded()
      @updateParentViewMiniClass()

  updateSyncPreMeasurement: ->
    @linesComponent.updateSync(@presenter.getPreMeasurementState())

  readAfterUpdateSync: =>
    @overlayManager?.measureOverlays()
    @linesComponent.measureBlockDecorations()
    @offScreenBlockDecorationsComponent.measureBlockDecorations()

  mountGutterContainerComponent: ->
    @gutterContainerComponent = new GutterContainerComponent({@editor, @onLineNumberGutterMouseDown, @domElementPool, @views})
    @domNode.insertBefore(@gutterContainerComponent.getDomNode(), @domNode.firstChild)

  becameVisible: ->
    @updatesPaused = true
    # Always invalidate LinesYardstick measurements when the editor becomes
    # visible again, because content might have been reflowed and measurements
    # could be outdated.
    @invalidateMeasurements()
    @measureScrollbars() if @measureScrollbarsWhenShown
    @sampleFontStyling()
    @sampleBackgroundColors()
    @measureWindowSize()
    @measureDimensions()
    @measureLineHeightAndDefaultCharWidth() if @measureLineHeightAndDefaultCharWidthWhenShown
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
      @views.updateDocument =>
        @updateRequested = false
        @updateSync() if @canUpdate()
      @views.readDocument(@readAfterUpdateSync)

  canUpdate: ->
    @mounted and @editor.isAlive()

  requestAnimationFrame: (fn) ->
    @updatesPaused = true
    requestAnimationFrame =>
      fn()
      @updatesPaused = false
      if @updateRequestedWhilePaused and @canUpdate()
        @updateRequestedWhilePaused = false
        @requestUpdate()

  getTopmostDOMNode: ->
    @hostElement

  observeEditor: ->
    @disposables.add @editor.observeGrammar(@onGrammarChanged)

  listenForDOMEvents: ->
    @domNode.addEventListener 'mousewheel', @onMouseWheel
    @domNode.addEventListener 'textInput', @onTextInput
    @scrollViewNode.addEventListener 'mousedown', @onMouseDown
    @scrollViewNode.addEventListener 'scroll', @onScrollViewScroll

    @detectAccentedCharacterMenu()
    @listenForIMEEvents()
    @trackSelectionClipboard() if process.platform is 'linux'

  detectAccentedCharacterMenu: ->
    # We need to get clever to detect when the accented character menu is
    # opened on macOS. Usually, every keydown event that could cause input is
    # followed by a corresponding keypress. However, pressing and holding
    # long enough to open the accented character menu causes additional keydown
    # events to fire that aren't followed by their own keypress and textInput
    # events.
    #
    # Therefore, we assume the accented character menu has been deployed if,
    # before observing any keyup event, we observe events in the following
    # sequence:
    #
    # keydown(keyCode: X), keypress, keydown(keyCode: X)
    #
    # The keyCode X must be the same in the keydown events that bracket the
    # keypress, meaning we're *holding* the _same_ key we intially pressed.
    # Got that?
    lastKeydown = null
    lastKeydownBeforeKeypress = null

    @domNode.addEventListener 'keydown', (event) =>
      if lastKeydownBeforeKeypress
        if lastKeydownBeforeKeypress.keyCode is event.keyCode
          @openedAccentedCharacterMenu = true
        lastKeydownBeforeKeypress = null
      else
        lastKeydown = event

    @domNode.addEventListener 'keypress', =>
      lastKeydownBeforeKeypress = lastKeydown
      lastKeydown = null

      # This cancels the accented character behavior if we type a key normally
      # with the menu open.
      @openedAccentedCharacterMenu = false

    @domNode.addEventListener 'keyup', ->
      lastKeydownBeforeKeypress = null
      lastKeydown = null

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
      if @openedAccentedCharacterMenu
        @editor.selectLeft()
        @openedAccentedCharacterMenu = false
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
        # This uses ipcRenderer.send instead of clipboard.writeText because
        # clipboard.writeText is a sync ipcRenderer call on Linux and that
        # will slow down selections.
        ipcRenderer.send('write-text-to-selection-clipboard', selectedText)
    @disposables.add @editor.onDidChangeSelectionRange ->
      clearTimeout(timeoutId)
      timeoutId = setTimeout(writeSelectedTextToSelectionClipboard)

  onGrammarChanged: =>
    if @scopedConfigDisposables?
      @scopedConfigDisposables.dispose()
      @disposables.remove(@scopedConfigDisposables)

    @scopedConfigDisposables = new CompositeDisposable
    @disposables.add(@scopedConfigDisposables)

  focused: ->
    if @mounted
      @presenter.setFocused(true)

  blurred: ->
    if @mounted
      @presenter.setFocused(false)

  onTextInput: (event) =>
    event.stopPropagation()

    # WARNING: If we call preventDefault on the input of a space character,
    # then the browser interprets the spacebar keypress as a page-down command,
    # causing spaces to scroll elements containing editors. This is impossible
    # to test.
    event.preventDefault() if event.data isnt ' '

    return unless @isInputEnabled()

    # Workaround of the accented character suggestion feature in macOS.
    # This will only occur when the user is not composing in IME mode.
    # When the user selects a modified character from the macOS menu, `textInput`
    # will occur twice, once for the initial character, and once for the
    # modified character. However, only a single keypress will have fired. If
    # this is the case, select backward to replace the original character.
    if @openedAccentedCharacterMenu
      @editor.selectLeft()
      @openedAccentedCharacterMenu = false

    @editor.insertText(event.data, groupUndo: true)

  onVerticalScroll: (scrollTop) =>
    return if @updateRequested or scrollTop is @presenter.getScrollTop()

    animationFramePending = @pendingScrollTop?
    @pendingScrollTop = scrollTop
    unless animationFramePending
      @requestAnimationFrame =>
        pendingScrollTop = @pendingScrollTop
        @pendingScrollTop = null
        @presenter.setScrollTop(pendingScrollTop)
        @presenter.commitPendingScrollTopPosition()

  onHorizontalScroll: (scrollLeft) =>
    return if @updateRequested or scrollLeft is @presenter.getScrollLeft()

    animationFramePending = @pendingScrollLeft?
    @pendingScrollLeft = scrollLeft
    unless animationFramePending
      @requestAnimationFrame =>
        @presenter.setScrollLeft(@pendingScrollLeft)
        @presenter.commitPendingScrollLeftPosition()
        @pendingScrollLeft = null

  onMouseWheel: (event) =>
    # Only scroll in one direction at a time
    {wheelDeltaX, wheelDeltaY} = event

    if Math.abs(wheelDeltaX) > Math.abs(wheelDeltaY)
      # Scrolling horizontally
      previousScrollLeft = @presenter.getScrollLeft()
      updatedScrollLeft = previousScrollLeft - Math.round(wheelDeltaX * @editor.getScrollSensitivity() / 100)

      event.preventDefault() if @presenter.canScrollLeftTo(updatedScrollLeft)
      @presenter.setScrollLeft(updatedScrollLeft)
    else
      # Scrolling vertically
      @presenter.setMouseWheelScreenRow(@screenRowForNode(event.target))
      previousScrollTop = @presenter.getScrollTop()
      updatedScrollTop = previousScrollTop - Math.round(wheelDeltaY * @editor.getScrollSensitivity() / 100)

      event.preventDefault() if @presenter.canScrollTopTo(updatedScrollTop)
      @presenter.setScrollTop(updatedScrollTop)

  onScrollViewScroll: =>
    if @mounted
      @scrollViewNode.scrollTop = 0
      @scrollViewNode.scrollLeft = 0

  onDidChangeScrollTop: (callback) ->
    @presenter.onDidChangeScrollTop(callback)

  onDidChangeScrollLeft: (callback) ->
    @presenter.onDidChangeScrollLeft(callback)

  setScrollLeft: (scrollLeft) ->
    @presenter.setScrollLeft(scrollLeft)

  setScrollRight: (scrollRight) ->
    @presenter.setScrollRight(scrollRight)

  setScrollTop: (scrollTop) ->
    @presenter.setScrollTop(scrollTop)

  setScrollBottom: (scrollBottom) ->
    @presenter.setScrollBottom(scrollBottom)

  getScrollTop: ->
    @presenter.getScrollTop()

  getScrollLeft: ->
    @presenter.getScrollLeft()

  getScrollRight: ->
    @presenter.getScrollRight()

  getScrollBottom: ->
    @presenter.getScrollBottom()

  getScrollHeight: ->
    @presenter.getScrollHeight()

  getScrollWidth: ->
    @presenter.getScrollWidth()

  getMaxScrollTop: ->
    @presenter.getMaxScrollTop()

  getVerticalScrollbarWidth: ->
    @presenter.getVerticalScrollbarWidth()

  getHorizontalScrollbarHeight: ->
    @presenter.getHorizontalScrollbarHeight()

  getVisibleRowRange: ->
    @presenter.getVisibleRowRange()

  pixelPositionForScreenPosition: (screenPosition, clip=true) ->
    screenPosition = Point.fromObject(screenPosition)
    screenPosition = @editor.clipScreenPosition(screenPosition) if clip

    unless @presenter.isRowRendered(screenPosition.row)
      @presenter.setScreenRowsToMeasure([screenPosition.row])

    unless @linesComponent.lineNodeForScreenRow(screenPosition.row)?
      @updateSyncPreMeasurement()

    pixelPosition = @linesYardstick.pixelPositionForScreenPosition(screenPosition)
    @presenter.clearScreenRowsToMeasure()
    pixelPosition

  screenPositionForPixelPosition: (pixelPosition) ->
    row = @linesYardstick.measuredRowForPixelPosition(pixelPosition)
    if row? and not @presenter.isRowRendered(row)
      @presenter.setScreenRowsToMeasure([row])
      @updateSyncPreMeasurement()

    position = @linesYardstick.screenPositionForPixelPosition(pixelPosition)
    @presenter.clearScreenRowsToMeasure()
    position

  pixelRectForScreenRange: (screenRange) ->
    rowsToMeasure = []
    unless @presenter.isRowRendered(screenRange.start.row)
      rowsToMeasure.push(screenRange.start.row)
    unless @presenter.isRowRendered(screenRange.end.row)
      rowsToMeasure.push(screenRange.end.row)

    if rowsToMeasure.length > 0
      @presenter.setScreenRowsToMeasure(rowsToMeasure)
      @updateSyncPreMeasurement()

    rect = @presenter.absolutePixelRectForScreenRange(screenRange)

    if rowsToMeasure.length > 0
      @presenter.clearScreenRowsToMeasure()

    rect

  pixelRangeForScreenRange: (screenRange, clip=true) ->
    {start, end} = Range.fromObject(screenRange)
    {start: @pixelPositionForScreenPosition(start, clip), end: @pixelPositionForScreenPosition(end, clip)}

  pixelPositionForBufferPosition: (bufferPosition) ->
    @pixelPositionForScreenPosition(
      @editor.screenPositionForBufferPosition(bufferPosition)
    )

  invalidateBlockDecorationDimensions: ->
    @presenter.invalidateBlockDecorationDimensions(arguments...)

  onMouseDown: (event) =>
    # Handle middle mouse button on linux platform only (paste clipboard)
    if event.button is 1 and process.platform is 'linux'
      if selection = require('./safe-clipboard').readText('selection')
        screenPosition = @screenPositionForMouseEvent(event)
        @editor.setCursorScreenPosition(screenPosition, autoscroll: false)
        @editor.insertText(selection)
        return

    # Handle mouse down events for left mouse button only
    # (except middle mouse button on linux platform, see above)
    unless event.button is 0
      return

    return if event.target?.classList.contains('horizontal-scrollbar')

    {detail, shiftKey, metaKey, ctrlKey} = event

    # CTRL+click brings up the context menu on macOS, so don't handle those either
    return if ctrlKey and process.platform is 'darwin'

    # Prevent focusout event on hidden input if editor is already focused
    event.preventDefault() if @oldState.focused

    screenPosition = @screenPositionForMouseEvent(event)

    if event.target?.classList.contains('fold-marker')
      bufferPosition = @editor.bufferPositionForScreenPosition(screenPosition)
      @editor.destroyFoldsIntersectingBufferRange([bufferPosition, bufferPosition])
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
    @editor.addSelectionForScreenRange(initialScreenRange, autoscroll: false)
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
        endPosition = @editor.clipScreenPosition([dragRow + 1, 0], clipDirection: 'backward')
        screenRange = new Range(endPosition, endPosition).union(initialRange)
        @editor.getLastSelection().setScreenRange(screenRange, reversed: false, autoscroll: false, preserveFolds: true)

  onStylesheetsChanged: (styleElement) =>
    return unless @performedInitialMeasurement
    return unless @themes.isInitialLoadComplete()

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
    if @isVisible()
      @sampleFontStyling()
      @sampleBackgroundColors()
      @invalidateMeasurements()

  handleDragUntilMouseUp: (dragHandler) ->
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

    stopDragging = ->
      dragging = false
      window.removeEventListener('mousemove', onMouseMove)
      window.removeEventListener('mouseup', onMouseUp)
      disposables.dispose()

    autoscroll = (mouseClientPosition) =>
      {top, bottom, left, right} = @scrollViewNode.getBoundingClientRect()
      top += 30
      bottom -= 30
      left += 30
      right -= 30

      if mouseClientPosition.clientY < top
        mouseYDelta = top - mouseClientPosition.clientY
        yDirection = -1
      else if mouseClientPosition.clientY > bottom
        mouseYDelta = mouseClientPosition.clientY - bottom
        yDirection = 1

      if mouseClientPosition.clientX < left
        mouseXDelta = left - mouseClientPosition.clientX
        xDirection = -1
      else if mouseClientPosition.clientX > right
        mouseXDelta = mouseClientPosition.clientX - right
        xDirection = 1

      if mouseYDelta?
        @presenter.setScrollTop(@presenter.getScrollTop() + yDirection * scaleScrollDelta(mouseYDelta))
        @presenter.commitPendingScrollTopPosition()

      if mouseXDelta?
        @presenter.setScrollLeft(@presenter.getScrollLeft() + xDirection * scaleScrollDelta(mouseXDelta))
        @presenter.commitPendingScrollLeftPosition()

    scaleScrollDelta = (scrollDelta) ->
      Math.pow(scrollDelta / 2, 3) / 280

    window.addEventListener('mousemove', onMouseMove)
    window.addEventListener('mouseup', onMouseUp)
    disposables = new CompositeDisposable
    disposables.add(@editor.getBuffer().onWillChange(onMouseUp))
    disposables.add(@editor.onDidDestroy(stopDragging))

  isVisible: ->
    # Investigating an exception that occurs here due to ::domNode being null.
    @assert @domNode?, "TextEditorComponent::domNode was null.", (error) =>
      error.metadata = {@initialized}

    @domNode? and (@domNode.offsetHeight > 0 or @domNode.offsetWidth > 0)

  pollDOM: =>
    if @isVisible()
      @sampleBackgroundColors()
      @measureWindowSize()
      @sampleFontStyling()
      @overlayManager?.measureOverlays()

  # Measure explicitly-styled height and width and relay them to the model. If
  # these values aren't explicitly styled, we assume the editor is unconstrained
  # and use the scrollHeight / scrollWidth as its height and width in
  # calculations.
  measureDimensions: ->
    # If we don't assign autoHeight explicitly, we try to automatically disable
    # auto-height in certain circumstances. This is legacy behavior that we
    # would rather not implement, but we can't remove it without risking
    # breakage currently.
    unless @editor.autoHeight?
      {position, top, bottom} = getComputedStyle(@hostElement)
      hasExplicitTopAndBottom = (position is 'absolute' and top isnt 'auto' and bottom isnt 'auto')
      hasInlineHeight = @hostElement.style.height.length > 0

      if hasInlineHeight or hasExplicitTopAndBottom
        if @presenter.autoHeight
          @presenter.setAutoHeight(false)
          if hasExplicitTopAndBottom
            Grim.deprecate("""
              Assigning editor #{@editor.id}'s height explicitly via `position: 'absolute'` and an assigned `top` and `bottom` implicitly assigns the `autoHeight` property to false on the editor.
              This behavior is deprecated and will not be supported in the future. Please explicitly assign `autoHeight` on this editor.
            """)
          else if hasInlineHeight
            Grim.deprecate("""
              Assigning editor #{@editor.id}'s height explicitly via an inline style implicitly assigns the `autoHeight` property to false on the editor.
              This behavior is deprecated and will not be supported in the future. Please explicitly assign `autoHeight` on this editor.
            """)
      else
        @presenter.setAutoHeight(true)

    if @presenter.autoHeight
      @presenter.setExplicitHeight(null)
    else if @hostElement.offsetHeight > 0
      @presenter.setExplicitHeight(@hostElement.offsetHeight)

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
      @clearPoolAfterUpdate = true
      @measureLineHeightAndDefaultCharWidth()
      @invalidateMeasurements()

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
    @linesComponent.lineNodeForScreenRow(screenRow)

  lineNumberNodeForScreenRow: (screenRow) ->
    tileRow = @presenter.tileForRow(screenRow)
    gutterComponent = @gutterContainerComponent.getLineNumberGutterComponent()
    tileComponent = gutterComponent.getComponentForTile(tileRow)

    tileComponent?.lineNumberNodeForScreenRow(screenRow)

  tileNodesForLines: ->
    @linesComponent.getTiles()

  tileNodesForLineNumbers: ->
    gutterComponent = @gutterContainerComponent.getLineNumberGutterComponent()
    gutterComponent.getTiles()

  screenRowForNode: (node) ->
    while node?
      if screenRow = node.dataset?.screenRow
        return parseInt(screenRow)
      node = node.parentElement
    null

  getFontSize: ->
    parseInt(getComputedStyle(@getTopmostDOMNode()).fontSize)

  setFontSize: (fontSize) ->
    @getTopmostDOMNode().style.fontSize = fontSize + 'px'
    @sampleFontStyling()
    @invalidateMeasurements()

  getFontFamily: ->
    getComputedStyle(@getTopmostDOMNode()).fontFamily

  setFontFamily: (fontFamily) ->
    @getTopmostDOMNode().style.fontFamily = fontFamily
    @sampleFontStyling()
    @invalidateMeasurements()

  setLineHeight: (lineHeight) ->
    @getTopmostDOMNode().style.lineHeight = lineHeight
    @sampleFontStyling()
    @invalidateMeasurements()

  invalidateMeasurements: ->
    @linesYardstick.invalidateCache()
    @presenter.measurementsChanged()

  screenPositionForMouseEvent: (event, linesClientRect) ->
    pixelPosition = @pixelPositionForMouseEvent(event, linesClientRect)
    @screenPositionForPixelPosition(pixelPosition)

  pixelPositionForMouseEvent: (event, linesClientRect) ->
    {clientX, clientY} = event

    linesClientRect ?= @linesComponent.getDomNode().getBoundingClientRect()
    top = clientY - linesClientRect.top + @presenter.getRealScrollTop()
    left = clientX - linesClientRect.left + @presenter.getRealScrollLeft()
    bottom = linesClientRect.top + @presenter.getRealScrollTop() + linesClientRect.height - clientY
    right = linesClientRect.left + @presenter.getRealScrollLeft() + linesClientRect.width - clientX

    {top, left, bottom, right}

  getGutterWidth: ->
    @presenter.getGutterWidth()

  getModel: ->
    @editor

  isInputEnabled: -> @inputEnabled

  setInputEnabled: (@inputEnabled) -> @inputEnabled

  setContinuousReflow: (continuousReflow) ->
    @presenter.setContinuousReflow(continuousReflow)

  updateParentViewFocusedClassIfNeeded: ->
    if @oldState.focused isnt @newState.focused
      @hostElement.classList.toggle('is-focused', @newState.focused)
      @oldState.focused = @newState.focused

  updateParentViewMiniClass: ->
    @hostElement.classList.toggle('mini', @editor.isMini())
