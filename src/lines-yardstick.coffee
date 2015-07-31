TokenIterator = require './token-iterator'
{Point} = require 'text-buffer'

module.exports =
class LinesYardstick
  constructor: (@model) ->
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
    screenPosition = @model.clipScreenPosition(screenPosition) if clip

    targetRow = screenPosition.row
    targetColumn = screenPosition.column

    top = targetRow * @model.getLineHeightInPixels()
    left = @leftPixelPositionForScreenPosition(screenPosition)

    {top, left}

  screenPositionForPixelPosition: (pixelPosition) ->
    targetTop = Math.ceil(pixelPosition.top)
    targetLeft = Math.ceil(pixelPosition.left)

    row = Math.floor(targetTop / @model.getLineHeightInPixels())
    targetLeft = 0 if row < 0
    targetLeft = Infinity if row > @getLastScreenRow()
    row = Math.min(row, @getLastScreenRow())
    row = Math.max(0, row)
    line = @model.tokenizedLineForScreenRow(row)

    column = @screenColumnForLeftPixelPosition(row, targetLeft)

    new Point(row, column)

  currentFontForTokenIterator: ->
    scopesIdentifier = @identifierForScopes(@tokenIterator.getScopes())
    @fontsByScopesIdentifier[scopesIdentifier] or @defaultFont

  leftPixelPositionForScreenPosition: (screenPosition) ->
    line = @model.tokenizedLineForScreenRow(screenPosition.row)
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
    line = @model.tokenizedLineForScreenRow(row)
    left = 0
    column = 0

    indexWithinToken = null
    tokenText = null
    @tokenIterator.reset(line)
    while @tokenIterator.next()
      newFont = @currentFontForTokenIterator()
      if newFont isnt @measuringContextFont
        @measuringContext.font = @measuringContextFont = newFont

      tokenText = @tokenIterator.getText()
      tokenWidth = @measuringContext.measureText(tokenText).width
      if left + tokenWidth >= targetLeft
        indexWithinToken = 0
        break

      indexWithinToken = tokenText.length
      left += tokenWidth
      column += tokenText.length

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

  getLastScreenRow: ->
    if @model.getLastRow?
      @model.getLastRow()
    else
      @model.getLastScreenRow()
