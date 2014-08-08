{toArray, multiplyString, clone} = require 'underscore-plus'
WrapperDiv = document.createElement('div')

module.exports =
class GutterTileComponent
  constructor: (@presenter) ->
    @lineNumberNodesById = {}
    @screenRowsByLineNumberId = {}
    @lineNumberDecorationsByLineNumberId = {}

    @domNode = document.createElement('div')
    @domNode.style.overflow = 'hidden'
    if @presenter.dummy
      @domNode.style.visibility = 'hidden'
    else
      @domNode.style.position = 'absolute'
      @domNode.style.top = '0px'

    @appendDummyLineNumber()
    @update()

  appendDummyLineNumber: ->
    WrapperDiv.innerHTML = @buildLineNumberHTML('0')
    @domNode.appendChild(WrapperDiv.firstChild)

  update: ->
    return if @presenter.dummy
    @updateTransform()
    @updateHeight()
    @updateBackgroundColor()
    @updateLineNumbers()

  updateTransform: ->
    {top} = @presenter
    unless top is @top
      @domNode.style['-webkit-transform'] = "translate3d(0px, #{top}px, 0px)"
      @top = top

  updateHeight: ->
    {height} = @presenter
    unless height is @height
      @domNode.style.height = height + 'px'
      @height = height

  updateBackgroundColor: ->
    {backgroundColor} = @presenter
    unless backgroundColor is @backgroundColor
      @domNode.style.backgroundColor = backgroundColor
      @backgroundColor = backgroundColor

  updateLineNumbers: ->
    {lineNumbers, lineNumberDecorations} = @presenter

    lineNumbersSet = new Set
    lineNumbersSet.add(lineNumber) for lineNumber in lineNumbers

    for lineNumberId, lineNumberNode of @lineNumberNodesById
      unless lineNumbersSet.has(lineNumberId)
        delete @lineNumberNodesById[lineNumberId]
        delete @screenRowsByLineNumberId[lineNumberId]
        delete @lineNumberDecorationsByLineNumberId[lineNumberId]
        @domNode.removeChild(lineNumberNode)

    newLineNumberIds = []
    newLineNumbersHTML = ""

    for lineNumberId, i in lineNumbers
      screenRow = @presenter.startRow + i

      if @lineNumberNodesById[lineNumberId]?
        @updateLineNumberNode(lineNumberId, screenRow)
      else
        newLineNumberIds.push(lineNumberId)
        newLineNumbersHTML += @buildLineNumberHTML(lineNumberId, screenRow)
        @screenRowsByLineNumberId[lineNumberId] = screenRow
        # @lineNumberIdsByScreenRow[screenRow] = id
        @lineNumberDecorationsByLineNumberId[lineNumberId] = clone(lineNumberDecorations[screenRow])

    if newLineNumberIds.length > 0
      WrapperDiv.innerHTML = newLineNumbersHTML
      newLineNumberNodes = toArray(WrapperDiv.children)

      for lineNumberId, i in newLineNumberIds
        @lineNumberNodesById[lineNumberId] = newLineNumberNodes[i]
        @lineNumberDecorationsByLineNumberId
        @domNode.appendChild(newLineNumberNodes[i])

  buildLineNumberHTML: (lineNumberId, screenRow) ->
    {lineHeightInPixels, lineNumberDecorations} = @presenter

    if screenRow?
      top = (screenRow - @presenter.startRow) * lineHeightInPixels
      style = "position: absolute; top: #{top}px;"
    else
      style = "visibility: hidden;"

    innerHTML = @buildLineNumberInnerHTML(lineNumberId)

    classes = ''
    if decorationsById = lineNumberDecorations?[screenRow]
      for id, decoration of decorationsById
        classes += decoration.class + ' '

    # classes += "foldable " if bufferRow >= 0 and editor.isFoldableAtBufferRow(bufferRow)
    classes += "line-number line-number-#{lineNumberId.replace(/\..*/, '')}"

    "<div class=\"#{classes}\" style=\"#{style}\" data-screen-row=\"#{screenRow}\">#{innerHTML}</div>"

  buildLineNumberInnerHTML: (lineNumberId) ->
    {maxLineNumberDigits} = @presenter
    softWrapped = lineNumberId.indexOf('.') isnt -1

    if softWrapped
      lineNumber = "•"
    else
      lineNumber = lineNumberId

    padding = multiplyString('&nbsp;', maxLineNumberDigits - lineNumber.length)
    iconHTML = '<div class="icon-right"></div>'
    padding + lineNumber + iconHTML

  updateLineNumberNode: (lineNumberId, screenRow) ->
    {lineDecorations} = @presenter
    node = @lineNumberNodesById[lineNumberId]

    # if editor.isFoldableAtBufferRow(bufferRow)
    #   node.classList.add('foldable')
    # else
    #   node.classList.remove('foldable')

    unless @screenRowsByLineNumberId[lineNumberId] is screenRow
      {lineHeightInPixels} = @presenter
      node.style.top = screenRow * lineHeightInPixels + 'px'
      node.dataset.screenRow = screenRow
      @screenRowsByLineNumberId[lineNumberId] = screenRow
      # @lineNumberIdsByScreenRow[screenRow] = lineNumberId

    @updateLineNumberDecorations(node, lineNumberId, screenRow)

  updateLineNumberDecorations: (lineNumberNode, lineNumberId, screenRow) ->
    desiredDecorations = @presenter.lineNumberDecorations[screenRow]

    if currentDecorations = @lineNumberDecorationsByLineNumberId[lineNumberId]
      for id, decoration of currentDecorations
        unless desiredDecorations?[id]?
          lineNumberNode.classList.remove(decoration.class)
          delete currentDecorations[id]

    if desiredDecorations?
      currentDecorations = (@lineNumberDecorationsByLineNumberId[lineNumberId] ?= {})
      for id, decoration of desiredDecorations
        unless currentDecorations[id]?
          lineNumberNode.classList.add(decoration.class)
          currentDecorations[id] = decoration
