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
