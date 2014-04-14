React = require 'react'
ReactUpdates = require 'react/lib/ReactUpdates'
{div, span} = require 'reactionary'
{$$} = require 'space-pen'
{debounce, multiplyString} = require 'underscore-plus'

GutterComponent = require './gutter-component'
InputComponent = require './input-component'
ScrollbarComponent = require './scrollbar-component'
SelectionComponent = require './selection-component'
CursorComponent = require './cursor-component'
SubscriberMixin = require './subscriber-mixin'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}

module.exports =
EditorCompont = React.createClass
  pendingScrollTop: null
  pendingScrollLeft: null
  selectOnMouseMove: false

  statics: {DummyLineNode}

  mixins: [SubscriberMixin]

  render: ->
    {fontSize, lineHeight, fontFamily, focused} = @state
    {editor} = @props
    visibleRowRange = @getVisibleRowRange()

    className = 'editor react'
    className += ' is-focused' if focused

    div className: className, tabIndex: -1, style: {fontSize, lineHeight, fontFamily},
      GutterComponent({editor, visibleRowRange})
      div className: 'scroll-view', ref: 'scrollView',
        InputComponent
          ref: 'input'
          className: 'hidden-input'
          style: @getHiddenInputPosition()
          onInput: @onInput
          onFocus: @onInputFocused
          onBlur: @onInputBlurred
        @renderScrollViewContent()

      ScrollbarComponent
        ref: 'verticalScrollbar'
        className: 'vertical-scrollbar'
        orientation: 'vertical'
        onScroll: @onVerticalScroll
        scrollTop: editor.getScrollTop()
        scrollHeight: editor.getScrollHeight()

      ScrollbarComponent
        ref: 'horizontalScrollbar'
        className: 'horizontal-scrollbar'
        orientation: 'horizontal'
        onScroll: @onHorizontalScroll
        scrollLeft: editor.getScrollLeft()
        scrollWidth: editor.getScrollWidth()

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

  renderScrollViewContent: ->
    {editor} = @props
    style =
      height: editor.getScrollHeight()
      WebkitTransform: "translate(#{-editor.getScrollLeft()}px, #{-editor.getScrollTop()}px)"

    div {className: 'scroll-view-content', style, @onMouseDown},
      @renderCursors()
      @renderVisibleLines()
      @renderUnderlayer()

  renderVisibleLines: ->
    {editor} = @props
    {showIndentGuide} = @state
    [startRow, endRow] = @getVisibleRowRange()
    lineHeightInPixels = editor.getLineHeight()
    precedingHeight = startRow * lineHeightInPixels
    followingHeight = (editor.getScreenLineCount() - endRow) * lineHeightInPixels

    div className: 'lines', ref: 'lines', [
      div className: 'spacer', key: 'top-spacer', style: {height: precedingHeight}
      (for tokenizedLine in @props.editor.linesForScreenRows(startRow, endRow - 1)
        LineComponent({tokenizedLine, showIndentGuide, key: tokenizedLine.id}))...
      div className: 'spacer', key: 'bottom-spacer', style: {height: followingHeight}
    ]

  renderCursors: ->
    {editor} = @props
    {blinkCursorsOff} = @state

    for selection in editor.getSelections() when editor.selectionIntersectsVisibleRowRange(selection)
      CursorComponent(cursor: selection.cursor, blinkOff: blinkCursorsOff)

  renderUnderlayer: ->
    {editor} = @props

    div className: 'underlayer',
      for selection in editor.getSelections() when editor.selectionIntersectsVisibleRowRange(selection)
        SelectionComponent({selection})

  getVisibleRowRange: ->
    visibleRowRange = @props.editor.getVisibleRowRange()
    if @visibleRowOverrides?
      visibleRowRange[0] = Math.min(visibleRowRange[0], @visibleRowOverrides[0])
      visibleRowRange[1] = Math.max(visibleRowRange[1], @visibleRowOverrides[1])
    visibleRowRange

  getInitialState: -> {}

  getDefaultProps: ->
    cursorBlinkPeriod: 800
    cursorBlinkResumeDelay: 200

  componentDidMount: ->
    @measuredLines = new WeakSet

    @props.editor.manageScrollPosition = true

    @listenForDOMEvents()
    @listenForCommands()
    @observeEditor()
    @observeConfig()
    @startBlinkingCursors()

    @updateAllDimensions()
    @props.editor.setVisible(true)

  componentWillUnmount: ->
    @getDOMNode().removeEventListener 'mousewheel', @onMouseWheel
    @stopBlinkingCursors()

  componentDidUpdate: ->
    @measureNewLines()
    @props.parentView.trigger 'editor:display-updated'

  observeEditor: ->
    {editor} = @props
    @subscribe editor, 'screen-lines-changed', @onScreenLinesChanged
    @subscribe editor, 'selection-added', @onSelectionAdded
    @subscribe editor, 'selection-removed', @onSelectionAdded
    @subscribe editor, 'cursors-moved', @pauseCursorBlinking
    @subscribe editor.$scrollTop.changes, @requestUpdate
    @subscribe editor.$scrollLeft.changes, @requestUpdate
    @subscribe editor.$height.changes, @requestUpdate
    @subscribe editor.$width.changes, @requestUpdate
    @subscribe editor.$defaultCharWidth.changes, @requestUpdate
    @subscribe editor.$lineHeight.changes, @requestUpdate

  listenForDOMEvents: ->
    @getDOMNode().addEventListener 'mousewheel', @onMouseWheel
    @getDOMNode().addEventListener 'focus', @onFocus
    @refs.scrollView.getDOMNode().addEventListener 'overflowchanged', @onOverflowChanged

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
      # 'editor:consolidate-selections': (event) => @consolidateSelections(event)
      'editor:backspace-to-beginning-of-word': => editor.backspaceToBeginningOfWord()
      'editor:backspace-to-beginning-of-line': => editor.backspaceToBeginningOfLine()
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
        # 'core:page-down': => @pageDown()
        # 'core:page-up': => @pageUp()
        # 'editor:scroll-to-cursor': => @scrollToCursorPosition()

  addCommandListeners: (listenersByCommandName) ->
    {parentView} = @props

    for command, listener of listenersByCommandName
      parentView.command command, listener

  observeConfig: ->
    @subscribe atom.config.observe 'editor.fontFamily', @setFontFamily
    @subscribe atom.config.observe 'editor.fontSize', @setFontSize
    @subscribe atom.config.observe 'editor.showIndentGuide', @setShowIndentGuide

  setFontSize: (fontSize) ->
    @clearScopedCharWidths()
    @setState({fontSize})
    @updateLineDimensions()

  setLineHeight: (lineHeight) ->
    @setState({lineHeight})

  setFontFamily: (fontFamily) ->
    @clearScopedCharWidths()
    @setState({fontFamily})
    @updateLineDimensions()

  setShowIndentGuide: (showIndentGuide) ->
    @setState({showIndentGuide})

  onFocus: ->
    @refs.input.focus()

  onInputFocused: ->
    @setState(focused: true)

  onInputBlurred: ->
    @setState(focused: false) unless document.activeElement is @getDOMNode()

  onInput: (char, replaceLastCharacter) ->
    {editor} = @props

    ReactUpdates.batchedUpdates ->
      editor.selectLeft() if replaceLastCharacter
      editor.insertText(char)

  onVerticalScroll: ->
    scrollTop = @refs.verticalScrollbar.getDOMNode().scrollTop
    return if @props.editor.getScrollTop() is scrollTop

    animationFramePending = @pendingScrollTop?
    @pendingScrollTop = scrollTop
    unless animationFramePending
      requestAnimationFrame =>
        @props.editor.setScrollTop(@pendingScrollTop)
        @pendingScrollTop = null

  onHorizontalScroll: ->
    scrollLeft = @refs.horizontalScrollbar.getDOMNode().scrollLeft
    return if @props.editor.getScrollLeft() is scrollLeft

    animationFramePending = @pendingScrollLeft?
    @pendingScrollLeft = scrollLeft
    unless animationFramePending
      requestAnimationFrame =>
        @props.editor.setScrollLeft(@pendingScrollLeft)
        @pendingScrollLeft = null

  onMouseWheel: (event) ->
    # To preserve velocity scrolling, delay removal of the event's target until
    # after mousewheel events stop being fired. Removing the target before then
    # will cause scrolling to stop suddenly.
    @visibleRowOverrides = @getVisibleRowRange()
    @clearVisibleRowOverridesAfterDelay ?= debounce(@clearVisibleRowOverrides, 100)
    @clearVisibleRowOverridesAfterDelay()

    # Only scroll in one direction at a time
    {wheelDeltaX, wheelDeltaY} = event
    if Math.abs(wheelDeltaX) > Math.abs(wheelDeltaY)
      @refs.horizontalScrollbar.getDOMNode().scrollLeft -= wheelDeltaX
    else
      @refs.verticalScrollbar.getDOMNode().scrollTop -= wheelDeltaY

    event.preventDefault()

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

  clearVisibleRowOverrides: ->
    @visibleRowOverrides = null
    @forceUpdate()

  clearVisibleRowOverridesAfterDelay: null

  onOverflowChanged: ->
    {editor} = @props
    {height, width} = @measureScrollViewDimensions()

    if height isnt editor.getHeight()
      editor.setHeight(height)
      update = true

    if width isnt editor.getWidth()
      editor.setWidth(width)
      update = true

    @requestUpdate() if update

  onScreenLinesChanged: ({start, end}) ->
    {editor} = @props
    @requestUpdate() if editor.intersectsVisibleRowRange(start, end + 1) # TODO: Use closed-open intervals for change events

  onSelectionAdded: (selection) ->
    {editor} = @props
    @requestUpdate() if editor.selectionIntersectsVisibleRowRange(selection)

  onSelectionRemoved: (selection) ->
    {editor} = @props
    @requestUpdate() if editor.selectionIntersectsVisibleRowRange(selection)

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

  requestUpdate: ->
    @forceUpdate()

  updateAllDimensions: ->
    {height, width} = @measureScrollViewDimensions()
    {lineHeightInPixels, charWidth} = @measureLineDimensions()
    {editor} = @props

    editor.setHeight(height)
    editor.setWidth(width)
    editor.setLineHeight(lineHeightInPixels)
    editor.setDefaultCharWidth(charWidth)

  updateLineDimensions: ->
    {lineHeightInPixels, charWidth} = @measureLineDimensions()
    {editor} = @props

    editor.setLineHeight(lineHeightInPixels)
    editor.setDefaultCharWidth(charWidth)

  measureScrollViewDimensions: ->
    scrollViewNode = @refs.scrollView.getDOMNode()
    {height: scrollViewNode.clientHeight, width: scrollViewNode.clientWidth}

  measureLineDimensions: ->
    linesNode = @refs.lines.getDOMNode()
    linesNode.appendChild(DummyLineNode)
    lineHeightInPixels = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    linesNode.removeChild(DummyLineNode)
    {lineHeightInPixels, charWidth}

  measureNewLines: ->
    [visibleStartRow, visibleEndRow] = @getVisibleRowRange()
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
