_ = require 'underscore'

module.exports =
class Parser
  constructor: (@grammar) ->

  getLineTokens: (line, stateStack=@initialStateStack()) ->
    tokens = []
    currentScopes = _.pluck(stateStack, 'scopeName')
    state = _.last(stateStack)

    startPosition = 0
    loop
      { match, pattern } = @findNextMatch(line, state.patterns, startPosition)

      if not match or match.index > startPosition
        nextPosition = match?.index ? line.length
        if nextPosition > startPosition
          tokens.push
            value: line[startPosition...nextPosition]
            scopes: new Array(currentScopes...)
          startPosition = nextPosition

      break unless match

      tokens.push(@tokensForMatch(match, pattern, startPosition, currentScopes)...)
      startPosition += match[0].length

    { state, tokens }

  findNextMatch: (line, patterns, startPosition) ->
    firstMatch = null
    matchedPattern = null
    for pattern in patterns
      if match = pattern.match.search(line, startPosition)
        if !firstMatch or match.index < firstMatch.index
          firstMatch = match
          matchedPattern = pattern

    { match: firstMatch, pattern: matchedPattern }

  tokensForMatch: (match, pattern, matchStartPosition, scopes) ->
    tokens = []
    scopes = scopes.concat(pattern.name)
    if captures = pattern.captures
      tokens.push(@tokensForMatchWithCaptures(match, captures, matchStartPosition, scopes)...)
    else
      tokens.push(value: match[0], scopes: scopes)
    tokens

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

  constructor: ({@scopeName, @patterns}) ->
    for pattern in @patterns
      pattern.match = new OnigRegExp(pattern.match)