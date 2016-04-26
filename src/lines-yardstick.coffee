{Point} = require 'text-buffer'
{isPairedCharacter} = require './text-utils'
binarySearch = require 'binary-search-with-index'

module.exports =
class LinesYardstick
  constructor: (@model, @lineNodesProvider, @lineTopIndex, grammarRegistry) ->
    @rangeForMeasurement = document.createRange()
    @invalidateCache()

  invalidateCache: ->
    @leftPixelPositionCache = {}

  measuredRowForPixelPosition: (pixelPosition) ->
    targetTop = pixelPosition.top
    row = Math.floor(targetTop / @model.getLineHeightInPixels())
    row if 0 <= row <= @model.getLastScreenRow()

  screenPositionForPixelPosition: (pixelPosition) ->
    targetTop = pixelPosition.top
    targetLeft = pixelPosition.left
    defaultCharWidth = @model.getDefaultCharWidth()
    return Point(0, 0) if targetTop < 0
    row = @lineTopIndex.rowForPixelPosition(targetTop)
    targetLeft = Infinity if row > @model.getLastScreenRow()
    row = Math.min(row, @model.getLastScreenRow())
    row = Math.max(0, row)

    lineNode = @lineNodesProvider.lineNodeForScreenRow(row)
    return Point(row, 0) unless lineNode

    textNodes = @lineNodesProvider.textNodesForScreenRow(row)
    lineOffset = lineNode.getBoundingClientRect().left
    targetLeft += lineOffset

    textNodeComparator = (textNode, position) =>
      {length: textNodeLength} = textNode
      rangeRect = @clientRectForRange(textNode, 0, textNodeLength)
      return -1 if rangeRect.right < position
      return 1 if rangeRect.left > position
      return 0

    textNodeIndex = binarySearch(textNodes, targetLeft, textNodeComparator)

    if textNodeIndex >= 0
      textNodeStartColumn = textNodes
        .slice(0, textNodeIndex)
        .reduce(((totalLength, node) -> totalLength + node.length), 0)
      charIndex = @charIndexForScreenPosition(textNodes[textNodeIndex], targetLeft)

      return Point(row, textNodeStartColumn + charIndex)

    textNodeStartColumn = textNodes
      .reduce(((totalLength, node) -> totalLength + node.length), 0)

    return Point(row, textNodeStartColumn)

  pixelPositionForScreenPosition: (screenPosition) ->
    targetRow = screenPosition.row
    targetColumn = screenPosition.column

    top = @lineTopIndex.pixelPositionAfterBlocksForRow(targetRow)
    left = @leftPixelPositionForScreenPosition(targetRow, targetColumn)

    {top, left}

  leftPixelPositionForScreenPosition: (row, column) ->
    lineNode = @lineNodesProvider.lineNodeForScreenRow(row)
    lineId = @lineNodesProvider.lineIdForScreenRow(row)

    return 0 unless lineNode?

    if cachedPosition = @leftPixelPositionCache[lineId]?[column]
      return cachedPosition

    textNodes = @lineNodesProvider.textNodesForScreenRow(row)
    textNodeStartColumn = 0

    for textNode in textNodes
      textNodeEndColumn = textNodeStartColumn + textNode.textContent.length
      if textNodeEndColumn > column
        indexInTextNode = column - textNodeStartColumn
        break
      else
        textNodeStartColumn = textNodeEndColumn

    if textNode?
      indexInTextNode ?= textNode.textContent.length
      lineOffset = lineNode.getBoundingClientRect().left
      if indexInTextNode is 0
        leftPixelPosition = @clientRectForRange(textNode, 0, 1).left
      else
        leftPixelPosition = @clientRectForRange(textNode, 0, indexInTextNode).right
      leftPixelPosition -= lineOffset

      @leftPixelPositionCache[lineId] ?= {}
      @leftPixelPositionCache[lineId][column] = leftPixelPosition
      leftPixelPosition
    else
      0

  clientRectForRange: (textNode, startIndex, endIndex) ->
    @rangeForMeasurement.setStart(textNode, startIndex)
    @rangeForMeasurement.setEnd(textNode, endIndex)
    @rangeForMeasurement.getClientRects()[0] ? @rangeForMeasurement.getBoundingClientRect()

  charIndexForScreenPosition: (textNode, targetLeft) ->
    {textContent: textNodeContent} = textNode
    rangeRect = null
    nextCharIndex = -1
    characterComparator = (char, position, charIndex) =>
      if isPairedCharacter(textNodeContent, charIndex)
        nextCharIndex = charIndex + 2
      else
        nextCharIndex = charIndex + 1
      rangeRect = @clientRectForRange(textNode, charIndex, nextCharIndex)
      return -1 if rangeRect.right < position
      return 1 if rangeRect.left > position
      return 0

    characterIndex = binarySearch(textNodeContent, targetLeft, characterComparator)
    if targetLeft <= ((rangeRect.left + rangeRect.right) / 2)
      return characterIndex
    return nextCharIndex
