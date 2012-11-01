_ = require 'underscore'

module.exports =
class ScreenLine
  constructor: ({@tokens, @stack, @bufferRows, @startBufferColumn, @fold, @foldable}) ->
    @bufferRows ?= 1
    @startBufferColumn ?= 0
    @foldable ?= false
    @text = _.pluck(@tokens, 'value').join('')

  copy: ->
    new ScreenLine({@tokens, @stack, @bufferRows, @startBufferColumn, @fold, @foldable})

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
    @clipScreenColumn(bufferColumn - @startBufferColumn)

  bufferColumnForScreenColumn: (screenColumn, options) ->
    @startBufferColumn + screenColumn

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
      stack: @stack
      foldable: @foldable
    )
    rightFragment = new ScreenLine(
      tokens: rightTokens
      startBufferColumn: @startBufferColumn + column
      stack: @stack
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
