_ = require 'underscore'

module.exports =
class Parser
  constructor: (@grammar) ->

  getLineTokens: (line, stateStack=@initialStateStack()) ->
    tokens = []
    currentScopes = _.pluck(stateStack, 'scopeName')
    state = _.last(stateStack)

    bestMatch = { index: Infinity }
    bestPattern = null
    for pattern in state.patterns
      if match = pattern.match.search(line)
        if match.index < bestMatch.index
          bestMatch = match
          bestPattern = pattern

    if bestPattern
      currentScopes = currentScopes.concat(bestPattern.name)

      if captures = bestPattern.captures
        endOfLastCapture = 0
        for captureIndex in _.keys(captures)
          captureStartPosition = bestMatch.indices[captureIndex]
          captureText = bestMatch[captureIndex]
          captureScopeName = captures[captureIndex].name

          if endOfLastCapture < captureStartPosition
            tokens.push
              value: bestMatch[0][endOfLastCapture...captureStartPosition]
              scopes: currentScopes

          tokens.push
            value: captureText
            scopes: currentScopes.concat(captureScopeName)

          endOfLastCapture = captureStartPosition + captureText.length
      else
        tokens.push
          value: bestMatch[0]
          scopes: currentScopes

    { state, tokens }

  initialStateStack: ->
    [new ParserState(@grammar)]

class ParserState
  scopeName: null
  patterns: null

  constructor: ({@scopeName, @patterns}) ->
    for pattern in @patterns
      pattern.match = new OnigRegExp(pattern.match)