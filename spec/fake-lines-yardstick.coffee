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

    top = @lineTopIndex.pixelPositionAfterBlocksForRow(targetRow)
    left = 0
    column = 0

    scopes = []
    startIndex = 0
    {tagCodes, lineText} = @model.screenLineForScreenRow(targetRow)
    for tagCode in tagCodes
      if @displayLayer.isOpenTagCode(tagCode)
        scopes.push(@displayLayer.tagForCode(tagCode))
      else if @displayLayer.isCloseTagCode(tagCode)
        scopes.splice(scopes.lastIndexOf(@displayLayer.tagForCode(tagCode)), 1)
      else
        text = lineText.substr(startIndex, tagCode)
        startIndex += tagCode
        characterWidths = @getScopedCharacterWidths(scopes)

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

          left += characterWidths[char] ? @model.getDefaultCharWidth() unless char is '\0'
          column += charLength

    {top, left}
