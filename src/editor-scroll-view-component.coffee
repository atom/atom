React = require 'react'
ReactUpdates = require 'react/lib/ReactUpdates'
{div, span} = require 'reactionary'
{debounce, isEqual, multiplyString, pick} = require 'underscore-plus'
{$$} = require 'space-pen'

InputComponent = require './input-component'
CursorComponent = require './cursor-component'
SelectionComponent = require './selection-component'
SubscriberMixin = require './subscriber-mixin'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}

module.exports =
EditorScrollViewComponent = React.createClass
  mixins: [SubscriberMixin]

  render: ->
    {onInputFocused, onInputBlurred} = @props

    div className: 'scroll-view', ref: 'scrollView',
      InputComponent
        ref: 'input'
        className: 'hidden-input'
        style: @getHiddenInputPosition()
        onInput: @onInput
        onFocus: onInputFocused
        onBlur: onInputBlurred
      @renderScrollViewContent()

  renderScrollViewContent: ->
    {editor} = @props
    style =
      height: editor.getScrollHeight()
      WebkitTransform: "translate(#{-editor.getScrollLeft()}px, #{-editor.getScrollTop()}px)"

    div {className: 'scroll-view-content', style, @onMouseDown},
      @renderCursors()
      @renderVisibleLines()
      @renderUnderlayer()

  renderCursors: ->
    {editor} = @props
    {blinkCursorsOff} = @state

    for selection in editor.getSelections() when editor.selectionIntersectsVisibleRowRange(selection)
      CursorComponent(cursor: selection.cursor, blinkOff: blinkCursorsOff)

  renderVisibleLines: ->
    {editor, visibleRowRange} = @props
    {showIndentGuide} = @props
    [startRow, endRow] = visibleRowRange
    lineHeightInPixels = editor.getLineHeight()
    precedingHeight = startRow * lineHeightInPixels
    followingHeight = (editor.getScreenLineCount() - endRow) * lineHeightInPixels

    div className: 'lines', ref: 'lines', [
      div className: 'spacer', key: 'top-spacer', style: {height: precedingHeight}
      (for tokenizedLine in @props.editor.linesForScreenRows(startRow, endRow - 1)
        LineComponent({tokenizedLine, showIndentGuide, key: tokenizedLine.id}))...
      div className: 'spacer', key: 'bottom-spacer', style: {height: followingHeight}
    ]

  renderUnderlayer: ->
    {editor} = @props

    div className: 'underlayer',
      for selection in editor.getSelections() when editor.selectionIntersectsVisibleRowRange(selection)
        SelectionComponent({selection})

  getInitialState: ->
    blinkCursorsOff: false

  componentDidMount: ->
    @measuredLines = new WeakSet

    @getDOMNode().addEventListener 'overflowchanged', @onOverflowChanged

    @subscribe @props.editor, 'cursors-moved', @pauseCursorBlinking


    @updateAllDimensions()
    @startBlinkingCursors()

  componentDidUpdate: (prevProps) ->
    unless isEqual(pick(prevProps, 'fontSize', 'fontFamily', 'lineHeight'), pick(@props, 'fontSize', 'fontFamily', 'lineHeight'))
      @updateLineDimensions()

    unless isEqual(pick(prevProps, 'fontSize', 'fontFamily'), pick(@props, 'fontSize', 'fontFamily'))
      @clearScopedCharWidths()

    @measureNewLines()

  focus: ->
    @refs.input.focus()

  startBlinkingCursors: ->
    @cursorBlinkIntervalHandle = setInterval(@toggleCursorBlink, @props.cursorBlinkPeriod / 2)

  stopBlinkingCursors: ->
    clearInterval(@cursorBlinkIntervalHandle)
    @setState(blinkCursorsOff: false)

  toggleCursorBlink: -> @setState(blinkCursorsOff: not @state.blinkCursorsOff)

  pauseCursorBlinking: ->
    @stopBlinkingCursors()
    @startBlinkingCursorsAfterDelay ?= debounce(@startBlinkingCursors, @props.cursorBlinkResumeDelay)
    @startBlinkingCursorsAfterDelay()

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

  onOverflowChanged: ->
    {editor} = @props
    {height, width} = @measureScrollViewDimensions()
    editor.setHeight(height)
    editor.setWidth(width)

  updateAllDimensions: ->
    @updateScrollViewDimensions()
    @updateLineDimensions()

  updateScrollViewDimensions: ->
    {editor} = @props
    {height, width} = @measureScrollViewDimensions()
    editor.setHeight(height)
    editor.setWidth(width)

  updateLineDimensions: ->
    {editor} = @props
    {lineHeightInPixels, charWidth} = @measureLineDimensions()
    editor.setLineHeight(lineHeightInPixels)
    editor.setDefaultCharWidth(charWidth)

  measureScrollViewDimensions: ->
    node = @getDOMNode()
    {height: node.clientHeight, width: node.clientWidth}

  measureLineDimensions: ->
    linesNode = @refs.lines.getDOMNode()
    linesNode.appendChild(DummyLineNode)
    lineHeightInPixels = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    linesNode.removeChild(DummyLineNode)
    {lineHeightInPixels, charWidth}

  measureNewLines: ->
    [visibleStartRow, visibleEndRow] = @props.visibleRowRange
    linesNode = @refs.lines.getDOMNode()

    for tokenizedLine, i in @props.editor.linesForScreenRows(visibleStartRow, visibleEndRow - 1)
      unless @measuredLines.has(tokenizedLine)
        lineNode = linesNode.children[i + 1]
        @measureCharactersInLine(tokenizedLine, lineNode)

  measureCharactersInLine: (tokenizedLine, lineNode) ->
    {editor} = @props
    iterator = document.createNodeIterator(lineNode, NodeFilter.SHOW_TEXT, AcceptFilter)
    rangeForMeasurement = document.createRange()

    for {value, scopes} in tokenizedLine.tokens
      textNode = iterator.nextNode()
      charWidths = editor.getScopedCharWidths(scopes)
      for char, i in value
        unless charWidths[char]?
          rangeForMeasurement.setStart(textNode, i)
          rangeForMeasurement.setEnd(textNode, i + 1)
          charWidth = rangeForMeasurement.getBoundingClientRect().width
          editor.setScopedCharWidth(scopes, char, charWidth)

    @measuredLines.add(tokenizedLine)

  clearScopedCharWidths: ->
    @measuredLines.clear()
    @props.editor.clearScopedCharWidths()

LineComponent = React.createClass
  render: ->
    div className: 'line', dangerouslySetInnerHTML: {__html: @buildInnerHTML()}

  buildInnerHTML: ->
    if @props.tokenizedLine.text.length is 0
      @buildEmptyLineHTML()
    else
      @buildScopeTreeHTML(@props.tokenizedLine.getScopeTree())

  buildEmptyLineHTML: ->
    {showIndentGuide, tokenizedLine} = @props
    {indentLevel, tabLength} = tokenizedLine

    if showIndentGuide and indentLevel > 0
      indentSpan = "<span class='indent-guide'>#{multiplyString(' ', tabLength)}</span>"
      multiplyString(indentSpan, indentLevel + 1)
    else
      "&nbsp;"

  buildScopeTreeHTML: (scopeTree) ->
    if scopeTree.children?
      html = "<span class='#{scopeTree.scope.replace(/\./g, ' ')}'>"
      html += @buildScopeTreeHTML(child) for child in scopeTree.children
      html += "</span>"
      html
    else
      "<span>#{scopeTree.getValueAsHtml({hasIndentGuide: @props.showIndentGuide})}</span>"

  shouldComponentUpdate: (newProps, newState) ->
    newProps.showIndentGuide isnt @props.showIndentGuide
