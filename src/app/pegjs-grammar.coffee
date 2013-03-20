PEG = require('pegjs')
fs = require('fs')
_ = require('underscore')

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

    rawToken = @parser.parse(line, cache: @cache)

    {tokens: @normalizeToken(rawToken)}

  normalizeToken: (topLevelToken) ->
    @flattenTokens(@convertTokens(topLevelToken))

  convertTokens: (rawTokens...) ->
    rawTokens.map((rawToken)=>@convertToken(rawToken))

  convertToken: ({text, type}) ->
    value: text
    scopes: @buildScopes(type)

  buildScopes: (type) ->
    scope = [@scopeName]
    scope.push("source.#{type}") if type
    scope

  flattenTokens: (treeTokens) ->
    _.flatten(treeTokens.map((treeToken)=>@flattenToken(treeToken)))

  flattenToken: (parentToken) ->
    childTokens = parentToken.tokens
    delete parentToken.tokens

    return [parentToken] if !childTokens || childTokens.length == 0

    input = parentToken.value

