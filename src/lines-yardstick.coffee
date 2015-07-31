TokenIterator = require './token-iterator'
{Point} = require 'text-buffer'

module.exports =
class LinesYardstick
  constructor: (@editor) ->
    @fontsByScopesIdentifier = {}
    @measuringContext = document.createElement("canvas").getContext("2d")
    @tokenIterator = new TokenIterator

  clearFontsForScopes: ->
    @fontsByScopesIdentifier = {}

  setDefaultFont: (fontFamily, fontSize) ->
    @defaultFont = "#{fontSize} #{fontFamily}"

  setFontForScopes: (scopes, font) ->
    scopesIdentifier = @identifierForScopes(scopes)
    @fontsByScopesIdentifier[scopesIdentifier] = font

  identifierForScopes: (scopes) ->
    scopes.join()

  pixelPositionForScreenPosition: (screenPosition, clip=true) ->
    screenPosition = Point.fromObject(screenPosition)
    screenPosition = @editor.clipScreenPosition(screenPosition) if clip

    targetRow = screenPosition.row
    targetColumn = screenPosition.column

    top = targetRow * @editor.getLineHeightInPixels()
    left = @leftPixelPositionForScreenPosition(screenPosition)

    {top, left}

  screenPositionForPixelPosition: (pixelPosition) ->
    targetTop = pixelPosition.top
    targetLeft = pixelPosition.left

    row = Math.floor(targetTop / @editor.getLineHeightInPixels())
    targetLeft = 0 if row < 0
    targetLeft = Infinity if row > @editor.getLastScreenRow()
    row = Math.min(row, @editor.getLastScreenRow())
    row = Math.max(0, row)
    line = @editor.tokenizedLineForScreenRow(row)

    column = @screenColumnForLeftPixelPosition(row, targetLeft)

    new Point(row, column)

  currentFontForTokenIterator: ->
    scopesIdentifier = @identifierForScopes(@tokenIterator.getScopes())
    @fontsByScopesIdentifier[scopesIdentifier] or @defaultFont

  leftPixelPositionForScreenPosition: (screenPosition) ->
    line = @editor.tokenizedLineForScreenRow(screenPosition.row)
    text = ""
    width = 0

    @tokenIterator.reset(line)
    while @tokenIterator.next()
      newFont = @currentFontForTokenIterator()
      if newFont isnt @measuringContextFont
        width += @measuringContext.measureText(text).width
        @measuringContext.font = @measuringContextFont = newFont
        text = ""

      screenStart = @tokenIterator.getScreenStart()
      screenEnd = @tokenIterator.getScreenEnd()
      if screenStart <= screenPosition.column < screenEnd
        text += @tokenIterator.getText().substring(
          0,
          screenPosition.column - screenStart
        )
        break
      else
        text += @tokenIterator.getText()

    width += @measuringContext.measureText(text).width if text isnt ""
    width

  screenColumnForLeftPixelPosition: (row, targetLeft) ->
    line = @editor.tokenizedLineForScreenRow(row)
    left = 0
    column = 0

    tokenText = null
    @tokenIterator.reset(line)
    while @tokenIterator.next()
      newFont = @currentFontForTokenIterator()
      if newFont isnt @measuringContextFont
        @measuringContext.font = @measuringContextFont = newFont

      tokenText = @tokenIterator.getText()
      tokenWidth = @measuringContext.measureText(tokenText).width
      break if left + tokenWidth >= targetLeft

      left += tokenWidth
      column += tokenText.length

    indexWithinToken = 0
    while indexWithinToken < tokenText.length
      if @tokenIterator.isPairedCharacter()
        charLength = 2
        indexWithinToken += 2
      else
        charLength = 1
        indexWithinToken++

      currentRunText = tokenText.substring(0, indexWithinToken)
      currentRunWidth = @measuringContext.measureText(currentRunText).width
      break if left + currentRunWidth > targetLeft

      column += charLength

    column
