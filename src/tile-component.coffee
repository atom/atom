_ = require 'underscore-plus'
{toArray} = require 'underscore-plus'
{$$} = require 'space-pen'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
WrapperDiv = document.createElement('div')

cloneObject = (object) ->
  clone = {}
  clone[key] = value for key, value of object
  clone

module.exports =
class TileComponent
  placeholderTextDiv: null

  constructor: ({@presenter, @id, @domNode}) ->
    @measuredLines = new Set
    @lineNodesByLineId = {}
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}
    @domNode ?= document.createElement("div")
    @domNode.style.position = "absolute"
    @domNode.style.display = "block"
    @domNode.classList.add("tile")

  getDomNode: ->
    @domNode

  updateSync: (state) ->
    @newState = state
    unless @oldState
      @oldState = {tiles: {}}
      @oldState.tiles[@id] = {lines: {}}

    @newTileState = @newState.tiles[@id]
    @oldTileState = @oldState.tiles[@id]

    if @newTileState.display isnt @oldTileState.display
      @domNode.style.display = @newTileState.display
      @oldTileState.display = @newTileState.display

    if @newTileState.height isnt @oldTileState.height
      @domNode.style.height = @newTileState.height + 'px'
      @oldTileState.height = @newTileState.height

    if @newTileState.top isnt @oldTileState.top or @newTileState.left isnt @oldTileState.left
      @domNode.style['-webkit-transform'] = "translate3d(#{@newTileState.left}px, #{@newTileState.top}px, 0px)"
      @oldTileState.top = @newTileState.top
      @oldTileState.left = @newTileState.left

    @removeLineNodes() unless @oldState.indentGuidesVisible is @newState.indentGuidesVisible
    @updateLineNodes()

    if @newState.scrollWidth isnt @oldState.scrollWidth
      @domNode.style.width = @newState.scrollWidth + 'px'
      @oldState.scrollWidth = @newState.scrollWidth

    @oldState.indentGuidesVisible = @newState.indentGuidesVisible
    @oldState.scrollWidth = @newState.scrollWidth

  removeLineNodes: ->
    @removeLineNode(id) for id of @oldTileState.lines
    return

  removeLineNode: (id) ->
    @lineNodesByLineId[id].remove()
    delete @lineNodesByLineId[id]
    delete @lineIdsByScreenRow[@screenRowsByLineId[id]]
    delete @screenRowsByLineId[id]
    delete @oldTileState.lines[id]

  updateLineNodes: ->
    for id of @oldTileState.lines
      unless @newTileState.lines.hasOwnProperty(id)
        @removeLineNode(id)

    newLineIds = null
    newLinesHTML = null

    for id, lineState of @newTileState.lines
      if @oldTileState.lines.hasOwnProperty(id)
        @updateLineNode(id)
      else
        newLineIds ?= []
        newLinesHTML ?= ""
        newLineIds.push(id)
        newLinesHTML += @buildLineHTML(id)
        @screenRowsByLineId[id] = lineState.screenRow
        @lineIdsByScreenRow[lineState.screenRow] = id
        @oldTileState.lines[id] = cloneObject(lineState)

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
    {screenRow, tokens, text, top, lineEnding, fold, isSoftWrapped, indentLevel, decorationClasses} = @newTileState.lines[id]

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
    {indentLevel, tabLength, endOfLineInvisibles} = @newTileState.lines[id]

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
    {tokens, text, isOnlyWhitespace} = @newTileState.lines[id]
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
    {endOfLineInvisibles} = @newTileState.lines[id]

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
    oldLineState = @oldTileState.lines[id]
    newLineState = @newTileState.lines[id]

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
      oldLineState.top = newLineState.top

    if newLineState.screenRow isnt oldLineState.screenRow
      lineNode.dataset.screenRow = newLineState.screenRow
      oldLineState.screenRow = newLineState.screenRow
      @lineIdsByScreenRow[newLineState.screenRow] = id

  lineNodeForScreenRow: (screenRow) ->
    @lineNodesByLineId[@lineIdsByScreenRow[screenRow]]

  measureCharactersInNewLines: ->
    for id, lineState of @oldTileState.lines
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

  clearMeasurements: ->
    @measuredLines.clear()
