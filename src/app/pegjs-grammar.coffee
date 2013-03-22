PEG = require('pegjs')
Token = require('token')
fs = require('fs-utils')
_ = require('underscore')

module.exports =
class PEGjsGrammar

  class TokenTree
    constructor: {@tokens, @type, @text}

  class Rule
    constructor: {@value, @scopeName}

  constructor: (@name, @grammarFile, @fileTypes, @scopeName) ->
    @parser = PEG.buildParser fs.read(@grammarFile),
                                cache:    false
                                output:   "parser"
                                optimize: "speed"
                                plugins:  []
    @parserCache  = {}

  tokenizeLine: (line, ruleStack=undefined, lineNumber) ->
    @parserCache = {} if lineNumber == 0

    mixedOutput = @parser.parse(line, cache: @parserCache)
    tokenTree = @normalizeOutput(mixedOutput)
    tokens = @convertTokenTree(tokenTree, [@scopeName])

    {tokens: tokens}

  convertTokenTree: (tokenTree, scopeStack) ->
    scopeStack = @combineStacks(scopeStack, tokenTree.type) if tokenTree.type?

    childTokens = _.flatten(tokenTree.tokens.map((child)=>@convertTokenTree(child, scopeStack)))

    @reduceTokens(@collapseTokenTree(tokenTree, childTokens, scopeStack))

  combineStacks: (stack, type) ->
    typeStack = if _.isArray(type) then [type...] else [type]
    stack.concat(typeStack)

  collapseTokenTree: (treeToken, childTokens, scopeStack) ->
    return [] if _.isEmpty(childTokens) and !treeToken.text?.length
    return [@buildToken(treeToken.text, scopeStack)] if _.isEmpty(childTokens)

    childText = childTokens.map((childToken)->childToken.value).join('')

    return childTokens unless treeToken.text?.length
    return childTokens if childText == treeToken.text

    tokens = []
    buf = treeToken.text

    childTokens.forEach (childToken) ->
      [text, buf] = buf.split(childToken.value)
      buf = buf.join(childToken.value)

      tokens.push(@buildToken(text, scopeStack)) if text?.length
      tokens.push(childToken)

    tokens.push(@buildToken(buf, scopeStack)) if buf?.length

    tokens

  buildToken: (value, scopeStack) ->
    new Token(value: value, scopes: [scopeStack...])

  reduceTokens: (tokens) ->
    return tokens if tokens.length < 2

    [first, second, remaining...] = tokens

    if @isCombinable(first, second)
      @reduceTokens([@combineTokens(first, second), remaining...])
    else
      [first, @reduceTokens([second, remaining...])...]

  isCombinable: (a, b) ->
    _.isEqual(a.scopes, b.scopes)

  combineTokens: (a, b) ->
    @buildToken([a.value, b.value].join(''), _.uniq(a.scopes, b.scopes))

  normalizeOutput: (output) ->
    if _.isArray(output)
      @buildTokenTree({tokens: output})
    else if _.isObject(output)
      @buildTokenTree(output)
    else if _.isString(output)
      @buildTokenTree({text: output})

  buildTokenTree: (parent) ->
    if _.isArray(parent.tokens)
      outputs = parent.tokens
    else if _.isObject(parent.tokens)
      outputs = [parent.tokens]
    else
      outputs = []

    children = outputs.map((output)=>@normalizeOutput(output))

    parent.tokens = children

    parent
