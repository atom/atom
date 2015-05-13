_ = require 'underscore-plus'
{toArray} = require 'underscore-plus'
{$$} = require 'space-pen'

CursorsComponent = require './cursors-component'
HighlightsComponent = require './highlights-component'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
WrapperDiv = document.createElement('div')

cloneObject = (object) ->
  clone = {}
  clone[key] = value for key, value of object
  clone

module.exports =
class LinesComponent
  placeholderTextDiv: null

  constructor: ({@presenter, @hostElement, @useShadowDOM, visible}) ->
    @measuredLines = new Set
    @lineNodesByLineId = {}
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}
    @renderedDecorationsByLineId = {}

    @domNode = document.createElement('div')
    @domNode.classList.add('lines')

    @cursorsComponent = new CursorsComponent(@presenter)
    @domNode.appendChild(@cursorsComponent.getDomNode())

    @highlightsComponent = new HighlightsComponent(@presenter)
    @domNode.appendChild(@highlightsComponent.getDomNode())

    if @useShadowDOM
      insertionPoint = document.createElement('content')
      insertionPoint.setAttribute('select', '.overlayer')
      @domNode.appendChild(insertionPoint)

  getDomNode: ->
    @domNode

  updateSync: (state) ->
    @newState = state.content
    @oldState ?= {lines: {}}

    if @newState.scrollHeight isnt @oldState.scrollHeight
      @domNode.style.height = @newState.scrollHeight + 'px'
      @oldState.scrollHeight = @newState.scrollHeight

    if @newState.scrollTop isnt @oldState.scrollTop or @newState.scrollLeft isnt @oldState.scrollLeft
      @domNode.style['-webkit-transform'] = "translate3d(#{-@newState.scrollLeft}px, #{-@newState.scrollTop}px, 0px)"
      @oldState.scrollTop = @newState.scrollTop
      @oldState.scrollLeft = @newState.scrollLeft

    if @newState.backgroundColor isnt @oldState.backgroundColor
      @domNode.style.backgroundColor = @newState.backgroundColor
      @oldState.backgroundColor = @newState.backgroundColor

    if @newState.placeholderText isnt @oldState.placeholderText
      @placeholderTextDiv?.remove()
      if @newState.placeholderText?
        @placeholderTextDiv = document.createElement('div')
        @placeholderTextDiv.classList.add('placeholder-text')
        @placeholderTextDiv.textContent = @newState.placeholderText
        @domNode.appendChild(@placeholderTextDiv)

    @removeLineNodes() unless @oldState.indentGuidesVisible is @newState.indentGuidesVisible
    @updateLineNodes()

    if @newState.scrollWidth isnt @oldState.scrollWidth
      @domNode.style.width = @newState.scrollWidth + 'px'
      @oldState.scrollWidth = @newState.scrollWidth

    @cursorsComponent.updateSync(state)
    @highlightsComponent.updateSync(state)

    @oldState.indentGuidesVisible = @newState.indentGuidesVisible
    @oldState.scrollWidth = @newState.scrollWidth

  removeLineNodes: ->
    @removeLineNode(id) for id of @oldState.lines
    return

  removeLineNode: (id) ->
    @lineNodesByLineId[id].remove()
    delete @lineNodesByLineId[id]
    delete @lineIdsByScreenRow[@screenRowsByLineId[id]]
    delete @screenRowsByLineId[id]
    delete @oldState.lines[id]

  updateLineNodes: ->
    for id of @oldState.lines
      unless @newState.lines.hasOwnProperty(id)
        @removeLineNode(id)

    newLineIds = null
    newLinesHTML = null

    for id, lineState of @newState.lines
      if @oldState.lines.hasOwnProperty(id)
        @updateLineNode(id)
      else
        newLineIds ?= []
        newLinesHTML ?= ""
        newLineIds.push(id)
        newLinesHTML += @buildLineHTML(id)
        @screenRowsByLineId[id] = lineState.screenRow
        @lineIdsByScreenRow[lineState.screenRow] = id
        @oldState.lines[id] = cloneObject(lineState)

    return unless newLineIds?

    WrapperDiv.innerHTML = newLinesHTML
    newLineNodes = _.toArray(WrapperDiv.children)
    for id, i in newLineIds
      lineNode = newLineNodes[i]
      @lineNodesByLineId[id] = lineNode
      @domNode.appendChild(lineNode)

    return

  buildLineHTML: (id) ->
    {scrollWidth} = @newState
    {screenRow, tokens, text, top, lineEnding, fold, isSoftWrapped, indentLevel, decorationClasses} = @newState.lines[id]

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
    {indentGuidesVisible} = @newState
    {indentLevel, tabLength, endOfLineInvisibles} = @newState.lines[id]

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
    {indentGuidesVisible} = @newState
    {tokens, text, isOnlyWhitespace} = @newState.lines[id]
    innerHTML = ""

    scopeStack = []
    for token in tokens
      innerHTML += @updateScopeStack(scopeStack, token.scopes)
      hasIndentGuide = indentGuidesVisible and (token.hasLeadingWhitespace() or (token.hasTrailingWhitespace() and isOnlyWhitespace))
      innerHTML += token.getValueAsHtml({hasIndentGuide})

    innerHTML += @popScope(scopeStack) while scopeStack.length > 0
    innerHTML += @buildEndOfLineHTML(id)
    innerHTML

  buildEndOfLineHTML: (id) ->
    {endOfLineInvisibles} = @newState.lines[id]

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
    oldLineState = @oldState.lines[id]
    newLineState = @newState.lines[id]

    lineNode = @lineNodesByLineId[id]

    if @newState.scrollWidth isnt @oldState.scrollWidth
      lineNode.style.width = @newState.scrollWidth + 'px'

    newDecorationClasses = newLineState.decorationClasses
    oldDecorationClasses = oldLineState.decorationClasses

    if oldDecorationClasses?
      for decorationClass in oldDecorationClasses
        unless newDecorationClasses? and decorationClass in newDecorationClasses
          lineNode.classList.remove(decorationClass)

    if newDecorationClasses?
      for decorationClass in newDecorationClasses
        unless oldDecorationClasses? and decorationClass in oldDecorationClasses
          lineNode.classList.add(decorationClass)

    oldLineState.decorationClasses = newLineState.decorationClasses

    if newLineState.top isnt oldLineState.top
      lineNode.style.top = newLineState.top + 'px'
      oldLineState.top = newLineState.cop

    if newLineState.screenRow isnt oldLineState.screenRow
      lineNode.dataset.screenRow = newLineState.screenRow
      oldLineState.screenRow = newLineState.screenRow
      @lineIdsByScreenRow[newLineState.screenRow] = id

  lineNodeForScreenRow: (screenRow) ->
    @lineNodesByLineId[@lineIdsByScreenRow[screenRow]]

  measureLineHeightAndDefaultCharWidth: ->
    @domNode.appendChild(DummyLineNode)
    lineHeightInPixels = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    @domNode.removeChild(DummyLineNode)

    @presenter.setLineHeight(lineHeightInPixels)
    @presenter.setBaseCharacterWidth(charWidth)

  remeasureCharacterWidths: ->
    return unless @presenter.baseCharacterWidth

    @clearScopedCharWidths()
    @measureCharactersInNewLines()

  measureCharactersInNewLines: ->
    @presenter.batchCharacterMeasurement =>
      for id, lineState of @oldState.lines
        unless @measuredLines.has(id)
          lineNode = @lineNodesByLineId[id]
          @measureCharactersInLine(id, lineState, lineNode)
      return

  measureCharactersInLine: (lineId, tokenizedLine, lineNode) ->
    rangeForMeasurement = null
    iterator = null
    charIndex = 0

    for {value, scopes, hasPairedCharacter} in tokenizedLine.tokens
      charWidths = @presenter.getScopedCharacterWidths(scopes)

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
          @presenter.setScopedCharacterWidth(scopes, char, charWidth)

        charIndex += charLength

    @measuredLines.add(lineId)

  clearScopedCharWidths: ->
    @measuredLines.clear()
    @presenter.clearScopedCharacterWidths()
