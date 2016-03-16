{Point} = require 'text-buffer'
{isPairedCharacter} = require '../src/text-utils'

module.exports =
class FakeLinesYardstick
  constructor: (@model, @lineTopIndex) ->
    {@displayLayer} = @model
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

    top = @lineTopIndex.pixelPositionAfterBlocksForRow(targetRow)
    left = 0
    column = 0

    for {tokens} in @displayLayer.getScreenLines(targetRow, targetRow + 1)[0]
      scopes = []
      for {text, closeTags, openTags} in tokens
        scopes.splice(scopes.lastIndexOf(closeTag), 1) for closeTag in closeTags
        scopes.push(openTag) for openTag in openTags

        characterWidths = @getScopedCharacterWidths(iterator.getScopes())
        valueIndex = 0
        while valueIndex < text.length
          if isPairedCharacter(text, valueIndex)
            char = text[valueIndex...valueIndex + 2]
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
