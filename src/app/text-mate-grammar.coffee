_ = require 'underscore'
fs = require 'fs-utils'
plist = require 'plist'
Token = require 'token'
CSON = require 'cson'
{OnigRegExp, OnigScanner} = require 'oniguruma'

module.exports =
class TextMateGrammar
  @readFromPath: (path) ->
    fs.readPlist(path)

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
    @fileTypes ?= []

    for name, data of repository
      data = {patterns: [data], tempName: name} if data.begin? or data.match?
      @repository[name] = new Rule(this, data)

  tokenizeLine: (line, ruleStack=[@initialRule], firstLine=false) ->
    ruleStack = new Array(ruleStack...) # clone ruleStack
    tokens = []
    position = 0

    loop
      scopes = scopesFromStack(ruleStack)

      if line.length == 0
        tokens = [new Token(value: "", scopes: scopes)]
        return { tokens, ruleStack }

      break if position == line.length + 1 # include trailing newline position

      if match = _.last(ruleStack).getNextTokens(ruleStack, line, position, firstLine)
        { nextTokens, tokensStartPosition, tokensEndPosition } = match
        if position < tokensStartPosition # unmatched text before next tokens
          tokens.push(new Token(
            value: line[position...tokensStartPosition]
            scopes: scopes
          ))

        tokens.push(nextTokens...)
        position = tokensEndPosition
        break if position is line.length and nextTokens.length is 0

      else # push filler token for unmatched text at end of line
        if position < line.length
          tokens.push(new Token(
            value: line[position...line.length]
            scopes: scopes
          ))
        break

    ruleStack.forEach (rule) -> rule.clearAnchorPosition()
    { tokens, ruleStack }

class Rule
  grammar: null
  scopeName: null
  patterns: null
  scannersByBaseGrammarName: null
  createEndPattern: null
  anchorPosition: -1

  constructor: (@grammar, {@scopeName, patterns, @endPattern}) ->
    patterns ?= []
    @patterns = patterns.map (pattern) => new Pattern(grammar, pattern)
    @patterns.unshift(@endPattern) if @endPattern and !@endPattern.hasBackReferences
    @scannersByBaseGrammarName = {}

  getIncludedPatterns: (baseGrammar, included=[]) ->
    return [] if _.include(included, this)

    included = included.concat([this])
    allPatterns = []
    for pattern in @patterns
      allPatterns.push(pattern.getIncludedPatterns(baseGrammar, included)...)
    allPatterns

  clearAnchorPosition: -> @anchorPosition = -1

  getScanner: (baseGrammar, position, firstLine) ->
    return scanner if scanner = @scannersByBaseGrammarName[baseGrammar.name]

    anchored = false
    regexes = []
    patterns = @getIncludedPatterns(baseGrammar)
    patterns.forEach (pattern) =>
      if pattern.anchored
        anchored = true
        regex = pattern.replaceAnchor(firstLine, position, @anchorPosition)
      else
        regex = pattern.regexSource
      regexes.push regex if regex

    regexScanner = new OnigScanner(regexes)
    regexScanner.patterns = patterns
    @scannersByBaseGrammarName[baseGrammar.name] = regexScanner unless anchored
    regexScanner

  getNextTokens: (ruleStack, line, position, firstLine) ->
    baseGrammar = ruleStack[0].grammar
    patterns = @getIncludedPatterns(baseGrammar)

    scanner = @getScanner(baseGrammar, position, firstLine)
    # Add a `\n` to appease patterns that contain '\n' explicitly
    return null unless result = scanner.findNextMatch("#{line}\n", position)
    { index, captureIndices } = result
    # Since the `\n' (added above) is not part of the line, truncate captures to the line's actual length
    lineLength = line.length
    captureIndices = captureIndices.map (value, index) ->
      value = lineLength if index % 3 != 0 and value > lineLength
      value

    [firstCaptureIndex, firstCaptureStart, firstCaptureEnd] = captureIndices
    nextTokens = patterns[index].handleMatch(ruleStack, line, captureIndices)
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
  anchored: false

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
    @anchored = @hasAnchor()

  hasAnchor: ->
    return false unless @regexSource
    escape = false
    for character in @regexSource.split('')
      return true if escape and 'AGz'.indexOf(character) isnt -1
      escape = not escape and character is '\\'
    false

  replaceAnchor: (firstLine, offset, anchor) ->
    escaped = []
    placeholder = '\uFFFF'
    escape = false
    for character in @regexSource.split('')
      if escape
        switch character
          when 'A'
            if firstLine
              escaped.push("\\#{character}")
            else
              escaped.push(placeholder)
          when 'G'
            if offset is anchor
              escaped.push("\\#{character}")
            else
              escaped.push(placeholder)
          when 'z' then escaped.push('$(?!\n)(?<!\n)')
          else escaped.push("\\#{character}")
        escape = false
      else if character is '\\'
        escape = true
      else
        escaped.push(character)

    escaped.join('')

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

  ruleForInclude: (baseGrammar, name) ->
    if name[0] == "#"
      @grammar.repository[name[1..]]
    else if name == "$self"
      @grammar.initialRule
    else if name == "$base"
      baseGrammar.initialRule
    else
      syntax.grammarForScopeName(name)?.initialRule

  getIncludedPatterns: (baseGrammar, included) ->
    if @include
      rule = @ruleForInclude(baseGrammar, @include)
      rule?.getIncludedPatterns(baseGrammar, included) ? []
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
      ruleToPush = @pushRule.getRuleToPush(line, captureIndices)
      ruleToPush.anchorPosition = captureIndices[2]
      stack.push(ruleToPush)
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
