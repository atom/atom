{React, div, span} = require 'reactionary'
{last} = require 'underscore-plus'
{$$} = require 'space-pencil'

DummyLineNode = $$ ->
  @div class: 'line', style: 'position: absolute; visibility: hidden;', -> @span 'x'

module.exports =
React.createClass
  pendingScrollTop: null

  render: ->
    div class: 'editor',
      div class: 'scroll-view', ref: 'scrollView',
        div class: 'overlayer'
        @renderVisibleLines()
      div class: 'vertical-scrollbar', ref: 'verticalScrollbar', onScroll: @onVerticalScroll,
        div outlet: 'verticalScrollbarContent', style: {height: @getScrollHeight()}

  renderVisibleLines: ->
    [startRow, endRow] = @getVisibleRowRange()
    precedingHeight = startRow * @state.lineHeight
    lineCount = @props.editor.getScreenLineCount()
    followingHeight = (lineCount - endRow) * @state.lineHeight

    div class: 'lines', ref: 'lines', style: {WebkitTransform: "translateY(#{-@state.scrollTop}px)"}, [
      div class: 'spacer', key: 'top-spacer', style: {height: precedingHeight}
      (for tokenizedLine in @props.editor.linesForScreenRows(startRow, endRow - 1)
        LineComponent({tokenizedLine, key: tokenizedLine.id}))...
      div class: 'spacer', key: 'bottom-spacer', style: {height: followingHeight}
    ]

  getInitialState: ->
    height: 0
    width: 0
    lineHeight: 0
    scrollTop: 0

  componentDidMount: ->
    @props.editor.on 'screen-lines-changed', @onScreenLinesChanged
    @refs.scrollView.getDOMNode().addEventListener 'mousewheel', @onMousewheel
    @updateAllDimensions()
    @props.editor.setVisible(true)

  componentWillUnmount: ->
    @props.editor.off 'screen-lines-changed', @onScreenLinesChanged
    @getDOMNode().removeEventListener 'mousewheel', @onMousewheel

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

  onScreenLinesChanged: ({start, end}) ->
    [visibleStart, visibleEnd] = @getVisibleRowRange()
    @forceUpdate() unless end < visibleStart or visibleEnd <= start

  getVisibleRowRange: ->
    return [0, 0] unless @state.lineHeight > 0

    heightInLines = @state.height / @state.lineHeight
    startRow = Math.floor(@state.scrollTop / @state.lineHeight)
    endRow = Math.ceil(startRow + heightInLines)
    [startRow, endRow]

  getScrollHeight: ->
    @props.editor.getLineCount() * @state.lineHeight

  updateAllDimensions: ->
    lineHeight = @measureLineHeight()
    {height, width} = @measureScrollViewDimensions()

    @setState({lineHeight, height, width})

  measureScrollViewDimensions: ->
    scrollViewNode = @refs.scrollView.getDOMNode()
    {height: scrollViewNode.clientHeight, width: scrollViewNode.clientWidth}

  measureLineHeight: ->
    linesNode = @refs.lines.getDOMNode()
    linesNode.appendChild(DummyLineNode)
    lineHeight = DummyLineNode.getBoundingClientRect().height
    linesNode.removeChild(DummyLineNode)
    lineHeight

LineComponent = React.createClass
  render: ->
    div class: 'line', dangerouslySetInnerHTML: {__html: @buildInnerHTML()}

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
