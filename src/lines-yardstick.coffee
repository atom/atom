TokenIterator = require './token-iterator'
{Point} = require 'text-buffer'

module.exports =
class LinesYardstick
  constructor: (@model, @presenter, @lineNodesProvider) ->
    @tokenIterator = new TokenIterator
    @rangeForMeasurement = document.createRange()

  prepareScreenRowsForMeasurement: (screenRows) ->
    @presenter.setScreenRowsToMeasure(screenRows)
    @lineNodesProvider.updateSync(@presenter.getPreMeasurementState())

  screenPositionForPixelPosition: (pixelPosition) ->
    targetTop = pixelPosition.top
    targetLeft = pixelPosition.left
    defaultCharWidth = @model.getDefaultCharWidth()
    row = Math.floor(targetTop / @model.getLineHeightInPixels())
    targetLeft = 0 if row < 0
    targetLeft = Infinity if row > @model.getLastScreenRow()
    row = Math.min(row, @model.getLastScreenRow())
    row = Math.max(0, row)

    tokenizedLine = @model.tokenizedLineForScreenRow(row)
    lineNode = @lineNodesProvider.lineNodeForLineIdAndScreenRow(tokenizedLine.id, row)

    return new Point(row, 0) unless lineNode? and tokenizedLine?

    iterator = document.createNodeIterator(lineNode, NodeFilter.SHOW_TEXT)
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

        indexWithinTextNode = charIndex - textNodeIndex
        left = @leftPixelPositionForCharInTextNode(lineNode, textNode, indexWithinTextNode)
        break if left >= targetLeft

        charIndex += charLength

    new Point(row, charIndex)

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

    indexWithinTextNode = null
    iterator = document.createNodeIterator(lineNode, NodeFilter.SHOW_TEXT)
    charIndex = 0

    @tokenIterator.reset(tokenizedLine)
    while @tokenIterator.next()
      break if foundIndexWithinTextNode?

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
          foundIndexWithinTextNode = charIndex - textNodeIndex
          break

        charIndex += charLength

    if textNode?
      foundIndexWithinTextNode ?= textNode.textContent.length
      @leftPixelPositionForCharInTextNode(lineNode, textNode, foundIndexWithinTextNode)
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
