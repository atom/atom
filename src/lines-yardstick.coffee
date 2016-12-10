{Point} = require 'text-buffer'
{isPairedCharacter} = require './text-utils'

module.exports =
class LinesYardstick
  constructor: (@model, @lineNodesProvider, @lineTopIndex) ->
    @rangeForMeasurement = document.createRange()
    @invalidateCache()

  invalidateCache: ->
    @leftPixelPositionCache = {}

  measuredRowForPixelPosition: (pixelPosition) ->
    targetTop = pixelPosition.top
    row = Math.floor(targetTop / @model.getLineHeightInPixels())
    row if 0 <= row

  screenPositionForPixelPosition: (pixelPosition) ->
    targetTop = pixelPosition.top
    row = Math.max(0, @lineTopIndex.rowForPixelPosition(targetTop))
    lineNode = @lineNodesProvider.lineNodeForScreenRow(row)
    unless lineNode
      lastScreenRow = @model.getLastScreenRow()
      if row > lastScreenRow
        return Point(lastScreenRow, @model.lineLengthForScreenRow(lastScreenRow))
      else
        return Point(row, 0)

    targetLeft = pixelPosition.left
    targetLeft = 0 if targetTop < 0 or targetLeft < 0

    textNodes = @lineNodesProvider.textNodesForScreenRow(row)
    lineOffset = lineNode.getBoundingClientRect().left
    targetLeft += lineOffset

    textNodeIndex = 0
    low = 0
    high = textNodes.length - 1
    while low <= high
      mid = low + (high - low >> 1)
      textNode = textNodes[mid]
      rangeRect = @clientRectForRange(textNode, 0, textNode.length)
      if targetLeft < rangeRect.left
        high = mid - 1
        textNodeIndex = Math.max(0, mid - 1)
      else if targetLeft > rangeRect.right
        low = mid + 1
        textNodeIndex = Math.min(textNodes.length - 1, mid + 1)
      else
        textNodeIndex = mid
        break

    textNode = textNodes[textNodeIndex]
    characterIndex = 0
    low = 0
    high = textNode.textContent.length - 1
    while low <= high
      charIndex = low + (high - low >> 1)
      if isPairedCharacter(textNode.textContent, charIndex)
        nextCharIndex = charIndex + 2
      else
        nextCharIndex = charIndex + 1

      rangeRect = @clientRectForRange(textNode, charIndex, nextCharIndex)
      if targetLeft < rangeRect.left
        high = charIndex - 1
        characterIndex = Math.max(0, charIndex - 1)
      else if targetLeft > rangeRect.right
        low = nextCharIndex
        characterIndex = Math.min(textNode.textContent.length, nextCharIndex)
      else
        if targetLeft <= ((rangeRect.left + rangeRect.right) / 2)
          characterIndex = charIndex
        else
          characterIndex = nextCharIndex
        break

    textNodeStartColumn = 0
    textNodeStartColumn += textNodes[i].length for i in [0...textNodeIndex] by 1
    Point(row, textNodeStartColumn + characterIndex)

  pixelPositionForScreenPosition: (screenPosition) ->
    targetRow = screenPosition.row
    targetColumn = screenPosition.column

    top = @lineTopIndex.pixelPositionAfterBlocksForRow(targetRow)
    left = @leftPixelPositionForScreenPosition(targetRow, targetColumn)

    {top, left}

  leftPixelPositionForScreenPosition: (row, column) ->
    lineNode = @lineNodesProvider.lineNodeForScreenRow(row)
    lineId = @lineNodesProvider.lineIdForScreenRow(row)

    if lineNode?
      if @leftPixelPositionCache[lineId]?[column]?
        @leftPixelPositionCache[lineId][column]
      else
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
    else
      0

  clientRectForRange: (textNode, startIndex, endIndex) ->
    @rangeForMeasurement.setStart(textNode, startIndex)
    @rangeForMeasurement.setEnd(textNode, endIndex)
    clientRects = @rangeForMeasurement.getClientRects()
    if clientRects.length == 1
      clientRects[0]
    else 
      @rangeForMeasurement.getBoundingClientRect()
