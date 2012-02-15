_ = require 'underscore'

module.exports =
class ScreenLine
  tokens: null
  text: null
  state: null

  constructor: (@tokens, @text, @state) ->

  pushToken: (token) ->
    @tokens.push(token)
    @text += token.value

  concat: (otherLine) ->
    new ScreenLine(@tokens.concat(otherLine.tokens), @text + otherLine.text)

  splitAt: (column) ->
    return [this] if column == 0 or column >= @text.length

    rightTokens = _.clone(@tokens)
    leftTokens = []
    leftTextLength = 0
    while leftTextLength < column
      if leftTextLength + rightTokens[0].value.length > column
        rightTokens[0..0] = @splitTokenAt(rightTokens[0], column - leftTextLength)
      nextToken = rightTokens.shift()
      leftTextLength += nextToken.value.length
      leftTokens.push nextToken

    leftLine = new ScreenLine(leftTokens, @text.substring(0, column))
    rightLine = new ScreenLine(rightTokens, @text.substring(column))
    [leftLine, rightLine]

  splitTokenAt: (token, splitIndex) ->
    { type, value } = token
    value1 = value.substring(0, splitIndex)
    value2 = value.substring(splitIndex)
    [{value: value1, type }, {value: value2, type}]
