{React, div, span} = require 'reactionary'
{$$} = require 'space-pencil'

SelectionComponent = require './selection-component'
InputComponent = require './input-component'
CustomEventMixin = require './custom-event-mixin'
SubscriberMixin = require './subscriber-mixin'

DummyLineNode = $$ ->
  @div className: 'line', style: 'position: absolute; visibility: hidden;', -> @span 'x'

module.exports =
EditorCompont = React.createClass
  pendingScrollTop: null

  statics: {DummyLineNode}

  mixins: [CustomEventMixin, SubscriberMixin]

  render: ->
    div className: 'editor',
      div className: 'scroll-view', ref: 'scrollView',
        InputComponent ref: 'hiddenInput', className: 'hidden-input', onInput: @onInput
        @renderScrollableContent()
      div className: 'vertical-scrollbar', ref: 'verticalScrollbar', onScroll: @onVerticalScroll,
        div outlet: 'verticalScrollbarContent', style: {height: @getScrollHeight()}

  renderScrollableContent: ->
    height = @props.editor.getScreenLineCount() * @state.lineHeight
    WebkitTransform = "translateY(#{-@state.scrollTop}px)"

    div className: 'scrollable-content', style: {height, WebkitTransform},
      @renderOverlayer()
      @renderVisibleLines()

  renderOverlayer: ->
    {lineHeight, charWidth} = @state

    div className: 'overlayer',
      for selection in @props.editor.getSelections() when @selectionIntersectsVisibleRowRange(selection)
        SelectionComponent({selection, lineHeight, charWidth})

  renderVisibleLines: ->
    [startRow, endRow] = @getVisibleRowRange()
    precedingHeight = startRow * @state.lineHeight
    followingHeight = (@props.editor.getScreenLineCount() - endRow) * @state.lineHeight

    div className: 'lines', ref: 'lines', [
      div className: 'spacer', key: 'top-spacer', style: {height: precedingHeight}
      (for tokenizedLine in @props.editor.linesForScreenRows(startRow, endRow - 1)
        LineComponent({tokenizedLine, key: tokenizedLine.id}))...
      div className: 'spacer', key: 'bottom-spacer', style: {height: followingHeight}
    ]

  getInitialState: ->
    height: 0
    width: 0
    lineHeight: 0
    scrollTop: 0

  componentDidMount: ->
    @listenForCustomEvents()
    @refs.scrollView.getDOMNode().addEventListener 'mousewheel', @onMousewheel

    {editor} = @props
    @subscribe editor, 'screen-lines-changed', @onScreenLinesChanged
    @subscribe editor, 'selection-added', @onSelectionAdded

    @updateAllDimensions()
    @props.editor.setVisible(true)
    @refs.hiddenInput.focus()

  componentWillUnmount: ->
    @props.editor.off 'screen-lines-changed', @onScreenLinesChanged
    @getDOMNode().removeEventListener 'mousewheel', @onMousewheel

  listenForCustomEvents: ->
    {editor} = @props

    @addCustomEventListeners
      'core:move-left': => editor.moveCursorLeft()
      'core:move-right': => editor.moveCursorRight()
      'core:move-up': => editor.moveCursorUp()
      'core:move-down': => editor.moveCursorDown()

  onVerticalScroll: ->
    animationFramePending = @pendingScrollTop?
    @pendingScrollTop = @refs.verticalScrollbar.getDOMNode().scrollTop
    unless animationFramePending
      requestAnimationFrame =>
        @setState({scrollTop: @pendingScrollTop})
        @pendingScrollTop = null

  onMousewheel: (event) ->
    @refs.verticalScrollbar.getDOMNode().scrollTop -= event.wheelDeltaY
    event.preventDefault()

  onInput: (char, replaceLastChar) ->
    @props.editor.insertText(char)

  onScreenLinesChanged: ({start, end}) ->
    [visibleStart, visibleEnd] = @getVisibleRowRange()
    @forceUpdate() if @intersectsVisibleRowRange(start, end + 1) # TODO: Use closed-open intervals for change events

  onSelectionAdded: (selection) ->
    @forceUpdate() if @selectionIntersectsVisibleRowRange(selection)

  getVisibleRowRange: ->
    return [0, 0] unless @state.lineHeight > 0

    heightInLines = @state.height / @state.lineHeight
    startRow = Math.floor(@state.scrollTop / @state.lineHeight)
    endRow = Math.ceil(startRow + heightInLines)
    [startRow, endRow]

  intersectsVisibleRowRange: (startRow, endRow) ->
    [visibleStart, visibleEnd] = @getVisibleRowRange()
    not (endRow <= visibleStart or visibleEnd <= startRow)

  selectionIntersectsVisibleRowRange: (selection) ->
    {start, end} = selection.getScreenRange()
    @intersectsVisibleRowRange(start.row, end.row + 1)

  getScrollHeight: ->
    @props.editor.getLineCount() * @state.lineHeight

  updateAllDimensions: ->
    {height, width} = @measureScrollViewDimensions()
    {lineHeight, charWidth} = @measureLineDimensions()
    @setState({height, width, lineHeight, charWidth})

  measureScrollViewDimensions: ->
    scrollViewNode = @refs.scrollView.getDOMNode()
    {height: scrollViewNode.clientHeight, width: scrollViewNode.clientWidth}

  measureLineDimensions: ->
    linesNode = @refs.lines.getDOMNode()
    linesNode.appendChild(DummyLineNode)
    lineHeight = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    linesNode.removeChild(DummyLineNode)
    {lineHeight, charWidth}

LineComponent = React.createClass
  render: ->
    div className: 'line', dangerouslySetInnerHTML: {__html: @buildInnerHTML()}

  buildInnerHTML: ->
    if @props.tokenizedLine.text.length is 0
      "<span>&nbsp;</span>"
    else
      @buildScopeTreeHTML(@props.tokenizedLine.getScopeTree())

  buildScopeTreeHTML: (scopeTree) ->
    if scopeTree.children?
      html = "<span class='#{scopeTree.scope.replace(/\./g, ' ')}'>"
      html += @buildScopeTreeHTML(child) for child in scopeTree.children
      html
    else
      "<span>#{scopeTree.value}</span>"

  shouldComponentUpdate: -> false
