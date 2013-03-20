PEG = require('pegjs')
fs = require('fs')

module.exports =
class PEGjsGrammar
  constructor: (@name, @grammarFile, @fileTypes, @scopeName) ->
    @parser = PEG.buildParser fs.read(@grammarFile),
                                cache:    false
                                output:   "parser"
                                optimize: "speed"
                                plugins:  []
    @cache  = {}

  tokenizeLine: (line, ruleStack=undefined, lineNumber) ->
    @cache = {} if lineNumber == 0

    rawTokens = @parser.parse(line, cache: @cache)

    {tokens: rawTokens.map((token)=> @normalizeToken(token))}

  normalizeToken: (token) ->
    switch typeof(token)
      when typeof("") then value: token, scopes: @buildScopes()

  buildScopes: (scopes...) ->
    scopes.unshift(@scopeName)
    scopes