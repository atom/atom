_ = require 'underscore'
fs = require 'fs'
plist = require 'plist'

module.exports =
class TextMateGrammar
  @loadFromPath: (path) ->
    grammar = null
    plist.parseString fs.read(path), (e, data) ->
      throw new Error(e) if e
      grammar = new TextMateGrammar(data[0])
    grammar

  name: null
  repository: null
  initialRule: null

  constructor: ({ @name, @fileTypes, scopeName, patterns, repository }) ->
    @initialRule = new Rule(this, {scopeName, patterns})
    @repository = {}
    for name, data of repository
      @repository[name] = new Rule(this, data)

    for rule in [@initialRule, _.values(@repository)...]
      rule.compileRegex()

  getLineTokens: (line, stack=[@initialRule]) ->
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

  ruleForInclude: (name) ->
    if name[0] == "#"
      @repository[name[1..]]
    else if name == "$self"
      @initialRule

class Rule
  grammar: null
  scopeName: null
  patterns: null
  endPattern: null

  constructor: (@grammar, {@scopeName, patterns, @endPattern}) ->
    patterns ?= []
    @patterns = []
    @patterns.push(@endPattern) if @endPattern
    @patterns.push((patterns.map (pattern) => new Pattern(grammar, pattern))...)

  compileRegex: ->
    regexComponents = []
    @patternsByCaptureIndex = {}
    currentCaptureIndex = 1
    for [regex, pattern] in @getRegexPatternPairs()
      regexComponents.push(regex.source)
      @patternsByCaptureIndex[currentCaptureIndex] = pattern
      currentCaptureIndex += 1 + regex.getCaptureCount()
    @regex = new OnigRegExp('(' + regexComponents.join(')|(') + ')')

    pattern.compileRegex() for pattern in @patterns

  getRegexPatternPairs: (included=[]) ->
    return [] if _.include(included, this)
    included.push(this)
    regexPatternPairs = []

    regexPatternPairs.push(@endPattern.getRegexPatternPairs()...) if @endPattern
    for pattern in @patterns
      regexPatternPairs.push(pattern.getRegexPatternPairs(included)...)
    regexPatternPairs

  getNextTokens: (stack, line, position) ->
    tree = @regex.getCaptureTree(line, position)
    return {} unless tree?.captures

    match = tree.captures[0]
    pattern = @patternsByCaptureIndex[match.index]
    @adjustCaptureTreeIndices(match, match.index)
    nextTokens = pattern.handleMatch(stack, match)
    tokensStartPosition = match.position
    tokensEndPosition = tokensStartPosition + match.text.length

    { nextTokens, tokensStartPosition, tokensEndPosition }

  adjustCaptureTreeIndices: (tree, startIndex) ->
    tree.index -= startIndex
    for capture in tree.captures ? []
      @adjustCaptureTreeIndices(capture, startIndex)

  getNextMatch: (line, position) ->
    nextMatch = null
    matchedPattern = null

    for pattern in @patterns
      { pattern, match } = pattern.getNextMatch(line, position)
      if match
        if !nextMatch or match.position < nextMatch.position
          nextMatch = match
          matchedPattern = pattern

    { match: nextMatch, pattern: matchedPattern }

class Pattern
  grammar: null
  pushRule: null
  popRule: false
  scopeName: null
  regex: null
  captures: null

  constructor: (@grammar, { name, contentName, @include, match, begin, end, captures, beginCaptures, endCaptures, patterns, @popRule}) ->
    @scopeName = name ? contentName # TODO: We need special treatment of contentName
    if match
      @regex = new OnigRegExp(match)
      @captures = captures
    else if begin
      @regex = new OnigRegExp(begin)
      @captures = beginCaptures ? captures
      endPattern = new Pattern(@grammar, { match: end, captures: endCaptures ? captures, popRule: true})
      @pushRule = new Rule(@grammar, { @scopeName, patterns, endPattern })

  getRegexPatternPairs: (included) ->
    if @include
      rule = @grammar.ruleForInclude(@include)
      console.log "Could not find rule for include #{@include} in #{@grammar.name} grammar" unless rule
      rule?.getRegexPatternPairs(included) ? []
    else
      [[@regex, this]]

  compileRegex: ->
    @pushRule?.compileRegex()

  getNextMatch: (line, position) ->
    if @include
      rule = @grammar.ruleForInclude(@include)
      rule.getNextMatch(line, position)
    else
      { match: @regex.getCaptureTree(line, position), pattern: this }

  handleMatch: (stack, match) ->
    scopes = _.pluck(stack, "scopeName")
    scopes.push(@scopeName) unless @popRule

    if @captures
      tokens = @getTokensForCaptureTree(match, scopes)
    else
      tokens = [{ value: match.text, scopes: scopes }]

    if @pushRule
      stack.push(@pushRule)
    else if @popRule
      stack.pop()

    tokens

  getTokensForCaptureTree: (tree, scopes) ->
    tokens = []
    if scope = @captures[tree.index]?.name
      scopes = scopes.concat(scope)

    previousCaptureEndPosition = 0
    if tree.captures
      for capture in tree.captures
        continue unless capture.text.length # TODO: This can be removed since the tree will have no empty captures

        currentCaptureStartPosition = capture.position - tree.position
        if previousCaptureEndPosition < currentCaptureStartPosition
          tokens.push
            value: tree.text[previousCaptureEndPosition...currentCaptureStartPosition]
            scopes: scopes

        captureTokens = @getTokensForCaptureTree(capture, scopes)
        tokens.push(captureTokens...)
        previousCaptureEndPosition = currentCaptureStartPosition + capture.text.length

    if previousCaptureEndPosition < tree.text.length
      tokens.push
        value: tree.text[previousCaptureEndPosition...tree.text.length]
        scopes: scopes

    tokens
