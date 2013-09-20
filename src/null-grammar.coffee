Token = require './token'
EventEmitter = require './event-emitter'
_ = require './underscore-extensions'

### Internal ###
module.exports =
class NullGrammar
  _.extend @prototype, EventEmitter

  name: 'Null Grammar'
  scopeName: 'text.plain.null-grammar'

  getScore: -> 0

  tokenizeLine: (line) ->
    { tokens: [new Token(value: line, scopes: ['null-grammar.text.plain'])] }

  tokenizeLines: (text) ->
    lines = text.split('\n')
    for line, i in lines
      {tokens} = @tokenizeLine(line)
      tokens

  grammarUpdated: -> # noop
