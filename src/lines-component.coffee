_ = require 'underscore-plus'
React = require 'react-atom-fork'
{div, span} = require 'reactionary-atom-fork'
{debounce, isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
{$$} = require 'space-pen'

CursorsComponent = require './cursors-component'
HighlightsComponent = require './highlights-component'
OverlayManager = require './overlay-manager'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
WrapperDiv = document.createElement('div')

module.exports =
LinesComponent = React.createClass
  displayName: 'LinesComponent'

  render: ->
    {editor, presenter} = @props
    @oldState ?= {content: {lines: {}}}
    @newState = presenter.state

    {scrollHeight} = @newState
    {scrollWidth, backgroundColor, placeholderText} = @newState.content

    style =
      height: scrollHeight
      width: scrollWidth
      WebkitTransform: @getTransform()
      backgroundColor: backgroundColor

    div {className: 'lines', style},
      div className: 'placeholder-text', placeholderText if placeholderText?
      CursorsComponent {presenter}
      HighlightsComponent {presenter}

  getTransform: ->
    {scrollTop} = @newState
    {scrollLeft} = @newState.content
    {useHardwareAcceleration} = @props

    if useHardwareAcceleration
      "translate3d(#{-scrollLeft}px, #{-scrollTop}px, 0px)"
    else
      "translate(#{-scrollLeft}px, #{-scrollTop}px)"

  componentWillMount: ->
    @measuredLines = new Set
    @lineNodesByLineId = {}
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}
    @renderedDecorationsByLineId = {}

  componentDidMount: ->
    if @props.useShadowDOM
      insertionPoint = document.createElement('content')
      insertionPoint.setAttribute('select', '.overlayer')
      @getDOMNode().appendChild(insertionPoint)

      insertionPoint = document.createElement('content')
      insertionPoint.setAttribute('select', 'atom-overlay')
      @overlayManager = new OverlayManager(@props.hostElement)
      @getDOMNode().appendChild(insertionPoint)
    else
      @overlayManager = new OverlayManager(@getDOMNode())

  componentDidUpdate: ->
    {visible, presenter} = @props

    @removeLineNodes() unless @oldState?.content.indentGuidesVisible is @newState?.content.indentGuidesVisible
    @updateLineNodes()
    @measureCharactersInNewLines() if visible and not presenter.state.scrollingVertically

    @overlayManager?.render(@props)

    @oldState.content.indentGuidesVisible = @newState.content.indentGuidesVisible
    @oldState.content.scrollWidth = @newState.content.scrollWidth

  clearScreenRowCaches: ->
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}

  removeLineNodes: ->
    @removeLineNode(id) for id of @oldState.content.lines

  removeLineNode: (id) ->
    @lineNodesByLineId[id].remove()
    delete @lineNodesByLineId[id]
    delete @lineIdsByScreenRow[@screenRowsByLineId[id]]
    delete @screenRowsByLineId[id]
    delete @oldState.content.lines[id]

  updateLineNodes: ->
    {presenter, mouseWheelScreenRow} = @props

    for id of @oldState.content.lines
      unless @newState.content.lines.hasOwnProperty(id) or mouseWheelScreenRow is @screenRowsByLineId[id]
        @removeLineNode(id)

    newLineIds = null
    newLinesHTML = null

    for id, lineState of @newState.content.lines
      if @oldState.content.lines.hasOwnProperty(id)
        @updateLineNode(id)
      else
        newLineIds ?= []
        newLinesHTML ?= ""
        newLineIds.push(id)
        newLinesHTML += @buildLineHTML(id)
        @screenRowsByLineId[id] = lineState.screenRow
        @lineIdsByScreenRow[lineState.screenRow] = id
      @oldState.content.lines[id] = _.clone(lineState)

    return unless newLineIds?

    WrapperDiv.innerHTML = newLinesHTML
    newLineNodes = toArray(WrapperDiv.children)
    node = @getDOMNode()
    for id, i in newLineIds
      lineNode = newLineNodes[i]
      @lineNodesByLineId[id] = lineNode
      node.appendChild(lineNode)

  buildLineHTML: (id) ->
    {presenter} = @props
    {scrollWidth} = @newState.content
    {screenRow, tokens, text, top, lineEnding, fold, isSoftWrapped, indentLevel, decorationClasses} = @newState.content.lines[id]

    classes = ''
    if decorationClasses?
      for decorationClass in decorationClasses
        classes += decorationClass + ' '
    classes += 'line'

    lineHTML = "<div class=\"#{classes}\" style=\"position: absolute; top: #{top}px; width: #{scrollWidth}px;\" data-screen-row=\"#{screenRow}\">"

    if text is ""
      lineHTML += @buildEmptyLineInnerHTML(id)
    else
      lineHTML += @buildLineInnerHTML(id)

    lineHTML += '<span class="fold-marker"></span>' if fold
    lineHTML += "</div>"
    lineHTML

  buildEmptyLineInnerHTML: (id) ->
    {indentGuidesVisible} = @newState.content
    {indentLevel, tabLength, endOfLineInvisibles} = @newState.content.lines[id]

    if indentGuidesVisible and indentLevel > 0
      invisibleIndex = 0
      lineHTML = ''
      for i in [0...indentLevel]
        lineHTML += "<span class='indent-guide'>"
        for j in [0...tabLength]
          if invisible = endOfLineInvisibles?[invisibleIndex++]
            lineHTML += "<span class='invisible-character'>#{invisible}</span>"
          else
            lineHTML += ' '
        lineHTML += "</span>"

      while invisibleIndex < endOfLineInvisibles?.length
        lineHTML += "<span class='invisible-character'>#{endOfLineInvisibles[invisibleIndex++]}</span>"

      lineHTML
    else
      @buildEndOfLineHTML(id) or '&nbsp;'

  buildLineInnerHTML: (id) ->
    {editor} = @props
    {indentGuidesVisible} = @newState.content
    {tokens, text} = @newState.content.lines[id]
    innerHTML = ""

    scopeStack = []
    firstTrailingWhitespacePosition = text.search(/\s*$/)
    lineIsWhitespaceOnly = firstTrailingWhitespacePosition is 0
    for token in tokens
      innerHTML += @updateScopeStack(scopeStack, token.scopes)
      hasIndentGuide = indentGuidesVisible and (token.hasLeadingWhitespace() or (token.hasTrailingWhitespace() and lineIsWhitespaceOnly))
      innerHTML += token.getValueAsHtml({hasIndentGuide})

    innerHTML += @popScope(scopeStack) while scopeStack.length > 0
    innerHTML += @buildEndOfLineHTML(id)
    innerHTML

  buildEndOfLineHTML: (id) ->
    {endOfLineInvisibles} = @newState.content.lines[id]

    html = ''
    if endOfLineInvisibles?
      for invisible in endOfLineInvisibles
        html += "<span class='invisible-character'>#{invisible}</span>"
    html

  updateScopeStack: (scopeStack, desiredScopeDescriptor) ->
    html = ""

    # Find a common prefix
    for scope, i in desiredScopeDescriptor
      break unless scopeStack[i] is desiredScopeDescriptor[i]

    # Pop scopeDescriptor until we're at the common prefx
    until scopeStack.length is i
      html += @popScope(scopeStack)

    # Push onto common prefix until scopeStack equals desiredScopeDescriptor
    for j in [i...desiredScopeDescriptor.length]
      html += @pushScope(scopeStack, desiredScopeDescriptor[j])

    html

  popScope: (scopeStack) ->
    scopeStack.pop()
    "</span>"

  pushScope: (scopeStack, scope) ->
    scopeStack.push(scope)
    "<span class=\"#{scope.replace(/\.+/g, ' ')}\">"

  updateLineNode: (id) ->
    {scrollWidth} = @newState.content
    {screenRow, top} = @newState.content.lines[id]

    lineNode = @lineNodesByLineId[id]

    newDecorationClasses = @newState.content.lines[id].decorationClasses
    oldDecorationClasses = @oldState.content.lines[id].decorationClasses

    if oldDecorationClasses?
      for decorationClass in oldDecorationClasses
        unless newDecorationClasses? and decorationClass in newDecorationClasses
          lineNode.classList.remove(decorationClass)

    if newDecorationClasses?
      for decorationClass in newDecorationClasses
        unless oldDecorationClasses? and decorationClass in oldDecorationClasses
          lineNode.classList.add(decorationClass)

    lineNode.style.width = scrollWidth + 'px'
    lineNode.style.top = top + 'px'
    lineNode.dataset.screenRow = screenRow
    @screenRowsByLineId[id] = screenRow
    @lineIdsByScreenRow[screenRow] = id

  lineNodeForScreenRow: (screenRow) ->
    @lineNodesByLineId[@lineIdsByScreenRow[screenRow]]

  measureLineHeightAndDefaultCharWidth: ->
    node = @getDOMNode()
    node.appendChild(DummyLineNode)
    lineHeightInPixels = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    node.removeChild(DummyLineNode)

    {editor, presenter} = @props
    presenter.setLineHeight(lineHeightInPixels)
    editor.setLineHeightInPixels(lineHeightInPixels)
    presenter.setBaseCharacterWidth(charWidth)
    editor.setDefaultCharWidth(charWidth)

  remeasureCharacterWidths: ->
    return unless @props.presenter.hasRequiredMeasurements()

    @clearScopedCharWidths()
    @measureCharactersInNewLines()

  measureCharactersInNewLines: ->
    {editor} = @props
    node = @getDOMNode()

    editor.batchCharacterMeasurement =>
      for id, lineState of @oldState.content.lines
        unless @measuredLines.has(id)
          lineNode = @lineNodesByLineId[id]
          @measureCharactersInLine(lineState, lineNode)
      return

  measureCharactersInLine: (tokenizedLine, lineNode) ->
    {editor} = @props
    rangeForMeasurement = null
    iterator = null
    charIndex = 0

    for {value, scopes, hasPairedCharacter} in tokenizedLine.tokens
      charWidths = editor.getScopedCharWidths(scopes)

      valueIndex = 0
      while valueIndex < value.length
        if hasPairedCharacter
          char = value.substr(valueIndex, 2)
          charLength = 2
          valueIndex += 2
        else
          char = value[valueIndex]
          charLength = 1
          valueIndex++

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
          rangeForMeasurement.setEnd(textNode, i + charLength)
          charWidth = rangeForMeasurement.getBoundingClientRect().width
          editor.setScopedCharWidth(scopes, char, charWidth)
          @props.presenter.setScopedCharWidth(scopes, char, charWidth)

        charIndex += charLength

    @measuredLines.add(tokenizedLine.id)

  clearScopedCharWidths: ->
    @measuredLines.clear()
    @props.editor.clearScopedCharWidths()
    @props.presenter.clearScopedCharWidths()
