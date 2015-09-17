TokenIterator = require './token-iterator'
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
{Point} = require 'text-buffer'

module.exports =
class LinesYardstick
  constructor: (@model, @lineNodesProvider) ->
    @tokenIterator = new TokenIterator
    @rangeForMeasurement = document.createRange()

  pixelPositionForScreenPosition: (screenPosition, clip=true) ->
    screenPosition = Point.fromObject(screenPosition)
    screenPosition = @model.clipScreenPosition(screenPosition) if clip

    targetRow = screenPosition.row
    targetColumn = screenPosition.column
    baseCharacterWidth = @baseCharacterWidth

    top = targetRow * @model.getLineHeightInPixels()
    left = @leftPixelPositionForScreenPosition(targetRow, targetColumn)

    {top, left}

  leftPixelPositionForScreenPosition: (row, column) ->
    tokenizedLine = @model.tokenizedLineForScreenRow(row)
    return 0 unless tokenizedLine?

    lineNode =
      @lineNodesProvider.lineNodeForLineIdAndScreenRow(tokenizedLine.id, row)

    return 0 unless lineNode?

    iterator = document.createNodeIterator(lineNode, NodeFilter.SHOW_TEXT, AcceptFilter)
    charIndex = 0

    @tokenIterator.reset(tokenizedLine)
    while @tokenIterator.next()
      text = @tokenIterator.getText()

      textIndex = 0
      while textIndex < text.length
        if @tokenIterator.isPairedCharacter()
          char = text
          charLength = 2
          textIndex += 2
        else
          char = text[textIndex]
          charLength = 1
          textIndex++

        unless textNode?
          textNode = iterator.nextNode()
          textNodeLength = textNode.textContent.length
          textNodeIndex = 0
          nextTextNodeIndex = textNodeLength

        while nextTextNodeIndex <= charIndex
          textNode = iterator.nextNode()
          textNodeLength = textNode.textContent.length
          textNodeIndex = nextTextNodeIndex
          nextTextNodeIndex = textNodeIndex + textNodeLength

        if charIndex is column
          indexWithinToken = charIndex - textNodeIndex
          return @leftPixelPositionForCharInTextNode(lineNode, textNode, indexWithinToken)

        charIndex += charLength

    if textNode?
      @leftPixelPositionForCharInTextNode(lineNode, textNode, textNode.textContent.length)
    else
      0

  leftPixelPositionForCharInTextNode: (lineNode, textNode, charIndex) ->
    @rangeForMeasurement.setEnd(textNode, textNode.textContent.length)

    position =
      if charIndex is 0
        @rangeForMeasurement.setStart(textNode, 0)
        @rangeForMeasurement.getBoundingClientRect().left
      else if charIndex is textNode.textContent.length
        @rangeForMeasurement.setStart(textNode, 0)
        @rangeForMeasurement.getBoundingClientRect().right
      else
        @rangeForMeasurement.setStart(textNode, charIndex)
        @rangeForMeasurement.getBoundingClientRect().left

    position - lineNode.getBoundingClientRect().left
