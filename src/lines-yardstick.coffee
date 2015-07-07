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

  measureLine: (position) ->
    unless @initialized
      console.log "Not initialized yet"
      return

    console.profile("yardstick")
    line = @editor.tokenizedLineForScreenRow(position.row)
    lineState = @presenter.buildLineState(0, position.row, line)
    @htmlNode.innerHTML = @linesBuilder.buildLineHTML(true, 1000, lineState)
    @measureLeftPixelPosition(@htmlNode.children[0], position.column, line.getTokenIterator())
    console.profileEnd("yardstick")

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
