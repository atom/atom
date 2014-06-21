_ = require 'underscore-plus'
React = require 'react-atom-fork'
{div, span} = require 'reactionary-atom-fork'
{debounce, isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
{$$} = require 'space-pen'

HighlightsComponent = require './highlights-component'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
WrapperDiv = document.createElement('div')

module.exports =
LinesComponent = React.createClass
  displayName: 'LinesComponent'

  lineGroupSize: 10

  render: ->
    if @isMounted()
      {editor, highlightDecorations, scrollTop, scrollLeft, scrollHeight, scrollWidth} = @props
      {lineHeightInPixels, defaultCharWidth, scrollViewHeight, scopedCharacterWidthsChangeCount} = @props
      style = {}
        # height: Math.max(scrollHeight, scrollViewHeight)
        # width: scrollWidth
        # WebkitTransform: "translate3d(#{-scrollLeft}px, #{-scrollTop}px, 0px)"

    # The lines div must have the 'editor-colors' class so it has an opaque
    # background to avoid sub-pixel anti-aliasing problems on the GPU
    div {className: 'lines', style},
      if @isMounted()
        @renderLineGroups()
          # HighlightsComponent({editor, highlightDecorations, lineHeightInPixels, defaultCharWidth, scopedCharacterWidthsChangeCount}

  renderLineGroups: ->
    {renderedRowRange, pendingChanges, scrollTop, scrollLeft, editor, lineHeightInPixels, showIndentGuide, mini, invisibles} = @props
    [renderedStartRow, renderedEndRow] = renderedRowRange
    renderedStartRow -= renderedStartRow % @lineGroupSize

    for startRow in [renderedStartRow...renderedEndRow] by @lineGroupSize
      ref = startRow
      key = startRow
      endRow = startRow + @lineGroupSize
      LineGroupComponent {
        key, ref, startRow, endRow, pendingChanges, scrollTop, scrollLeft,
        editor, lineHeightInPixels, showIndentGuide, mini, invisibles
      }

  componentWillMount: ->
    @measuredLines = new WeakSet
    @lineNodesByLineId = {}
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}
    @renderedDecorationsByLineId = {}

  shouldComponentUpdate: (newProps) ->
    return true unless isEqualForProperties(newProps, @props,
      'renderedRowRange', 'lineDecorations', 'highlightDecorations', 'lineHeightInPixels', 'defaultCharWidth',
      'scrollTop', 'scrollLeft', 'showIndentGuide', 'scrollingVertically', 'invisibles', 'visible',
      'scrollViewHeight', 'mouseWheelScreenRow', 'scopedCharacterWidthsChangeCount', 'lineWidth'
    )

    {renderedRowRange, pendingChanges} = newProps
    [renderedStartRow, renderedEndRow] = renderedRowRange
    for change in pendingChanges
      return true unless change.end < renderedStartRow or renderedEndRow <= change.start

    false

  componentDidUpdate: (prevProps) ->
    unless isEqualForProperties(prevProps, @props, 'scrollTop', 'scrollLeft')
      @manuallyUpdateLineGroupScrollPositions()

    # {visible, scrollingVertically} = @props
    # @measureCharactersInNewLines() if visible and not scrollingVertically

  manuallyUpdateLineGroupScrollPositions: ->
    {renderedRowRange, scrollTop, scrollLeft} = @props
    [renderedStartRow, renderedEndRow] = renderedRowRange
    renderedStartRow -= renderedStartRow % @lineGroupSize
    for startRow in [renderedStartRow...renderedEndRow] by @lineGroupSize
      @refs[startRow].manuallyUpdateScrollPosition(scrollTop, scrollLeft)

  measureLineHeightAndDefaultCharWidth: ->
    node = @getDOMNode()
    node.appendChild(DummyLineNode)
    lineHeightInPixels = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    node.removeChild(DummyLineNode)

    {editor} = @props
    editor.setLineHeightInPixels(lineHeightInPixels)
    editor.setDefaultCharWidth(charWidth)

  remeasureCharacterWidths: ->
    @clearScopedCharWidths()
    @measureCharactersInNewLines()

  measureCharactersInNewLines: ->
    {editor} = @props
    [visibleStartRow, visibleEndRow] = @props.renderedRowRange
    node = @getDOMNode()

    for tokenizedLine in editor.linesForScreenRows(visibleStartRow, visibleEndRow - 1)
      unless @measuredLines.has(tokenizedLine)
        lineNode = @lineNodesByLineId[tokenizedLine.id]
        @measureCharactersInLine(tokenizedLine, lineNode)

  measureCharactersInLine: (tokenizedLine, lineNode) ->
    {editor} = @props
    rangeForMeasurement = null
    iterator = null
    charIndex = 0

    for {value, scopes}, tokenIndex in tokenizedLine.tokens
      charWidths = editor.getScopedCharWidths(scopes)

      for char in value
        continue if char is '\0'

        unless charWidths[char]?
          unless textNode?
            rangeForMeasurement ?= document.createRange()
            iterator =  document.createNodeIterator(lineNode, NodeFilter.SHOW_TEXT, AcceptFilter)
            textNode = iterator.nextNode()
            textNodeIndex = 0
            nextTextNodeIndex = textNode.textContent.length

          while nextTextNodeIndex <= charIndex
            textNode = iterator.nextNode()
            textNodeIndex = nextTextNodeIndex
            nextTextNodeIndex = textNodeIndex + textNode.textContent.length

          i = charIndex - textNodeIndex
          rangeForMeasurement.setStart(textNode, i)
          rangeForMeasurement.setEnd(textNode, i + 1)
          charWidth = rangeForMeasurement.getBoundingClientRect().width
          editor.setScopedCharWidth(scopes, char, charWidth)

        charIndex++

    @measuredLines.add(tokenizedLine)

  clearScopedCharWidths: ->
    @measuredLines.clear()
    @props.editor.clearScopedCharWidths()


