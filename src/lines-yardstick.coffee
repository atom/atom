LineHtmlBuilder = require './line-html-builder'
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
rangeForMeasurement = document.createRange()

module.exports =
class LinesYardstick
  constructor: (@editor, @presenter, hostElement) ->
    @initialized = false
    @linesBuilder = new LineHtmlBuilder
    @htmlNode = document.createElement("div")
    @stylesNode = document.createElement("style")
    @stylesNode.innerHTML = "body { font-size: 16px; }"
    @iframe = document.createElement("iframe")
    @iframe.onload = @setupIframe

    hostElement.appendChild(@iframe)

  setupIframe: =>
    @initialized = true
    @domNode = @iframe.contentDocument.body
    @domNode.appendChild(@stylesNode)
    @domNode.appendChild(@htmlNode)

  measureLines: (positions) ->
    unless @initialized
      console.log "Not initialized yet"
      return

    html = ""
    lines = []
    for position in positions
      line = @editor.tokenizedLineForScreenRow(position.row)
      lineState = @presenter.buildLineState(0, position.row, line)
      html += @linesBuilder.buildLineHTML(true, 1000, lineState)

      lines.push({line, position})

    @htmlNode.innerHTML = html

    for {line, position}, i in lines
      @measureLeftPixelPosition(@htmlNode.children[i], position.column, line.getTokenIterator())

  measureLeftPixelPosition: (lineNode, targetColumn, iterator) ->
    # TODO: Maybe we could have a LineIterator, which takes a line node and a
    # tokenized line, so that here we can simply express how to measure stuff
    # and not do all the housekeeping of making TokenIterator and NodeIterator
    # match.
    lineOffset = lineNode.getBoundingClientRect().left
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
          textNode = nodeIterator.nextNode()
          textNodeIndex = nextTextNodeIndex
          nextTextNodeIndex = textNodeIndex + textNode.textContent.length

        if charIndex is targetColumn
          indexWithinNode = charIndex - textNodeIndex
          return @charOffsetLeft(textNode, indexWithinNode) - lineOffset

        charIndex += charLength

    if textNode?
      @charOffsetLeft(textNode, textNode.textContent.length) - lineOffset
    else
      0

  charOffsetLeft: (textNode, charIndex) ->
    rangeForMeasurement.setEnd(textNode, textNode.textContent.length)

    if charIndex is 0
      rangeForMeasurement.setStart(textNode, 0)
      rangeForMeasurement.getBoundingClientRect().left
    else if charIndex is textNode.textContent.length
      rangeForMeasurement.setStart(textNode, 0)
      rangeForMeasurement.getBoundingClientRect().right
    else
      rangeForMeasurement.setStart(textNode, charIndex)
      rangeForMeasurement.getBoundingClientRect().left
