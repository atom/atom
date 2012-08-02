_ = require 'underscore'
fs = require 'fs'
plist = require 'plist'

module.exports =
class TextMateGrammar
  @grammarsByExtension: {}

  @loadFromBundles: ->
    for bundlePath in fs.list(require.resolve("bundles"))
      syntaxesPath = fs.join(bundlePath, "Syntaxes")
      continue unless fs.exists(syntaxesPath)
      for path in fs.list(syntaxesPath)
        grammar = @loadGrammarFromPath(path)
        @registerGrammar(grammar)

  @loadGrammarFromPath: (path) ->
    grammar = null
    plist.parseString fs.read(path), (e, data) ->
      throw new Error(e) if e
      grammar = new TextMateGrammar(data[0])
    grammar

  @registerGrammar: (grammar) ->
    for extension in grammar.extensions
      @grammarsByExtension[extension] = grammar

  @grammarForExtension: (extension) ->
    @grammarsByExtension[extension] or @grammarsByExtension["txt"]

  name: null
  repository: null
  initialRule: null

  constructor: ({ @name, fileTypes, scopeName, patterns, repository }) ->
    @extensions = fileTypes
    @initialRule = new Rule(this, {scopeName, patterns})
    @repository = {}
    for name, data of repository
      @repository[name] = new Rule(this, data)

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
      { pattern, match } = pattern.getNextMatch(line, position)
      if match
        if !nextMatch or match.index < nextMatch.index
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

  constructor: (@grammar, { name, @include, match, begin, end, captures, beginCaptures, endCaptures, patterns, @popRule}) ->
    @scopeName = name
    if match
      @regex = new OnigRegExp(match)
      @captures = captures
    else if begin
      @regex = new OnigRegExp(begin)
      @captures = beginCaptures ? captures
      endPattern = new Pattern(@grammar, { match: end, captures: endCaptures ? captures, popRule: true})
      @pushRule = new Rule(@grammar, { @scopeName, patterns, endPattern })

  getNextMatch: (line, position) ->
    if @include
      rule = @grammar.ruleForInclude(@include)
      rule.getNextMatch(line, position)
    else
      { match: @regex.search(line, position), pattern: this }

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
