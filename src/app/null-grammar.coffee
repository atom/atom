Token = require 'token'
EventEmitter = require 'event-emitter'
_ = require 'underscore'

### Internal ###
module.exports =
class NullGrammar
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

_.extend NullGrammar.prototype, EventEmitter
