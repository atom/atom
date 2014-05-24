React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{debounce} = require 'underscore-plus'

InputComponent = require './input-component'
LinesComponent = require './lines-component'
CursorsComponent = require './cursors-component'
SelectionsComponent = require './selections-component'

module.exports =
EditorScrollViewComponent = React.createClass
  displayName: 'EditorScrollViewComponent'

  measurementPending: false
  overflowChangedEventsPaused: false
  overflowChangedWhilePaused: false

  render: ->
    {editor, fontSize, fontFamily, lineHeight, lineHeightInPixels, showIndentGuide, invisibles, visible} = @props
    {renderedRowRange, pendingChanges, scrollTop, scrollLeft, scrollHeight, scrollWidth, scrollViewHeight, scrollingVertically, mouseWheelScreenRow} = @props
    {selectionChanged, selectionAdded, cursorBlinkPeriod, cursorBlinkResumeDelay, cursorsMoved, onInputFocused, onInputBlurred} = @props

    if @isMounted()
      inputStyle = @getHiddenInputPosition()
      inputStyle.WebkitTransform = 'translateZ(0)'

    div className: 'scroll-view', onMouseDown: @onMouseDown,
      InputComponent
        ref: 'input'
        className: 'hidden-input'
        style: inputStyle
        onInput: @onInput
        onFocus: onInputFocused
        onBlur: onInputBlurred

      CursorsComponent({editor, scrollTop, scrollLeft, cursorsMoved, selectionAdded, cursorBlinkPeriod, cursorBlinkResumeDelay})
      LinesComponent {
        ref: 'lines', editor, fontSize, fontFamily, lineHeight, lineHeightInPixels,
        showIndentGuide, renderedRowRange, pendingChanges, scrollTop, scrollLeft, scrollingVertically,
        selectionChanged, scrollHeight, scrollWidth, mouseWheelScreenRow, invisibles,
        visible, scrollViewHeight
      }

  componentDidMount: ->
    node = @getDOMNode()

    node.addEventListener 'overflowchanged', @onOverflowChanged
    window.addEventListener('resize', @onWindowResize)

    node.addEventListener 'scroll', ->
      console.warn "EditorScrollView scroll position changed, and it shouldn't have. If you can reproduce this, please report it."
      node.scrollTop = 0
      node.scrollLeft = 0

    @measureHeightAndWidth()

  componentDidUnmount: ->
    window.removeEventListener('resize', @onWindowResize)

  componentDidUpdate: ->
    @pauseOverflowChangedEvents()

  onOverflowChanged: ->
    if @overflowChangedEventsPaused
      @overflowChangedWhilePaused = true
    else
      @requestMeasurement()

  onWindowResize: ->
    @requestMeasurement()

  pauseOverflowChangedEvents: ->
    @overflowChangedEventsPaused = true
    @resumeOverflowChangedEventsAfterDelay ?= debounce(@resumeOverflowChangedEvents, 500)
    @resumeOverflowChangedEventsAfterDelay()

  resumeOverflowChangedEvents: ->
    if @overflowChangedWhilePaused
      @overflowChangedWhilePaused = false
      @requestMeasurement()

  resumeOverflowChangedEventsAfterDelay: null

  requestMeasurement: ->
    return if @measurementPending

    @measurementPending = true
    requestAnimationFrame =>
      @measurementPending = false
      @measureHeightAndWidth()

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

  screenPositionForMouseEvent: (event) ->
    pixelPosition = @pixelPositionForMouseEvent(event)
    @props.editor.screenPositionForPixelPosition(pixelPosition)

  pixelPositionForMouseEvent: (event) ->
    {editor} = @props
    {clientX, clientY} = event

    editorClientRect = @getDOMNode().getBoundingClientRect()
    top = clientY - editorClientRect.top + editor.getScrollTop()
    left = clientX - editorClientRect.left + editor.getScrollLeft()
    {top, left}

  getHiddenInputPosition: ->
    {editor, focused} = @props
    return {top: 0, left: 0} unless @isMounted() and focused and editor.getCursor()?

    {top, left, height, width} = editor.getCursor().getPixelRect()
    width = 2 if width is 0 # Prevent autoscroll at the end of longest line
    top -= editor.getScrollTop()
    left -= editor.getScrollLeft()
    top = Math.max(0, Math.min(editor.getHeight() - height, top))
    left = Math.max(0, Math.min(editor.getWidth() - width, left))
    {top, left}

  # Measure explicitly-styled height and width and relay them to the model. If
  # these values aren't explicitly styled, we assume the editor is unconstrained
  # and use the scrollHeight / scrollWidth as its height and width in
  # calculations.
  measureHeightAndWidth: ->
    return unless @isMounted()

    {editor} = @props
    node = @getDOMNode()
    editorNode = node.parentNode
    {position} = getComputedStyle(editorNode)
    {width, height} = editorNode.style

    if position is 'absolute' or height
      clientHeight =  node.clientHeight
      editor.setHeight(clientHeight) if clientHeight > 0

    if position is 'absolute' or width
      clientWidth = node.clientWidth
      editor.setWidth(clientWidth) if clientWidth > 0

  focus: ->
    @refs.input.focus()

  lineNodeForScreenRow: (screenRow) -> @refs.lines.lineNodeForScreenRow(screenRow)
