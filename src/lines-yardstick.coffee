TokenIterator = require './token-iterator'
{Point} = require 'text-buffer'

module.exports =
class LinesYardstick
  constructor: (@model, @presenter, @lineNodesProvider, grammarRegistry) ->
    @tokenIterator = new TokenIterator({grammarRegistry})
    @rangeForMeasurement = document.createRange()
    @invalidateCache()

  invalidateCache: ->
    @pixelPositionsByLineIdAndColumn = {}

  prepareScreenRowsForMeasurement: (screenRows) ->
    @presenter.setScreenRowsToMeasure(screenRows)
    @lineNodesProvider.updateSync(@presenter.getPreMeasurementState())

  clearScreenRowsForMeasurement: ->
    @presenter.clearScreenRowsToMeasure()

  screenPositionForPixelPosition: (pixelPosition, measureVisibleLinesOnly) ->
    targetTop = pixelPosition.top
    targetLeft = pixelPosition.left
    defaultCharWidth = @model.getDefaultCharWidth()
    row = Math.floor(targetTop / @model.getLineHeightInPixels())
    targetLeft = 0 if row < 0
    targetLeft = Infinity if row > @model.getLastScreenRow()
    row = Math.min(row, @model.getLastScreenRow())
    row = Math.max(0, row)

    @prepareScreenRowsForMeasurement([row]) unless measureVisibleLinesOnly

    line = @model.tokenizedLineForScreenRow(row)
    lineNode = @lineNodesProvider.lineNodeForLineIdAndScreenRow(line?.id, row)

    return new Point(row, 0) unless lineNode? and line?

    textNodes = @lineNodesProvider.textNodesForLineIdAndScreenRow(line.id, row)
    column = 0
    previousColumn = 0
    previousLeft = 0

    @tokenIterator.reset(line, false)
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
          textNode = textNodes.shift()
          textNodeLength = textNode.textContent.length
          textNodeIndex = 0
          nextTextNodeIndex = textNodeLength

        while nextTextNodeIndex <= column
          textNode = textNodes.shift()
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

    @clearScreenRowsForMeasurement() unless measureVisibleLinesOnly

    if targetLeft <= previousLeft + (charWidth / 2)
      new Point(row, previousColumn)
    else
      new Point(row, column)

  pixelPositionForScreenPosition: (screenPosition, clip=true, measureVisibleLinesOnly) ->
    screenPosition = Point.fromObject(screenPosition)
    screenPosition = @model.clipScreenPosition(screenPosition) if clip

    targetRow = screenPosition.row
    targetColumn = screenPosition.column

    @prepareScreenRowsForMeasurement([targetRow]) unless measureVisibleLinesOnly

    top = targetRow * @model.getLineHeightInPixels()
    left = @leftPixelPositionForScreenPosition(targetRow, targetColumn)

    @clearScreenRowsForMeasurement() unless measureVisibleLinesOnly

    {top, left}

  leftPixelPositionForScreenPosition: (row, column) ->
    line = @model.tokenizedLineForScreenRow(row)
    lineNode = @lineNodesProvider.lineNodeForLineIdAndScreenRow(line?.id, row)

    return 0 unless line? and lineNode?

    if cachedPosition = @pixelPositionsByLineIdAndColumn[line.id]?[column]
      return cachedPosition

    textNodes = @lineNodesProvider.textNodesForLineIdAndScreenRow(line.id, row)
    indexWithinTextNode = null
    charIndex = 0

    @tokenIterator.reset(line, false)
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
          textNode = textNodes.shift()
          textNodeLength = textNode.textContent.length
          textNodeIndex = 0
          nextTextNodeIndex = textNodeLength

        while nextTextNodeIndex <= charIndex
          textNode = textNodes.shift()
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
    if charIndex is 0
      width = 0
    else
      @rangeForMeasurement.setStart(textNode, 0)
      @rangeForMeasurement.setEnd(textNode, charIndex)
      width = @rangeForMeasurement.getBoundingClientRect().width

    @rangeForMeasurement.setStart(textNode, 0)
    @rangeForMeasurement.setEnd(textNode, textNode.textContent.length)
    left = @rangeForMeasurement.getBoundingClientRect().left

    offset = lineNode.getBoundingClientRect().left

    left + width - offset

  pixelRectForScreenRange: (screenRange, measureVisibleLinesOnly) ->
    lineHeight = @model.getLineHeightInPixels()

    if screenRange.end.row > screenRange.start.row
      top = @pixelPositionForScreenPosition(screenRange.start, true, measureVisibleLinesOnly).top
      left = 0
      height = (screenRange.end.row - screenRange.start.row + 1) * lineHeight
      width = @presenter.getScrollWidth()
    else
      {top, left} = @pixelPositionForScreenPosition(screenRange.start, false, measureVisibleLinesOnly)
      height = lineHeight
      width = @pixelPositionForScreenPosition(screenRange.end, false, measureVisibleLinesOnly).left - left

    {top, left, width, height}
