_ = require 'underscore'

module.exports =
class Parser
  grammar: null

  constructor: (data) ->
    @grammar = new Grammar(data)

  getLineTokens: (line, stack=[@grammar.initialRule]) ->
    stack = new Array(stack...)
    tokens = []
    position = 0

    loop
      break if position == line.length

      scopes = _.pluck(stack, "scopeName")
      { nextTokens, tokensStartPosition, tokensEndPosition} = _.last(stack).getNextTokens(stack, line, position)

      if nextTokens
        if position < tokensStartPosition # unmatched text preceding next tokens
          tokens.push
            value: line[position...tokensStartPosition]
            scopes: scopes

        tokens.push(nextTokens...)
        position = tokensEndPosition
      else
        tokens.push
          value: line[position...line.length]
          scopes: scopes
        break

    { tokens, stack }

class Grammar
  initialRule: null

  constructor: ({ scopeName, patterns }) ->
    @initialRule = new Rule({scopeName, patterns})

class Rule
  scopeName: null
  patterns: null
  endPattern: null

  constructor: ({@scopeName, patterns, @endPattern}) ->
    patterns ?= []
    @patterns = patterns.map (pattern) => new Pattern(pattern)
    @patterns.push(@endPattern) if @endPattern

  getNextTokens: (stack, line, position) ->
    { match, pattern } = @getNextMatch(line, position)
    return {} unless match

    tokens = pattern.handleMatch(stack, match)

    nextTokens = tokens
    tokensStartPosition = match.index
    tokensEndPosition = tokensStartPosition + match[0].length
    { nextTokens, tokensStartPosition, tokensEndPosition }

  getNextMatch: (line, position) ->
    nextMatch = null
    matchedPattern = null
    for pattern in @patterns
      continue unless pattern.regex # TODO: we should eventually not need this
      if match = pattern.regex.search(line, position)
        if !nextMatch or match.index < nextMatch.index
          nextMatch = match
          matchedPattern = pattern

    console.log "Matched pattern", matchedPattern, nextMatch
    { match: nextMatch, pattern: matchedPattern }

class Pattern
  pushRule: null
  popRule: false
  scopeName: null
  regex: null
  captures: null

  constructor: ({ name, match, begin, end, captures, beginCaptures, endCaptures, patterns, @popRule}) ->
    @scopeName = name
    if match
      @regex = new OnigRegExp(match)
      @captures = captures
    else if begin
      @regex = new OnigRegExp(begin)
      @captures = beginCaptures ? captures
      endPattern = new Pattern({ match: end, captures: endCaptures ? captures, popRule: true})
      @pushRule = new Rule({ @scopeName, patterns, endPattern })

  handleMatch: (stack, match) ->
    scopes = _.pluck(stack, "scopeName")
    scopes.push(@scopeName) unless @popRule

    if @captures
      tokens = @getTokensForMatchWithCaptures(match, scopes)
    else
      tokens = [{ value: match[0], scopes: scopes }]

    if @pushRule
      stack.push(@pushRule)
    else if @popRule
      stack.pop()

    tokens

  getTokensForMatchWithCaptures: (match, scopes) ->
    tokens = []
    previousCaptureEndPosition = 0

    for captureIndex in _.keys(@captures)
      currentCaptureStartPosition = match.indices[captureIndex] - match.index
      currentCaptureText = match[captureIndex]
      currentCaptureScopeName = @captures[captureIndex].name

      if previousCaptureEndPosition < currentCaptureStartPosition
        tokens.push
          value: match[0][previousCaptureEndPosition...currentCaptureStartPosition]
          scopes: scopes

      tokens.push
        value: currentCaptureText
        scopes: scopes.concat(currentCaptureScopeName)

      previousCaptureEndPosition = currentCaptureStartPosition + currentCaptureText.length

    if previousCaptureEndPosition < match[0].length
      tokens.push
        value: match[0][previousCaptureEndPosition...match[0].length]
        scopes: scopes

    tokens