LineGroupComponent = React.createClass
  displayName: "LineGroupComponent"

  render: ->
    {editor, startRow, endRow, showIndentGuide, mini, invisibles} = @props
    style =
      position: 'absolute'
      WebkitTransform: @getTranslation()

    div {className: 'line-group', style},
      for line, i in editor.linesForScreenRows(startRow, endRow - 1)
        screenRow = startRow + i
        LineComponent({key: line.id, line, screenRow, showIndentGuide, mini, invisibles})

  shouldComponentUpdate: (newProps) ->
    {startRow, endRow, pendingChanges} = newProps

    for change in pendingChanges
      return true unless change.end < startRow or change.start >= endRow

    false

  manuallyUpdateScrollPosition: (scrollTop, scrollLeft) ->
    @props.scrollTop = scrollTop
    @props.scrollLeft = scrollLeft
    @getDOMNode().style['-webkit-transform'] = @getTranslation()

  getTranslation: ->
    {startRow, lineHeightInPixels, scrollTop, scrollLeft} = @props
    top = startRow * lineHeightInPixels - scrollTop
    left = -scrollLeft
    "translate3d(#{left}px, #{top}px, 0px)"

LineComponent = React.createClass
  displayName: "LineComponent"

  render: ->
    {screenRow} = @props
    div className: "line", 'data-screen-row': screenRow, dangerouslySetInnerHTML: {__html: @buildInnerHTML()}

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'screenRow', 'lineHeightInPixels', 'showIndentGuide', 'invisibles')

  componentWillUpdate: (newProps) ->
    unless isEqualForProperties(newProps, @props, 'showIndentGuide', 'invisibles')
      @innerHTML = null

  buildInnerHTML: ->
    {line} = @props

    if line.text is ""
      @innerHTML ?= @buildEmptyInnerHTML()
    else
      @innerHTML ?= @buildNonEmptyInnerHTML()

  buildEmptyInnerHTML: ->
    {line, showIndentGuide} = @props
    {indentLevel, tabLength} = line

    if showIndentGuide and indentLevel > 0
      indentSpan = "<span class='indent-guide'>#{multiplyString(' ', tabLength)}</span>"
      multiplyString(indentSpan, indentLevel + 1)
    else
      "&nbsp;"

  buildNonEmptyInnerHTML: ->
    {line, invisibles, mini, showIndentGuide, invisibles} = @props
    {tokens, text} = line
    innerHTML = ""

    scopeStack = []
    firstTrailingWhitespacePosition = text.search(/\s*$/)
    lineIsWhitespaceOnly = firstTrailingWhitespacePosition is 0
    for token in tokens
      innerHTML += @updateScopeStack(scopeStack, token.scopes)
      hasIndentGuide = not mini and showIndentGuide and token.hasLeadingWhitespace or (token.hasTrailingWhitespace and lineIsWhitespaceOnly)
      innerHTML += token.getValueAsHtml({invisibles, hasIndentGuide})

    innerHTML += @popScope(scopeStack) while scopeStack.length > 0
    innerHTML += @buildEndOfLineHTML(line, invisibles)
    innerHTML

  buildEndOfLineHTML: ->
    {line, invisibles, mini} = @props
    return '' if mini or line.isSoftWrapped()

    html = ''
    if invisibles.cr? and line.lineEnding is '\r\n'
      html += "<span class='invisible-character'>#{invisibles.cr}</span>"
    if invisibles.eol?
      html += "<span class='invisible-character'>#{invisibles.eol}</span>"

    html

  updateScopeStack: (scopeStack, desiredScopes) ->
    html = ""

    # Find a common prefix
    for scope, i in desiredScopes
      break unless scopeStack[i]?.scope is desiredScopes[i]

    # Pop scopes until we're at the common prefx
    until scopeStack.length is i
      html += @popScope(scopeStack)

    # Push onto common prefix until scopeStack equals desiredScopes
    for j in [i...desiredScopes.length]
      html += @pushScope(scopeStack, desiredScopes[j])

    html

  popScope: (scopeStack) ->
    scopeStack.pop()
    "</span>"

  pushScope: (scopeStack, scope) ->
    scopeStack.push(scope)
    "<span class=\"#{scope.replace(/\.+/g, ' ')}\">"
