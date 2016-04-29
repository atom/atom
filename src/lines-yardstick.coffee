{Point} = require 'text-buffer'
{isPairedCharacter} = require './text-utils'

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
    row = @lineTopIndex.rowForPixelPosition(targetTop)
    targetLeft = 0 if targetTop < 0
    targetLeft = Infinity if row > @model.getLastScreenRow()
    row = Math.min(row, @model.getLastScreenRow())
    row = Math.max(0, row)

    lineNode = @lineNodesProvider.lineNodeForScreenRow(row)
    return Point(row, 0) unless lineNode

    textNodes = @lineNodesProvider.textNodesForScreenRow(row)
    lineOffset = lineNode.getBoundingClientRect().left
    targetLeft += lineOffset

    textNodeIndex = @_binarySearch(textNodes, (textNode) =>
      {length: textNodeLength} = textNode
      rangeRect = @clientRectForRange(textNode, 0, textNodeLength)
      return -1 if rangeRect.right < targetLeft
      return 1 if rangeRect.left > targetLeft
      return 0
    )

    textNodeStartColumn = 0

    if textNodeIndex >= 0
      textNodeStartColumn += textNodes[i].length for i in [0...textNodeIndex]

      textNode = textNodes[textNodeIndex]
      {textContent: textNodeContent} = textNode
      rangeRect = null
      nextCharIndex = -1

      characterIndex = @_binarySearch(textNodeContent, (char, charIndex) =>
        if isPairedCharacter(textNodeContent, charIndex)
          nextCharIndex = charIndex + 2
        else
          nextCharIndex = charIndex + 1
        rangeRect = @clientRectForRange(textNode, charIndex, nextCharIndex)
        return -1 if rangeRect.right < targetLeft
        return 1 if rangeRect.left > targetLeft
        return 0
      )

      if targetLeft <= ((rangeRect.left + rangeRect.right) / 2)
        return Point(row, textNodeStartColumn + characterIndex)
      return Point(row, textNodeStartColumn + nextCharIndex)

    textNodeStartColumn += node.length for node in textNodes
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

  _binarySearch: (array, compare) ->
    low = 0
    high = array.length - 1
    while low <= high
      mid = low + (high - low >> 1)
      comparison = compare(array[mid], mid)
      if comparison < 0
        low = mid + 1
      else if comparison > 0
        high = mid - 1
      else
        return mid

    return -1
