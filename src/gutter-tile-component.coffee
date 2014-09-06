{toArray, multiplyString} = require 'underscore-plus'
WrapperDiv = document.createElement('div')

module.exports =
class GutterTileComponent
  constructor: (@presenter) ->
    @lineNumberNodesById = {}
    @screenRowsByLineNumberId = {}
    @renderedDecorationsByLineNumberId = {}

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

  updateLineNumbers: ->
    lineNumbersSet = new Set
    lineNumbersSet.add(lineNumber) for lineNumber in @presenter.lineNumbers

    for lineNumberId, lineNumberNode of @lineNumberNodesById
      unless lineNumbersSet.has(lineNumberId)
        delete @lineNumberNodesById[lineNumberId]
        delete @screenRowsByLineNumberId[lineNumberId]
        delete @renderedDecorationsByLineNumberId[lineNumberId]
        @domNode.removeChild(lineNumberNode)

    newLineNumberIds = []
    newLineNumbersHTML = ""

    for lineNumberId, i in @presenter.lineNumbers
      screenRow = @presenter.startRow + i

      if @lineNumberNodesById[lineNumberId]?
        @updateLineNumberNode(lineNumberId, screenRow)
      else
        newLineNumberIds.push(lineNumberId)
        newLineNumbersHTML += @buildLineNumberHTML(lineNumberId, screenRow)
        @screenRowsByLineNumberId[lineNumberId] = screenRow
        # @lineNumberIdsByScreenRow[screenRow] = id

      # @renderedDecorationsByLineNumberId[id] = lineDecorations[screenRow]

    if newLineNumberIds.length > 0
      WrapperDiv.innerHTML = newLineNumbersHTML
      newLineNumberNodes = toArray(WrapperDiv.children)

      for lineNumberId, i in newLineNumberIds
        @lineNumberNodesById[lineNumberId] = newLineNumberNodes[i]
        @domNode.appendChild(newLineNumberNodes[i])

  buildLineNumberHTML: (lineNumberId, screenRow) ->
    {lineHeightInPixels, lineDecorations} = @presenter

    if screenRow?
      top = (screenRow - @presenter.startRow) * lineHeightInPixels
      style = "position: absolute; top: #{top}px;"
    else
      style = "visibility: hidden;"

    innerHTML = @buildLineNumberInnerHTML(lineNumberId)

    # classes = ''
    # if lineDecorations? and decorations = lineDecorations[screenRow]
    #   for id, decoration of decorations
    #     if Decoration.isType(decoration, 'gutter')
    #       classes += decoration.class + ' '

    # classes += "foldable " if bufferRow >= 0 and editor.isFoldableAtBufferRow(bufferRow)
    # classes += "line-number line-number-#{bufferRow}"

    classes = "line-number"

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

    # decorations = lineDecorations[screenRow]
    # previousDecorations = @renderedDecorationsByLineNumberId[lineNumberId]
    #
    # if previousDecorations?
    #   for id, decoration of previousDecorations
    #     if Decoration.isType(decoration, 'gutter') and not @hasDecoration(decorations, decoration)
    #       node.classList.remove(decoration.class)
    #
    # if decorations?
    #   for id, decoration of decorations
    #     if Decoration.isType(decoration, 'gutter') and not @hasDecoration(previousDecorations, decoration)
    #       node.classList.add(decoration.class)
    #
    unless @screenRowsByLineNumberId[lineNumberId] is screenRow
      {lineHeightInPixels} = @presenter
      node.style.top = screenRow * lineHeightInPixels + 'px'
      node.dataset.screenRow = screenRow
      @screenRowsByLineNumberId[lineNumberId] = screenRow
      # @lineNumberIdsByScreenRow[screenRow] = lineNumberId
