React = require 'react'
{div, span} = require 'reactionary'
{debounce} = require 'underscore-plus'

GutterComponent = require './gutter-component'
EditorScrollViewComponent = require './editor-scroll-view-component'
ScrollbarComponent = require './scrollbar-component'
SubscriberMixin = require './subscriber-mixin'

module.exports =
EditorCompont = React.createClass
  displayName: 'EditorComponent'
  mixins: [SubscriberMixin]

  pendingScrollTop: null
  pendingScrollLeft: null
  selectOnMouseMove: false


  render: ->
    {focused, fontSize, lineHeight, fontFamily, showIndentGuide} = @state
    {editor, cursorBlinkPeriod, cursorBlinkResumeDelay} = @props
    visibleRowRange = @getVisibleRowRange()

    className = 'editor react'
    className += ' is-focused' if focused

    div className: className, style: {fontSize, lineHeight, fontFamily}, tabIndex: -1, onFocus: @onFocus,
      GutterComponent({editor, visibleRowRange})

      EditorScrollViewComponent {
        ref: 'scrollView', editor, visibleRowRange, @onInputFocused, @onInputBlurred
        cursorBlinkPeriod, cursorBlinkResumeDelay, showIndentGuide, fontSize, fontFamily, lineHeight
      }

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

  getInitialState: -> {}

  getDefaultProps: ->
    cursorBlinkPeriod: 800
    cursorBlinkResumeDelay: 200

  componentDidMount: ->
    @props.editor.manageScrollPosition = true

    @listenForDOMEvents()
    @listenForCommands()
    @observeEditor()
    @observeConfig()

    @props.editor.setVisible(true)

  componentWillUnmount: ->
    @getDOMNode().removeEventListener 'mousewheel', @onMouseWheel
    @stopBlinkingCursors()

  componentDidUpdate: ->
    @props.parentView.trigger 'editor:display-updated'

  observeEditor: ->
    {editor} = @props
    @subscribe editor, 'screen-lines-changed', @onScreenLinesChanged
    @subscribe editor, 'selection-added', @onSelectionAdded
    @subscribe editor, 'selection-removed', @onSelectionAdded
    @subscribe editor.$scrollTop.changes, @requestUpdate
    @subscribe editor.$scrollLeft.changes, @requestUpdate
    @subscribe editor.$height.changes, @requestUpdate
    @subscribe editor.$width.changes, @requestUpdate
    @subscribe editor.$defaultCharWidth.changes, @requestUpdate
    @subscribe editor.$lineHeight.changes, @requestUpdate

  listenForDOMEvents: ->
    @getDOMNode().addEventListener 'mousewheel', @onMouseWheel

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
    @setState({fontSize})

  setLineHeight: (lineHeight) ->
    @setState({lineHeight})

  setFontFamily: (fontFamily) ->
    @setState({fontFamily})

  setShowIndentGuide: (showIndentGuide) ->
    @setState({showIndentGuide})

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

  onScreenLinesChanged: ({start, end}) ->
    {editor} = @props
    @requestUpdate() if editor.intersectsVisibleRowRange(start, end + 1) # TODO: Use closed-open intervals for change events

  onSelectionAdded: (selection) ->
    {editor} = @props
    @requestUpdate() if editor.selectionIntersectsVisibleRowRange(selection)

  onSelectionRemoved: (selection) ->
    {editor} = @props
    @requestUpdate() if editor.selectionIntersectsVisibleRowRange(selection)

  getVisibleRowRange: ->
    visibleRowRange = @props.editor.getVisibleRowRange()
    if @visibleRowOverrides?
      visibleRowRange[0] = Math.min(visibleRowRange[0], @visibleRowOverrides[0])
      visibleRowRange[1] = Math.max(visibleRowRange[1], @visibleRowOverrides[1])
    visibleRowRange

  clearVisibleRowOverrides: ->
    @visibleRowOverrides = null
    @forceUpdate()

  clearVisibleRowOverridesAfterDelay: null

  requestUpdate: ->
    @forceUpdate()

  updateModelDimensions: ->
    @refs.scrollView.updateModelDimensions()
