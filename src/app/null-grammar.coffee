Token = require 'token'

module.exports =
class NullGrammar
  name: 'Null Grammar'
  scopeName: 'text.plain.null-grammar'

  tokenizeLine: (line) ->
    { tokens: [new Token(value: line, scopes: ['null-grammar.text.plain'])] }
