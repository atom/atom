_ = require 'underscore'
Point = require 'point'

module.exports =
class ScreenLineFragment
  state: null
  text: null
  tokens: null
  screenDelta: null
  bufferDelta: null

  constructor: (@tokens, @text, screenDelta, bufferDelta, extraFields) ->
    @screenDelta = Point.fromObject(screenDelta)
    @bufferDelta = Point.fromObject(bufferDelta)
    _.extend(this, extraFields)

  copy: ->
    new ScreenLineFragment(@tokens, @text, @screenDelta, @bufferDelta, { @state })

  splitAt: (column) ->
    return [new ScreenLineFragment([], '', [0, 0], [0, 0]), this] if column == 0

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

    leftFragment = new ScreenLineFragment(leftTokens, leftText, leftScreenDelta, leftBufferDelta, {@state})
    rightFragment = new ScreenLineFragment(rightTokens, rightText, rightScreenDelta, rightBufferDelta, {@state})
    [leftFragment, rightFragment]

  concat: (other) ->
    tokens = @tokens.concat(other.tokens)
    text = @text + other.text
    screenDelta = @screenDelta.add(other.screenDelta)
    bufferDelta = @bufferDelta.add(other.bufferDelta)
    new ScreenLineFragment(tokens, text, screenDelta, bufferDelta, {state: other.state})

  translateColumn: (sourceDeltaType, targetDeltaType, sourceColumn, options={}) ->
    { skipAtomicTokens } = options
    sourceColumn = Math.min(sourceColumn, @textLength())

    currentSourceColumn = 0
    currentTargetColumn = 0
    for token in @tokens
      tokenStartTargetColumn = currentTargetColumn
      tokenStartSourceColumn = currentSourceColumn
      tokenEndSourceColumn = currentSourceColumn + token[sourceDeltaType]
      tokenEndTargetColumn = currentTargetColumn + token[targetDeltaType]
      break if tokenEndSourceColumn > sourceColumn
      currentSourceColumn = tokenEndSourceColumn
      currentTargetColumn = tokenEndTargetColumn

    if token?.isAtomic
      if skipAtomicTokens and sourceColumn > tokenStartSourceColumn
        tokenEndTargetColumn
      else
        tokenStartTargetColumn
    else
      remainingColumns = sourceColumn - currentSourceColumn
      currentTargetColumn + remainingColumns

  textLength: ->
    if @fold
      textLength = 0
    else
      textLength = @text.length

  isSoftWrapped: ->
    @screenDelta.row == 1 and @bufferDelta.row == 0

  isEqual: (other) ->
    _.isEqual(@tokens, other.tokens) and @screenDelta.isEqual(other.screenDelta) and @bufferDelta.isEqual(other.bufferDelta)
