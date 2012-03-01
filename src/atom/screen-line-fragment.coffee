_ = require 'underscore'
Point = require 'point'

module.exports =
class ScreenLineFragment
  isAtomic: false

  constructor: (@tokens, @text, outputDelta, inputDelta, extraFields) ->
    @outputDelta = Point.fromObject(outputDelta)
    @inputDelta = Point.fromObject(inputDelta)
    _.extend(this, extraFields)

  splitAt: (column) ->
    return [undefined, this] if column == 0

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

    [leftScreenDelta, rightScreenDelta] = @outputDelta.splitAt(column)
    [leftBufferDelta, rightBufferDelta] = @inputDelta.splitAt(column)

    leftFragment = new ScreenLineFragment(leftTokens, leftText, leftScreenDelta, leftBufferDelta)
    rightFragment = new ScreenLineFragment(rightTokens, rightText, rightScreenDelta, rightBufferDelta)
    [leftFragment, rightFragment]

  splitTokenAt: (token, splitIndex) ->
    { type, value } = token
    value1 = value.substring(0, splitIndex)
    value2 = value.substring(splitIndex)
    [{value: value1, type }, {value: value2, type}]

  concat: (other) ->
    tokens = @tokens.concat(other.tokens)
    text = @text + other.text
    outputDelta = @outputDelta.add(other.outputDelta)
    inputDelta = @inputDelta.add(other.inputDelta)
    new ScreenLineFragment(tokens, text, outputDelta, inputDelta)

  lengthForClipping: ->
    if @isAtomic
      0
    else
      @text.length

  isSoftWrapped: ->
    @outputDelta.row == 1 and @inputDelta.row == 0

  isEqual: (other) ->
    _.isEqual(@tokens, other.tokens) and @outputDelta.isEqual(other.outputDelta) and @inputDelta.isEqual(other.inputDelta)
