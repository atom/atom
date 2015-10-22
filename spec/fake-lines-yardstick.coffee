{Point} = require 'text-buffer'

module.exports =
class FakeLinesYardstick
  constructor: (@model, @presenter) ->
    @characterWidthsByScope = {}

  prepareScreenRowsForMeasurement: ->
    @presenter.getPreMeasurementState()

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

  pixelPositionForScreenPosition: (screenPosition, clip=true) ->
    screenPosition = Point.fromObject(screenPosition)
    screenPosition = @model.clipScreenPosition(screenPosition) if clip

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

  pixelRectForScreenRange: (screenRange) ->
    lineHeight = @model.getLineHeightInPixels()

    if screenRange.end.row > screenRange.start.row
      top = @pixelPositionForScreenPosition(screenRange.start).top
      left = 0
      height = (screenRange.end.row - screenRange.start.row + 1) * lineHeight
      width = @presenter.getScrollWidth()
    else
      {top, left} = @pixelPositionForScreenPosition(screenRange.start, false)
      height = lineHeight
      width = @pixelPositionForScreenPosition(screenRange.end, false).left - left

    {top, left, width, height}
