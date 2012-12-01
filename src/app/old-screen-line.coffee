_ = require 'underscore'
Point = require 'app/point'

module.exports =
class ScreenLine
  stack: null
  text: null
  tokens: null
  screenDelta: null
  bufferDelta: null
  foldable: null

  constructor: (@tokens, @text, screenDelta, bufferDelta, extraFields) ->
    @screenDelta = Point.fromObject(screenDelta)
    @bufferDelta = Point.fromObject(bufferDelta)
    _.extend(this, extraFields)

  copy: ->
    new ScreenLine(@tokens, @text, @screenDelta, @bufferDelta, { @stack, @foldable })

  splitAt: (column) ->
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

    leftText = _.pluck(leftTokens, 'value').join('')
    rightText = _.pluck(rightTokens, 'value').join('')

    [leftScreenDelta, rightScreenDelta] = @screenDelta.splitAt(column)
    [leftBufferDelta, rightBufferDelta] = @bufferDelta.splitAt(column)

    leftFragment = new ScreenLine(leftTokens, leftText, leftScreenDelta, leftBufferDelta, {@stack, @foldable})
    rightFragment = new ScreenLine(rightTokens, rightText, rightScreenDelta, rightBufferDelta, {@stack})
    [leftFragment, rightFragment]

  tokenAtBufferColumn: (bufferColumn) ->
    delta = 0
    for token in @tokens
      delta += token.bufferDelta
      return token if delta >= bufferColumn
    token

  concat: (other) ->
    tokens = @tokens.concat(other.tokens)
    text = @text + other.text
    screenDelta = @screenDelta.add(other.screenDelta)
    bufferDelta = @bufferDelta.add(other.bufferDelta)
    new ScreenLine(tokens, text, screenDelta, bufferDelta, {stack: other.stack})

  translateColumn: (sourceDeltaType, targetDeltaType, sourceColumn, options={}) ->
    { skipAtomicTokens } = options
    sourceColumn = Math.min(sourceColumn, @textLength())

    isSourceColumnBeforeLastToken = false
    tokenStartTargetColumn = 0
    tokenStartSourceColumn = 0

    for token in @tokens
      tokenEndSourceColumn = tokenStartSourceColumn + token[sourceDeltaType]
      tokenEndTargetColumn = tokenStartTargetColumn + token[targetDeltaType]
      break if tokenEndSourceColumn > sourceColumn
      tokenStartTargetColumn = tokenEndTargetColumn
      tokenStartSourceColumn = tokenEndSourceColumn

    sourceColumnIsInsideToken = tokenStartSourceColumn < sourceColumn < tokenEndSourceColumn

    if token?.isAtomic and sourceColumnIsInsideToken
      if skipAtomicTokens
        tokenEndTargetColumn
      else
        tokenStartTargetColumn
    else
      remainingColumns = sourceColumn - tokenStartSourceColumn
      tokenStartTargetColumn + remainingColumns

  textLength: ->
    if @fold
      textLength = 0
    else
      textLength = @text.length

  isSoftWrapped: ->
    @screenDelta.row == 1 and @bufferDelta.row == 0

  isEqual: (other) ->
    _.isEqual(@tokens, other.tokens) and @screenDelta.isEqual(other.screenDelta) and @bufferDelta.isEqual(other.bufferDelta)
