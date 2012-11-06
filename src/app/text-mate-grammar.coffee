_ = require 'underscore'
fs = require 'fs'
plist = require 'plist'
Token = require 'token'

module.exports =
class TextMateGrammar
  @loadFromPath: (path) ->
    grammar = null
    plist.parseString fs.read(path), (e, data) ->
      throw new Error(e) if e
      grammar = new TextMateGrammar(data[0])
    throw new Error("Failed to load grammar at path `#{path}`") unless grammar
    grammar

  name: null
  fileTypes: null
  scopeName: null
  repository: null
  initialRule: null
  firstLineRegex: null

  constructor: ({ @name, @fileTypes, @scopeName, patterns, repository, @foldingStopMarker, firstLineMatch}) ->
    @initialRule = new Rule(this, {@scopeName, patterns})
    @repository = {}
    @firstLineRegex = new OnigRegExp(firstLineMatch) if firstLineMatch

    for name, data of repository
      @repository[name] = new Rule(this, data)

  tokenizeLine: (line, {ruleStack, tabLength}={}) ->
    ruleStack ?= [@initialRule]
    ruleStack = new Array(ruleStack...) # clone ruleStack
    tokens = []
    position = 0

    loop
      scopes = scopesFromStack(ruleStack)

      if line.length == 0
        tokens = [new Token(value: "", scopes: scopes)]
        return { tokens, ruleStack }

      break if position == line.length

      if match = _.last(ruleStack).getNextTokens(ruleStack, line, position)
        { nextTokens, tokensStartPosition, tokensEndPosition } = match
        if position < tokensStartPosition # unmatched text before next tokens
          tokens.push(new Token(
            value: line[position...tokensStartPosition]
            scopes: scopes
          ))

        tokens.push(nextTokens...)
        position = tokensEndPosition

      else # push filler token for unmatched text at end of line
        tokens.push(new Token(
          value: line[position...line.length]
          scopes: scopes
        ))
        break

    { tokens: @breakOutAtomicTokens(tokens, tabLength), ruleStack }

  breakOutAtomicTokens: (inputTokens, tabLength) ->
    outputTokens = []
    breakOutLeadingWhitespace = true
    for token in inputTokens
      outputTokens.push(token.breakOutAtomicTokens(tabLength, breakOutLeadingWhitespace)...)
      breakOutLeadingWhitespace = token.isOnlyWhitespace() if breakOutLeadingWhitespace
    outputTokens

  ruleForInclude: (name) ->
    if name[0] == "#"
      @repository[name[1..]]
    else if name == "$self"
      @initialRule
    else
      TextMateBundle = require 'text-mate-bundle'
      TextMateBundle.grammarForScopeName(name)?.initialRule

class Rule
  grammar: null
  scopeName: null
  patterns: null
  allPatterns: null
  createEndPattern: null

  constructor: (@grammar, {@scopeName, patterns, @endPattern}) ->
    patterns ?= []
    @patterns = patterns.map (pattern) => new Pattern(grammar, pattern)
    @patterns.unshift(@endPattern) if @endPattern and !@endPattern.hasBackReferences

  getIncludedPatterns: (included=[]) ->
    return @allPatterns if @allPatterns
    return [] if _.include(included, this)

    included = included.concat([this])
    @allPatterns = []
    for pattern in @patterns
      @allPatterns.push(pattern.getIncludedPatterns(included)...)
    @allPatterns

  getScanner: ->
    @scanner ?= new OnigScanner(_.pluck(@getIncludedPatterns(), 'regexSource'))

  getNextTokens: (stack, line, position) ->
    patterns = @getIncludedPatterns()

    # Add a `\n` to appease patterns that contain '\n' explicitly
    return null unless result = @getScanner().findNextMatch(line + "\n", position)
    { index, captureIndices } = result

    # Since the `\n' (added above) is not part of the line, truncate captures to the line's actual length
    lineLength = line.length
    captureIndices = captureIndices.map (value, index) ->
      value = lineLength if index % 3 != 0 and value > lineLength
      value

    [firstCaptureIndex, firstCaptureStart, firstCaptureEnd] = captureIndices
    nextTokens = patterns[index].handleMatch(stack, line, captureIndices)
    { nextTokens, tokensStartPosition: firstCaptureStart, tokensEndPosition: firstCaptureEnd }

  getRuleToPush: (line, beginPatternCaptureIndices) ->
    if @endPattern.hasBackReferences
      rule = new Rule(@grammar, {@scopeName})
      rule.endPattern = @endPattern.resolveBackReferences(line, beginPatternCaptureIndices)
      rule.patterns = [rule.endPattern, @patterns...]
      rule
    else
      this

