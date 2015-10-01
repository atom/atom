TokenIterator = require './token-iterator'
{Point} = require 'text-buffer'

module.exports =
class LinesYardstick
  constructor: (@model, @presenter, @lineNodesProvider) ->
    @tokenIterator = new TokenIterator
    @rangeForMeasurement = document.createRange()
    @invalidateCache()

  invalidateCache: ->
    @pixelPositionsByLineIdAndColumn = {}

  prepareScreenRowsForMeasurement: (screenRows) ->
    return unless @presenter.isBatching()

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

    @prepareScreenRowsForMeasurement([row])

    line = @model.tokenizedLineForScreenRow(row)
    lineNode = @lineNodesProvider.lineNodeForLineIdAndScreenRow(line?.id, row)

    return new Point(row, 0) unless lineNode? and line?

    iterator = document.createNodeIterator(lineNode, NodeFilter.SHOW_TEXT)
    column = 0
    previousColumn = 0
    previousLeft = 0

    @tokenIterator.reset(line)
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

        while nextTextNodeIndex <= column
          textNode = iterator.nextNode()
          textNodeLength = textNode.textContent.length
          textNodeIndex = nextTextNodeIndex
          nextTextNodeIndex = textNodeIndex + textNodeLength

        indexWithinTextNode = column - textNodeIndex
        left = @leftPixelPositionForCharInTextNode(lineNode, textNode, indexWithinTextNode)
        charWidth = left - previousLeft

        return new Point(row, previousColumn) if targetLeft <= previousLeft + (charWidth / 2)

        previousLeft = left
        previousColumn = column
        column += charLength

    if targetLeft <= previousLeft + (charWidth / 2)
      new Point(row, previousColumn)
    else
      new Point(row, column)

  pixelPositionForScreenPosition: (screenPosition, clip=true) ->
    screenPosition = Point.fromObject(screenPosition)
    screenPosition = @model.clipScreenPosition(screenPosition) if clip

    targetRow = screenPosition.row
    targetColumn = screenPosition.column

    @prepareScreenRowsForMeasurement([targetRow])

    top = targetRow * @model.getLineHeightInPixels()
    left = @leftPixelPositionForScreenPosition(targetRow, targetColumn)

    {top, left}

  leftPixelPositionForScreenPosition: (row, column) ->
    line = @model.tokenizedLineForScreenRow(row)
    lineNode = @lineNodesProvider.lineNodeForLineIdAndScreenRow(line?.id, row)

    return 0 unless line? and lineNode?

    if cachedPosition = @pixelPositionsByLineIdAndColumn[line.id]?[column]
      return cachedPosition

    indexWithinTextNode = null
    iterator = document.createNodeIterator(lineNode, NodeFilter.SHOW_TEXT)
    charIndex = 0

    @tokenIterator.reset(line)
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
      position = @leftPixelPositionForCharInTextNode(
        lineNode, textNode, foundIndexWithinTextNode
      )
      @pixelPositionsByLineIdAndColumn[line.id] ?= {}
      @pixelPositionsByLineIdAndColumn[line.id][column] = position
      position
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

  pixelRectForScreenRange: (screenRange) ->
    lineHeight = @model.getLineHeightInPixels()

    if screenRange.end.row > screenRange.start.row
      top = @pixelPositionForScreenPosition(screenRange.start).top
      left = 0
      height = (screenRange.end.row - screenRange.start.row + 1) * lineHeight
      width = @presenter.getScrollWidth()
    else
      {top, left} = @pixelPositionForScreenPosition(screenRange.start, false)
      height = lineHeight
      width = @pixelPositionForScreenPosition(screenRange.end, false).left - left

    {top, left, width, height}
