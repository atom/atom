AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
rangeForMeasurement = document.createRange()

module.exports =
class LinesYardstick
  constructor: (@editor) ->

  setLinesComponent: (@linesComponent) ->

  pixelPositionForScreenPosition: (tileRow, screenPosition, clip=true) ->
    {
      top: screenPosition.row * @editor.getLineHeightInPixels(),
      left: @leftPixelPositionForScreenPosition(tileRow, screenPosition)
    }

  leftPixelPositionForScreenPosition: (tileRow, screenPosition) ->
    tokenizedLine = @editor.tokenizedLineForScreenRow(screenPosition.row)
    iterator = tokenizedLine.getTokenIterator()

    if lineNode = @lineNodeForLineId(tileRow, tokenizedLine.id)
      @measureLeftPixelPosition(lineNode, screenPosition.column, iterator)
    else
      @guessLeftPixelPosition(screenPosition.column, iterator)

  guessLeftPixelPosition: (targetColumn, iterator) ->
    baseCharacterWidth = @editor.getDefaultCharWidth()
    left = 0
    column = 0
    while iterator.next()
      characterWidths = @editor.getScopedCharWidths(iterator.getScopes())

      valueIndex = 0
      text = iterator.getText()
      while valueIndex < text.length
        if iterator.isPairedCharacter()
          char = text
          charLength = 2
          valueIndex += 2
        else
          char = text[valueIndex]
          charLength = 1
          valueIndex++

        break if column is targetColumn

        left += characterWidths[char] ? baseCharacterWidth unless char is '\0'
        column += charLength

    left

  measureLeftPixelPosition: (lineNode, targetColumn, iterator) ->
    # TODO: Maybe we could have a LineIterator, which takes a line node and a
    # tokenized line, so that here we can simply express how to measure stuff
    # and not do all the housekeeping of making TokenIterator and NodeIterator
    # match.
    nodeIterator = document.createNodeIterator(lineNode, NodeFilter.SHOW_TEXT, AcceptFilter)
    charIndex = 0
    leftPixelPosition = 0
    while iterator.next()
      text = iterator.getText()
      textIndex = 0
      while textIndex < text.length
        if iterator.isPairedCharacter()
          char = text
          charLength = 2
          textIndex += 2
        else
          char = text[textIndex]
          charLength = 1
          textIndex++

        continue if char is '\0'

        unless textNode?
          textNode = nodeIterator.nextNode()
          textNodeIndex = 0
          nextTextNodeIndex = textNode.textContent.length

        while nextTextNodeIndex <= charIndex
          leftPixelPosition += @measureTextNode(textNode)
          textNode = nodeIterator.nextNode()
          textNodeIndex = nextTextNodeIndex
          nextTextNodeIndex = textNodeIndex + textNode.textContent.length

        if charIndex is targetColumn
          indexWithinNode = charIndex - textNodeIndex
          return leftPixelPosition + @measureTextNode(textNode, indexWithinNode)

        charIndex += charLength

    leftPixelPosition += @measureTextNode(textNode) if textNode?
    leftPixelPosition

  measureTextNode: (textNode, extent = textNode.textContent.length) ->
    rangeForMeasurement.setStart(textNode, 0)
    rangeForMeasurement.setEnd(textNode, extent)
    rangeForMeasurement.getBoundingClientRect().width

  lineNodeForLineId: (tileRow, lineId) ->
    tileComponent = @linesComponent?.getComponentForTile(tileRow)
    tileComponent?.lineNodeForLineId(lineId)
