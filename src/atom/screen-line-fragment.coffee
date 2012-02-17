_ = require 'underscore'
Delta = require 'delta'

module.exports =
class ScreenLineFragment
  constructor: (@tokens, @text, screenDelta, bufferDelta) ->
    @screenDelta = Delta.fromObject(screenDelta)
    @bufferDelta = Delta.fromObject(bufferDelta)


  splitAt: (column) ->
    return [undefined, this] if column == 0
    return [this, undefined] if column >= @text.length

    rightTokens = _.clone(@tokens)
    leftTokens = []
    leftTextLength = 0
    while leftTextLength < column
      if leftTextLength + rightTokens[0].value.length > column
        rightTokens[0..0] = @splitTokenAt(rightTokens[0], column - leftTextLength)
      nextToken = rightTokens.shift()
      leftTextLength += nextToken.value.length
      leftTokens.push nextToken

    leftText = @text.substring(0, column)
    rightText = @text.substring(column)

    [leftScreenDelta, rightScreenDelta] = @screenDelta.splitAt(column)
    [leftBufferDelta, rightBufferDelta] = @bufferDelta.splitAt(column)

    leftFragment = new ScreenLineFragment(leftTokens, leftText, leftScreenDelta, leftBufferDelta)
    rightFragment = new ScreenLineFragment(rightTokens, rightText, rightScreenDelta, rightBufferDelta)
    [leftFragment, rightFragment]

  splitTokenAt: (token, splitIndex) ->
    { type, value } = token
    value1 = value.substring(0, splitIndex)
    value2 = value.substring(splitIndex)
    [{value: value1, type }, {value: value2, type}]
