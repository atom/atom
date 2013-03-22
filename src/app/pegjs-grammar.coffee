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
                                cache:    true
                                output:   "parser"
                                optimize: "speed"
                                plugins:  []
    @parserCache  = {}

  batchTokenizeLine: (buffer, lineNumber) ->
    @parserCache = {}

    lines = buffer.getText()

    lineRegion = @lineRegion(buffer.lines, lineNumber)

    mixedOutput = @parser.parse(lines, cache: @parserCache)
    tokenTree = @normalizeOutput(mixedOutput)
    allTokens = @convertTokenTree(tokenTree, [@scopeName])

    tokens = @pruneTokensRegion(allTokens, lineRegion)

    {tokens: tokens}

  lineRegion: (lines, lineNumber) ->
    lines = _.map(lines, (line)->"#{line}\n")
    [
      start = _.first(lines, lineNumber).join('').length,
      start + lines[lineNumber].length
    ]

  pruneTokensRegion: (tokens, region) ->
    [start, end] = region

    startPositions = []
    endPositions = []

    iter = (startPosition, token) ->
      endPosition = startPosition + token.value.length - 1
      startPositions.push(startPosition)
      endPositions.push(endPosition)
      endPosition + 1

    _.reduce(tokens, iter, 0)

    matches = _.filter _.zip(tokens, startPositions, endPositions), ([token, startPos, endPos]) ->
      startPos >= start and endPos < end

    _.map(matches, ([token, _...])->token)

  buildTokenMap: (tokens) ->
    tokenMap = {}

    builder = (sum, token) ->
      tokenMap[sum] = token
      sum + token.value.length

    _.reduce tokens, builder, 0

    tokenMap

  tokenizeLine: (line, ruleStack=undefined, lineNumber) ->
    @parserCache = {}

    mixedOutput = @parser.parse(line, cache: @parserCache)
    tokenTree = @normalizeOutput(mixedOutput)
    tokens = @convertTokenTree(tokenTree, [@scopeName])

    {tokens: tokens}

  convertTokenTree: (tokenTree, scopeStack) ->
    scopeStack = scopeStack.concat(tokenTree.type) if tokenTree.type?

    childTokens = _.flatten(tokenTree.tokens.map((child)=>@convertTokenTree(child, scopeStack)))

    @reduceTokens(@collapseTokenTree(tokenTree, childTokens, scopeStack))

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

    if @isMultiline(first)
      [a, b] = @splitToken(first)
      [a, @reduceTokens([b, second, remaining...])...]
    else if @isCombinable(first, second)
      @reduceTokens([@combineTokens(first, second), remaining...])
    else
      [first, @reduceTokens([second, remaining...])...]

  isMultiline: (token) ->
    /\n./.test(token.value)

  splitToken: (token) ->
    [a, b] = token.value.split("\n")
    [@buildToken("#{a}\n", token.scopes), @buildToken(b, token.scopes)]

  isCombinable: (a, b) ->
    _.isEqual(a.scopes, b.scopes) or /\n./.test(a.value)

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
