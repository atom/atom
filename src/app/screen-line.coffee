_ = require 'underscore'

module.exports =
class ScreenLine
  constructor: ({tokens, @ruleStack, @bufferRows, @startBufferColumn, @fold, tabLength}) ->
    @tokens = @breakOutAtomicTokens(tokens, tabLength)
    @bufferRows ?= 1
    @startBufferColumn ?= 0
    @text = _.pluck(@tokens, 'value').join('')

  copy: ->
    new ScreenLine({@tokens, @ruleStack, @bufferRows, @startBufferColumn, @fold})

  clipScreenColumn: (column, options={}) ->
    { skipAtomicTokens } = options
    column = Math.min(column, @getMaxScreenColumn())

    tokenStartColumn = 0
    for token in @tokens
      break if tokenStartColumn + token.screenDelta > column
      tokenStartColumn += token.screenDelta

    if token.isAtomic and tokenStartColumn < column
      if skipAtomicTokens
        tokenStartColumn + token.screenDelta
      else
        tokenStartColumn
    else
      column

  screenColumnForBufferColumn: (bufferColumn, options) ->
    bufferColumn = bufferColumn - @startBufferColumn
    screenColumn = 0
    currentBufferColumn = 0
    for token in @tokens
      break if currentBufferColumn > bufferColumn
      screenColumn += token.screenDelta
      currentBufferColumn += token.bufferDelta
    @clipScreenColumn(screenColumn + (bufferColumn - currentBufferColumn))

  bufferColumnForScreenColumn: (screenColumn, options) ->
    bufferColumn = @startBufferColumn
    currentScreenColumn = 0
    for token in @tokens
      break if currentScreenColumn + token.screenDelta > screenColumn
      bufferColumn += token.bufferDelta
      currentScreenColumn += token.screenDelta
    bufferColumn + (screenColumn - currentScreenColumn)

  getMaxScreenColumn: ->
    if @fold
      0
    else
      @text.length

  getMaxBufferColumn: ->
    @startBufferColumn + @getMaxScreenColumn()

  softWrapAt: (column) ->
    return [new ScreenLine([], '', [0, 0], [0, 0]), this] if column == 0

    rightTokens = new Array(@tokens...)
    leftTokens = []
    leftTextLength = 0
    while leftTextLength < column
      if leftTextLength + rightTokens[0].value.length > column
        rightTokens[0..0] = rightTokens[0].splitAt(column - leftTextLength)
      nextToken = rightTokens.shift()
      leftTextLength += nextToken.value.length
      leftTokens.push nextToken

    leftFragment = new ScreenLine(
      tokens: leftTokens
      bufferRows: 0
      startBufferColumn: @startBufferColumn
      ruleStack: @ruleStack
    )
    rightFragment = new ScreenLine(
      tokens: rightTokens
      startBufferColumn: @startBufferColumn + column
      ruleStack: @ruleStack
    )
    [leftFragment, rightFragment]

  isSoftWrapped: ->
    @bufferRows == 0

  tokenAtBufferColumn: (bufferColumn) ->
    delta = 0
    for token in @tokens
      delta += token.bufferDelta
      return token if delta >= bufferColumn
    token

  breakOutAtomicTokens: (inputTokens, tabLength) ->
    outputTokens = []
    breakOutLeadingWhitespace = true
    for token in inputTokens
      outputTokens.push(token.breakOutAtomicTokens(tabLength, breakOutLeadingWhitespace)...)
      breakOutLeadingWhitespace = token.isOnlyWhitespace() if breakOutLeadingWhitespace
    outputTokens
