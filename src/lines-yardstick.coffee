LineHtmlBuilder = require './line-html-builder'
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
rangeForMeasurement = document.createRange()
WrapperDiv = document.createElement("div")
{Emitter} = require 'event-kit'

module.exports =
class LinesYardstick
  constructor: (@editor, @presenter, hostElement) ->
    @initialized = false
    @emitter = new Emitter
    @linesBuilder = new LineHtmlBuilder(true)
    @htmlNode = document.createElement("div")
    @stylesNode = document.createElement("style")
    @iframe = document.createElement("iframe")
    @iframe.onload = @setupIframe

    hostElement.appendChild(@iframe)

  setFont: (fontFamily, fontSize) ->
    @stylesNode.innerHTML = "body { margin: 0; padding: 0; font-size: #{fontSize}; font-family: #{fontFamily}; white-space: pre; }"

  onDidInitialize: (callback) ->
    @emitter.on "did-initialize", callback

  canMeasure: ->
    @initialized

  ensureInitialized: ->
    return if @canMeasure()

    throw new Error("This instance of LinesYardstick hasn't been initialized!")

  setupIframe: =>
    @initialized = true
    @domNode = @iframe.contentDocument.body
    @domNode.appendChild(@stylesNode)
    @domNode.appendChild(WrapperDiv)

    @emitter.emit "did-initialize"

  buildDomNodesForScreenRows: (screenRows) ->
    @ensureInitialized()

    @lineDomPositionByScreenRow = {}
    html = ""
    state = @presenter.getState().content
    index = 0

    screenRows.forEach (screenRow) =>
      line = @editor.tokenizedLineForScreenRow(screenRow)
      lineState = @presenter.buildLineState(0, screenRow, line)
      html += @linesBuilder.buildLineHTML(
        state.indentGuidesVisible,
        state.width,
        lineState
      )

      @lineDomPositionByScreenRow[screenRow] = index++

    WrapperDiv.remove()
    WrapperDiv.innerHTML = html
    @domNode.appendChild(WrapperDiv)

  lineNodeForScreenRow: (screenRow) ->
    WrapperDiv.children[@lineDomPositionByScreenRow[screenRow]]

  leftPixelPositionForScreenPosition: (screenPosition) ->
    @ensureInitialized()

    lineNode = @lineNodeForScreenRow(screenPosition.row)
    tokens = lineNode.getElementsByClassName("token")
    token = @findTokenByColumn(screenPosition.column, tokens)
    positionWithinToken = screenPosition.column - parseInt(token.dataset.start)

    # console.log "Found Token: #{token.dataset.start}-#{token.dataset.end}"
    # console.log "#{positionWithinToken}"
    # console.log "First Token: #{tokens[0].dataset.start}-#{tokens[0].dataset.end}"
    # console.log "First Token: #{tokens[0].textContent}"

    @charOffsetLeft(token.childNodes[0], positionWithinToken)

  findTokenByColumn: (column, tokens, startIndex = 0, endIndex = tokens.length) ->
    return null if startIndex > endIndex

    index = Math.round (startIndex + endIndex) / 2
    element = tokens[index]

    rangeStart = parseInt(element.dataset.start)
    rangeEnd = parseInt(element.dataset.end)

    if rangeStart > column
      @findTokenByColumn(column, tokens, startIndex, index - 1)
    else if rangeEnd < column
      @findTokenByColumn(column, tokens, index + 1, endIndex)
    else
      element

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
