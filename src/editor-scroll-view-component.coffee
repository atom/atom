React = require 'react'
ReactUpdates = require 'react/lib/ReactUpdates'
{div} = require 'reactionary'

InputComponent = require './input-component'
LinesComponent = require './lines-component'
CursorsComponent = require './cursors-component'
SelectionComponent = require './selection-component'

module.exports =
EditorScrollViewComponent = React.createClass
  render: ->
    {editor, fontSize, fontFamily, lineHeight, showIndentGuide, cursorBlinkPeriod, cursorBlinkResumeDelay} = @props
    {visibleRowRange, onInputFocused, onInputBlurred} = @props
    contentStyle =
      height: editor.getScrollHeight()
      WebkitTransform: "translate(#{-editor.getScrollLeft()}px, #{-editor.getScrollTop()}px)"

    div className: 'scroll-view', ref: 'scrollView',
      InputComponent
        ref: 'input'
        className: 'hidden-input'
        style: @getHiddenInputPosition()
        onInput: @onInput
        onFocus: onInputFocused
        onBlur: onInputBlurred

      div className: 'scroll-view-content', style: contentStyle, onMouseDown: @onMouseDown,
        CursorsComponent({editor, cursorBlinkPeriod, cursorBlinkResumeDelay})
        LinesComponent({ref: 'lines', editor, fontSize, fontFamily, lineHeight, visibleRowRange, showIndentGuide})
        @renderUnderlayer()

  renderUnderlayer: ->
    {editor} = @props

    div className: 'underlayer',
      for selection in editor.getSelections() when editor.selectionIntersectsVisibleRowRange(selection)
        SelectionComponent({selection})

  componentDidMount: ->
    @getDOMNode().addEventListener 'overflowchanged', @updateModelDimensions
    @updateModelDimensions()

  focus: ->
    @refs.input.focus()

  getHiddenInputPosition: ->
    {editor} = @props

    if cursor = editor.getCursor()
      cursorRect = cursor.getPixelRect()
      top = cursorRect.top - editor.getScrollTop()
      top = Math.max(0, Math.min(editor.getHeight(), top))
      left = cursorRect.left - editor.getScrollLeft()
      left = Math.max(0, Math.min(editor.getWidth(), left))
    else
      top = 0
      left = 0

    {top, left}

  onInput: (char, replaceLastCharacter) ->
    {editor} = @props

    ReactUpdates.batchedUpdates ->
      editor.selectLeft() if replaceLastCharacter
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

    editorClientRect = @refs.scrollView.getDOMNode().getBoundingClientRect()
    top = clientY - editorClientRect.top + editor.getScrollTop()
    left = clientX - editorClientRect.left + editor.getScrollLeft()
    {top, left}

  updateModelDimensions: ->
    {editor} = @props
    node = @getDOMNode()
    editor.setHeight(node.clientHeight)
    editor.setWidth(node.clientWidth)
