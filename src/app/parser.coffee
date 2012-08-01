_ = require 'underscore'

module.exports =
class Parser
  grammar: null

  constructor: (data) ->
    @grammar = new Grammar(data)

  getLineTokens: (line, currentRule=@grammar.initialRule) ->
    tokens = []
    position = 0

    loop
      break if position == line.length

      { nextTokens, tokensStartPosition, tokensEndPosition, nextRule } = currentRule.getNextTokens(line, position)

      if nextTokens
        if position < tokensStartPosition # unmatched text preceding next tokens
          tokens.push
            value: line[position...tokensStartPosition]
            scopes: currentRule.getScopes()

        tokens.push(nextTokens...)
        position = tokensEndPosition
        currentRule = nextRule
      else
        tokens.push
          value: line[position...line.length]
          scopes: currentRule.getScopes()
        break

    { tokens, currentRule }

class Grammar
  initialRule: null

  constructor: ({ scopeName, patterns, @repository }) ->
    @initialRule = new Rule(this, {scopeName, patterns})

class Rule
  grammar: null
  parentRule: null
  scopeName: null
  patterns: null
  endPattern: null

  constructor: (@grammar, {@parentRule, @scopeName, patterns, @endPattern}) ->
    patterns ?= []
    @patterns = patterns.map (pattern) => new Pattern(this, pattern)
    @patterns.push(@endPattern) if @endPattern

  getNextTokens: (line, position) ->
    { match, pattern } = @getNextMatch(line, position)
    return {} unless match

    { tokens, nextRule } = pattern.getTokensForMatch(match)

    nextTokens = tokens
    tokensStartPosition = match.index
    tokensEndPosition = tokensStartPosition + match[0].length
    { nextTokens, tokensStartPosition, tokensEndPosition, nextRule }

  getNextMatch: (line, position) ->
    nextMatch = null
    matchedPattern = null
    for pattern in @patterns
      { match, pattern } = pattern.getNextMatch(line, position)
      if match
        if !nextMatch or match.index < nextMatch.index
          nextMatch = match
          matchedPattern = pattern
    { match: nextMatch, pattern: matchedPattern }

  getScopes: ->
    scopes = @parentRule?.getScopes() ? []
    scopes = scopes.concat(@scopeName) if @scopeName
    scopes

class Pattern
  parentRule: null
  nextRule: null
  scopeName: null
  regex: null
  captures: null

  constructor: (@parentRule, { name, match, begin, end, captures, beginCaptures, endCaptures, patterns, include}) ->
    if include
      patterns = @parentRule.grammar.repository[include.replace(/^#/, '')]?.patterns
      @includeRule = new Rule @parentRule.grammar, {@parentRule, patterns}
    else
      @scopeName = name
      if match
        @regex = new OnigRegExp(match)
        @captures = captures
        @nextRule = @parentRule
      else if begin
        @regex = new OnigRegExp(begin)
        @captures = beginCaptures ? captures
        endPattern = new Pattern(@parentRule, { name: @scopeName, match: end, captures: endCaptures ? captures })
        @nextRule = new Rule(@parentRule.grammar, {@parentRule, @scopeName, patterns, endPattern})

  getNextMatch: (line, position) ->
    if @includeRule
      @includeRule.getNextMatch(line, position)
    else
      {pattern: this, match: @regex?.search(line, position)}

  getTokensForMatch: (match) ->
    tokens = []
    if @captures
      tokens = @getTokensForMatchWithCaptures(match)
    else
      tokens = [{ value: match[0], scopes: @getScopes() }]

    { tokens, @nextRule }

  getTokensForMatchWithCaptures: (match) ->
    tokens = []
    previousCaptureEndPosition = 0

    for captureIndex in _.keys(@captures)
      currentCaptureStartPosition = match.indices[captureIndex] - match.index
      currentCaptureText = match[captureIndex]
      currentCaptureScopeName = @captures[captureIndex].name

      if previousCaptureEndPosition < currentCaptureStartPosition
        tokens.push
          value: match[0][previousCaptureEndPosition...currentCaptureStartPosition]
          scopes: @getScopes()

      tokens.push
        value: currentCaptureText
        scopes: @getScopes().concat(currentCaptureScopeName)

      previousCaptureEndPosition = currentCaptureStartPosition + currentCaptureText.length

    if previousCaptureEndPosition < match[0].length
      tokens.push
        value: match[0][previousCaptureEndPosition...match[0].length]
        scopens: @getScopes()

    tokens

  getScopes: ->
    @parentRule.getScopes().concat(@scopeName)