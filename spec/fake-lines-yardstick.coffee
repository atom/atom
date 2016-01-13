{Point} = require 'text-buffer'

module.exports =
class FakeLinesYardstick
  constructor: (@model) ->
    @characterWidthsByScope = {}

  getScopedCharacterWidth: (scopeNames, char) ->
    @getScopedCharacterWidths(scopeNames)[char]

  getScopedCharacterWidths: (scopeNames) ->
    scope = @characterWidthsByScope
    for scopeName in scopeNames
      scope[scopeName] ?= {}
      scope = scope[scopeName]
    scope.characterWidths ?= {}
    scope.characterWidths

  setScopedCharacterWidth: (scopeNames, character, width) ->
    @getScopedCharacterWidths(scopeNames)[character] = width

  pixelPositionForScreenPosition: (screenPosition) ->
    screenPosition = Point.fromObject(screenPosition)

    targetRow = screenPosition.row
    targetColumn = screenPosition.column
    baseCharacterWidth = @model.getDefaultCharWidth()

    top = targetRow * @model.getLineHeightInPixels()
    left = 0
    column = 0

    iterator = @model.tokenizedLineForScreenRow(targetRow).getTokenIterator()
    while iterator.next()
      characterWidths = @getScopedCharacterWidths(iterator.getScopes())

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

    {top, left}
