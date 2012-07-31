_ = require 'underscore'

module.exports =
class Parser
  constructor: (@grammar) ->

  getLineTokens: (line, stateStack=@initialStateStack()) ->
    lineTokens = []

    startPosition = 0
    loop
      { match, pattern } = @findNextMatch(line, _.last(stateStack).patterns, startPosition)
      currentScopes = _.pluck(stateStack, 'scopeName')

      if not match or match.index > startPosition
        nextPosition = match?.index ? line.length
        if nextPosition > startPosition
          lineTokens.push
            value: line[startPosition...nextPosition]
            scopes: new Array(currentScopes...)
          startPosition = nextPosition

      break unless match

      { tokens, stateStack } = @tokensForMatch(match, pattern, startPosition, currentScopes, stateStack)

      lineTokens.push(tokens...)
      startPosition += match[0].length

    { state: stateStack, tokens: lineTokens }

  findNextMatch: (line, patterns, startPosition) ->
    firstMatch = null
    matchedPattern = null
    for pattern in patterns
      continue unless regex = pattern.begin or pattern.match
      if match = regex.search(line, startPosition)
        if !firstMatch or match.index < firstMatch.index
          firstMatch = match
          matchedPattern = pattern

    { match: firstMatch, pattern: matchedPattern }

  tokensForMatch: (match, pattern, matchStartPosition, scopes, stateStack) ->
    tokens = []
    scopes = scopes.concat(pattern.name) if pattern.name

    captures = pattern.captures
    if pattern.begin
      captures ?= pattern.beginCaptures
      stateStack = stateStack.concat(ParserState.forPattern(pattern))
    else if pattern.popStateStack
      stateStack = stateStack[0...-1]

    if captures
      tokens.push(@tokensForMatchWithCaptures(match, captures, matchStartPosition, scopes)...)
    else
      tokens.push(value: match[0], scopes: scopes)

    { tokens, stateStack }

  tokensForMatchWithCaptures: (match, captures, matchStartPosition, scopes) ->
    tokens = []
    endOfLastCapture = 0
    for captureIndex in _.keys(captures)
      captureStartPosition = match.indices[captureIndex] - matchStartPosition
      captureText = match[captureIndex]
      captureScopeName = captures[captureIndex].name

      if endOfLastCapture < captureStartPosition
        tokens.push
          value: match[0][endOfLastCapture...captureStartPosition]
          scopes: scopes

      tokens.push
        value: captureText
        scopes: scopes.concat(captureScopeName)

      endOfLastCapture = captureStartPosition + captureText.length
    tokens

  initialStateStack: ->
    [new ParserState(@grammar)]

class ParserState
  scopeName: null
  patterns: null

  @forPattern: (pattern) ->
    endPattern =
      popStateStack: true
      match: pattern.endSource
      captures: pattern.endCaptures
    new ParserState(scopeName: pattern.name, patterns: [endPattern])

  constructor: ({@scopeName, @patterns}) ->
    for pattern in @patterns
      if pattern.match
        pattern.matchSource = pattern.match
        pattern.match = new OnigRegExp(pattern.match)
      else if pattern.begin
        pattern.beginSource = pattern.begin
        pattern.begin = new OnigRegExp(pattern.begin)
        pattern.endSource = pattern.end
        pattern.end = new OnigRegExp(pattern.end)