class Pattern
  grammar: null
  pushRule: null
  popRule: false
  scopeName: null
  captures: null
  backReferences: null

  constructor: (@grammar, { name, contentName, @include, match, begin, end, captures, beginCaptures, endCaptures, patterns, @popRule, hasBackReferences}) ->
    @scopeName = name ? contentName # TODO: We need special treatment of contentName
    if match
      if @hasBackReferences = hasBackReferences ? /\\\d+/.test(match)
        @match = match
      else
        @regexSource = match
      @captures = captures
    else if begin
      @regexSource = begin
      @captures = beginCaptures ? captures
      endPattern = new Pattern(@grammar, { match: end, captures: endCaptures ? captures, popRule: true})
      @pushRule = new Rule(@grammar, { @scopeName, patterns, endPattern })

  resolveBackReferences: (line, beginCaptureIndices) ->
    beginCaptures = []

    for i in [0...beginCaptureIndices.length] by 3
      start = beginCaptureIndices[i + 1]
      end = beginCaptureIndices[i + 2]
      beginCaptures.push line[start...end]

    resolvedMatch = @match.replace /\\\d+/g, (match) ->
      index = parseInt(match[1..])
      _.escapeRegExp(beginCaptures[index] ? "\\#{index}")

    new Pattern(@grammar, { hasBackReferences: false, match: resolvedMatch, @captures, @popRule })

  getIncludedPatterns: (included) ->
    if @include
      rule = @grammar.ruleForInclude(@include)
      rule?.getIncludedPatterns(included) ? []
    else
      [this]

  handleMatch: (stack, line, captureIndices) ->
    scopes = scopesFromStack(stack)
    scopes.push(@scopeName) if @scopeName and not @popRule

    if @captures
      tokens = @getTokensForCaptureIndices(line, _.clone(captureIndices), scopes)
    else
      [start, end] = captureIndices[1..2]
      zeroLengthMatch = end == start
      if zeroLengthMatch
        tokens = []
      else
        tokens = [new Token(value: line[start...end], scopes: scopes)]
    if @pushRule
      stack.push(@pushRule.getRuleToPush(line, captureIndices))
    else if @popRule
      stack.pop()

    tokens

  getTokensForCaptureIndices: (line, captureIndices, scopes) ->
    [parentCaptureIndex, parentCaptureStart, parentCaptureEnd] = shiftCapture(captureIndices)

    tokens = []
    if scope = @captures[parentCaptureIndex]?.name
      scopes = scopes.concat(scope)

    previousChildCaptureEnd = parentCaptureStart
    while captureIndices.length and captureIndices[1] < parentCaptureEnd
      [childCaptureIndex, childCaptureStart, childCaptureEnd] = captureIndices

      emptyCapture = childCaptureEnd - childCaptureStart == 0
      captureHasNoScope = not @captures[childCaptureIndex]
      if emptyCapture or captureHasNoScope
        shiftCapture(captureIndices)
        continue

      if childCaptureStart > previousChildCaptureEnd
        tokens.push(new Token(
          value: line[previousChildCaptureEnd...childCaptureStart]
          scopes: scopes
        ))

      captureTokens = @getTokensForCaptureIndices(line, captureIndices, scopes)
      tokens.push(captureTokens...)
      previousChildCaptureEnd = childCaptureEnd

    if parentCaptureEnd > previousChildCaptureEnd
      tokens.push(new Token(
        value: line[previousChildCaptureEnd...parentCaptureEnd]
        scopes: scopes
      ))

    tokens

shiftCapture = (captureIndices) ->
  [captureIndices.shift(), captureIndices.shift(), captureIndices.shift()]

scopesFromStack = (stack) ->
  _.compact(_.pluck(stack, "scopeName"))

