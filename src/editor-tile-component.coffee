{extend, toArray} = require 'underscore-plus'
Decoration = require './decoration'

WrapperDiv = document.createElement('div')

module.exports =
class EditorTileComponent
  constructor: (@props) ->
    @lineNodesByLineId = {}
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}
    @renderedDecorationsByLineId = {}

    @domNode = document.createElement('div')
    @domNode.style['-webkit-transform'] = @getTransform()
    @buildLines()

  updateProps: (newProps) ->
    @clearScreenRowCaches() if newProps.lineHeightInPixels isnt @props.lineHeightInPixels
    extend(@props, newProps)
    @domNode.style['-webkit-transform'] = @getTransform()
    @updateLines()

  getTransform: ->
    {startRow, lineHeightInPixels, scrollTop, scrollLeft} = @props
    left = -scrollLeft
    top = (startRow * lineHeightInPixels) - scrollTop
    "translate3d(#{left}px, #{top}px, 0px)"

  buildLines: ->
    {editor, startRow, endRow} = @props

    lines = editor.linesForScreenRows(startRow, endRow - 1)
    linesHTML = ""

    for line, i in lines
      screenRow = startRow + i
      linesHTML += @buildLineHTML(line, screenRow)

    @domNode.innerHTML = linesHTML

    for line, i in lines
      screenRow = startRow + i
      lineNode = @domNode.children[i]
      @lineNodesByLineId[line.id] = lineNode
      @screenRowsByLineId[line.id] = screenRow
      @lineIdsByScreenRow[screenRow] = line.id

  updateLines: ->
    {editor, startRow, endRow} = @props
    lines = editor.linesForScreenRows(startRow, endRow - 1)
    @removeLineNodes(lines)
    @appendOrUpdateVisibleLineNodes(lines)

  removeLineNodes: (lines=[]) ->
    lineIds = new Set
    lineIds.add(line.id.toString()) for line in lines
    for lineId, lineNode of @lineNodesByLineId when not lineIds.has(lineId)
      screenRow = @screenRowsByLineId[lineId]
      delete @lineNodesByLineId[lineId]
      delete @lineIdsByScreenRow[screenRow] if @lineIdsByScreenRow[screenRow] is lineId
      delete @screenRowsByLineId[lineId]
      delete @renderedDecorationsByLineId[lineId]
      @domNode.removeChild(lineNode)

  appendOrUpdateVisibleLineNodes: (visibleLines) ->
    {startRow, lineDecorations} = @props

    newLines = null
    newLinesHTML = null

    for line, index in visibleLines
      screenRow = startRow + index

      if @hasLineNode(line.id)
        @updateLineNode(line, screenRow)
      else
        newLines ?= []
        newLinesHTML ?= ""
        newLines.push(line)
        newLinesHTML += @buildLineHTML(line, screenRow)
        @screenRowsByLineId[line.id] = screenRow
        @lineIdsByScreenRow[screenRow] = line.id

      @renderedDecorationsByLineId[line.id] = lineDecorations[screenRow]

    return unless newLines?

    WrapperDiv.innerHTML = newLinesHTML
    newLineNodes = toArray(WrapperDiv.children)
    for line, i in newLines
      lineNode = newLineNodes[i]
      @lineNodesByLineId[line.id] = lineNode
      @domNode.appendChild(lineNode)

  updateLineNode: (line, screenRow) ->
    {startRow, editor, lineHeightInPixels, lineDecorations, lineWidth} = @props
    lineNode = @lineNodesByLineId[line.id]

    decorations = lineDecorations[screenRow]
    previousDecorations = @renderedDecorationsByLineId[line.id]

    if previousDecorations?
      for id, decoration of previousDecorations
        if Decoration.isType(decoration, 'line') and not @hasDecoration(decorations, decoration)
          lineNode.classList.remove(decoration.class)

    if decorations?
      for id, decoration of decorations
        if Decoration.isType(decoration, 'line') and not @hasDecoration(previousDecorations, decoration)
          lineNode.classList.add(decoration.class)

    unless @screenRowsByLineId[line.id] is screenRow
      lineNode.style.top = (screenRow - startRow) * lineHeightInPixels + 'px'
      lineNode.dataset.screenRow = screenRow
      @screenRowsByLineId[line.id] = screenRow
      @lineIdsByScreenRow[screenRow] = line.id

  clearScreenRowCaches: ->
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}

  hasLineNode: (lineId) ->
    @lineNodesByLineId.hasOwnProperty(lineId)

  lineNodeForScreenRow: (screenRow) ->
    @lineNodesByLineId[@lineIdsByScreenRow[screenRow]]

  hasDecoration: (decorations, decoration) ->
    decorations? and decorations[decoration.id] is decoration

  buildLineHTML: (line, screenRow) ->
    {startRow, lineHeightInPixels, lineWidth} = @props
    {text, fold, isSoftWrapped, indentLevel} = line

    classes = @getLineClasses(screenRow)
    top = (screenRow - startRow) * lineHeightInPixels
    style = "position: absolute; top: #{top}px; width: 100%;"

    lineHTML = """<div class="#{classes}" style="#{style}">"""

    if text is ""
      lineHTML += @buildEmptyLineInnerHTML(line)
    else
      lineHTML += @buildLineInnerHTML(line)

    lineHTML += '<span class="fold-marker"></span>' if fold?
    lineHTML += "</div>"
    lineHTML

  getLineClasses: (screenRow) ->
    classes = ''
    if decorations = @props.lineDecorations[screenRow]
      for id, decoration of decorations
        if Decoration.isType(decoration, 'line')
          classes += decoration.class + ' '
    classes + 'line'

  buildEmptyLineInnerHTML: (line) ->
    {showIndentGuide, invisibles} = @props
    {cr, eol} = invisibles
    {indentLevel, tabLength} = line

    if showIndentGuide and indentLevel > 0
      invisiblesToRender = []
      invisiblesToRender.push(cr) if cr? and line.lineEnding is '\r\n'
      invisiblesToRender.push(eol) if eol?

      lineHTML = ''
      for i in [0...indentLevel]
        lineHTML += "<span class='indent-guide'>"
        for j in [0...tabLength]
          if invisible = invisiblesToRender.shift()
            lineHTML += "<span class='invisible-character'>#{invisible}</span>"
          else
            lineHTML += ' '
        lineHTML += "</span>"

      while invisiblesToRender.length
        lineHTML += "<span class='invisible-character'>#{invisiblesToRender.shift()}</span>"

      lineHTML
    else
      @buildEndOfLineHTML(line, @props.invisibles) or '&nbsp;'

  buildLineInnerHTML: (line) ->
    {invisibles, mini, showIndentGuide, invisibles} = @props
    {tokens, text} = line
    innerHTML = ""

    scopeStack = []
    firstTrailingWhitespacePosition = text.search(/\s*$/)
    lineIsWhitespaceOnly = firstTrailingWhitespacePosition is 0
    for token in tokens
      innerHTML += @updateScopeStack(scopeStack, token.scopes)
      hasIndentGuide = not mini and showIndentGuide and (token.hasLeadingWhitespace or (token.hasTrailingWhitespace and lineIsWhitespaceOnly))
      innerHTML += token.getValueAsHtml({invisibles, hasIndentGuide})

    innerHTML += @popScope(scopeStack) while scopeStack.length > 0
    innerHTML += @buildEndOfLineHTML(line, invisibles)
    innerHTML

  buildEndOfLineHTML: (line, invisibles) ->
    return '' if @props.mini or line.isSoftWrapped()

    html = ''
    # Note the lack of '?' in the character checks. A user can set the chars
    # to an empty string which we will interpret as not-set
    if invisibles.cr and line.lineEnding is '\r\n'
      html += "<span class='invisible-character'>#{invisibles.cr}</span>"
    if invisibles.eol
      html += "<span class='invisible-character'>#{invisibles.eol}</span>"

    html

  updateScopeStack: (scopeStack, desiredScopes) ->
    html = ""

    # Find a common prefix
    for scope, i in desiredScopes
      break unless scopeStack[i] is desiredScopes[i]

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
