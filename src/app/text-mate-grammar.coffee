_ = require 'underscore'
fsUtils = require 'fs-utils'
plist = require 'plist'
Token = require 'token'
{OnigRegExp, OnigScanner} = require 'oniguruma'
path = require 'path'
EventEmitter = require 'event-emitter'
TextMateScopeSelector = require 'text-mate-scope-selector'

pathSplitRegex = new RegExp("[#{path.sep}.]")

### Internal ###

module.exports =
class TextMateGrammar
  @load: (grammarPath, done) ->
    fsUtils.readObject grammarPath, (error, object) ->
      if error?
        done(error)
      else
        done(null, new TextMateGrammar(object))

  @loadSync: (grammarPath) ->
    new TextMateGrammar(fsUtils.readObjectSync(grammarPath))

  name: null
  rawPatterns: null
  rawRepository: null
  fileTypes: null
  scopeName: null
  repository: null
  initialRule: null
  firstLineRegex: null
  includedGrammarScopes: null
  maxTokensPerLine: 100

  constructor: ({ @name, @fileTypes, @scopeName, injections, injectionSelector, patterns, repository, @foldingStopMarker, firstLineMatch}) ->
    @rawPatterns = patterns
    @rawRepository = repository
    @injections = new Injections(this, injections)

    if injectionSelector?
      @injectionSelector = new TextMateScopeSelector(injectionSelector)

    @firstLineRegex = new OnigRegExp(firstLineMatch) if firstLineMatch
    @fileTypes ?= []
    @includedGrammarScopes = []

  clearRules: ->
    @initialRule = null
    @repository = null

  getInitialRule: ->
    @initialRule ?= new Rule(this, {@scopeName, patterns: @rawPatterns})

  getRepository: ->
    @repository ?= do =>
      repository = {}
      for name, data of @rawRepository
        data = {patterns: [data], tempName: name} if data.begin? or data.match?
        repository[name] = new Rule(this, data)
      repository

  addIncludedGrammarScope: (scope) ->
    @includedGrammarScopes.push(scope) unless _.include(@includedGrammarScopes, scope)

  grammarUpdated: (scopeName) ->
    return false unless _.include(@includedGrammarScopes, scopeName)
    @clearRules()
    syntax.grammarUpdated(@scopeName)
    @trigger 'grammar-updated'
    true

  getScore: (filePath, contents) ->
    contents = fsUtils.read(filePath) if not contents? and fsUtils.isFileSync(filePath)


    if syntax.grammarOverrideForPath(filePath) is @scopeName
      2 + filePath.length
    else if @matchesContents(contents)
      1 + filePath.length
    else
      @getPathScore(filePath)

  matchesContents: (contents) ->
    return false unless contents? and @firstLineRegex?

    escaped = false
    numberOfNewlinesInRegex = 0
    for character in @firstLineRegex.source
      switch character
        when '\\'
          escaped = !escaped
        when 'n'
          numberOfNewlinesInRegex++ if escaped
          escaped = false
        else
          escaped = false
    lines = contents.split('\n')
    @firstLineRegex.test(lines[0..numberOfNewlinesInRegex].join('\n'))

  getPathScore: (filePath) ->
    return -1 unless filePath?

    pathComponents = filePath.split(pathSplitRegex)
    pathScore = -1
    @fileTypes.forEach (fileType) ->
      fileTypeComponents = fileType.split(pathSplitRegex)
      pathSuffix = pathComponents[-fileTypeComponents.length..-1]
      if _.isEqual(pathSuffix, fileTypeComponents)
        pathScore = Math.max(pathScore, fileType.length)

    pathScore

  tokenizeLine: (line, ruleStack=[@getInitialRule()], firstLine=false) ->
    originalRuleStack = ruleStack
    ruleStack = new Array(ruleStack...) # clone ruleStack
    tokens = []
    position = 0

    loop
      scopes = scopesFromStack(ruleStack)
      previousRuleStackLength = ruleStack.length
      previousPosition = position

      if tokens.length >= (@getMaxTokensPerLine() - 1)
        token = new Token(value: line[position..], scopes: scopes)
        tokens.push token
        ruleStack = originalRuleStack
        break

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

      if position == previousPosition
        if ruleStack.length == previousRuleStackLength
          console.error("Popping rule because it loops at column #{position} of line '#{line}'", _.clone(ruleStack))
          ruleStack.pop()
        else if ruleStack.length > previousRuleStackLength # Stack size increased with zero length match
          [penultimateRule, lastRule] = ruleStack[-2..]
          if lastRule?.scopeName? and penultimateRule.scopeName == lastRule.scopeName
            ruleStack.pop()
            tokens.push(new Token(
              value: line[position...line.length]
              scopes: scopes
            ))
            break

    ruleStack.forEach (rule) -> rule.clearAnchorPosition()
    { tokens, ruleStack }

  tokenizeLines: (text) ->
    lines = text.split('\n')
    ruleStack = null
    for line, i in lines
      { tokens, ruleStack } = @tokenizeLine(line, ruleStack, i is 0)
      tokens

  getMaxTokensPerLine: ->
    @maxTokensPerLine

class Injections
  @injections: null

  constructor: (grammar, injections={}) ->
    @injections = []
    @scanners = {}
    for selector, values of injections
      continue unless values?.patterns?.length > 0
      patterns = []
      anchored = false
      for regex in values.patterns
        pattern = new Pattern(grammar, regex)
        anchored = true if pattern.anchored
        patterns.push(pattern.getIncludedPatterns(grammar, patterns)...)
      @injections.push
        anchored: anchored
        selector: new TextMateScopeSelector(selector)
        patterns: patterns

  getScanner: (injection, firstLine, position, anchorPosition) ->
    return injection.scanner if injection.scanner?

    regexes = _.map injection.patterns, (pattern) ->
      pattern.getRegex(firstLine, position, anchorPosition)
    scanner = new OnigScanner(regexes)
    scanner.patterns = injection.patterns
    scanner.anchored = injection.anchored
    injection.scanner = scanner unless scanner.anchored
    scanner

  getScanners: (ruleStack, firstLine, position, anchorPosition) ->
    scanners = []
    scopes = scopesFromStack(ruleStack)
    for injection in @injections
      if injection.selector.matches(scopes)
        scanner = @getScanner(injection, firstLine, position, anchorPosition)
        scanners.push(scanner)
    scanners

_.extend TextMateGrammar.prototype, EventEmitter

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

  createScanner: (patterns, firstLine, position) ->
    anchored = false
    regexes = _.map patterns, (pattern) =>
      anchored = true if pattern.anchored
      pattern.getRegex(firstLine, position, @anchorPosition)

    scanner = new OnigScanner(regexes)
    scanner.patterns = patterns
    scanner.anchored = anchored
    scanner

  getScanner: (baseGrammar, position, firstLine) ->
    return scanner if scanner = @scannersByBaseGrammarName[baseGrammar.name]

    patterns = @getIncludedPatterns(baseGrammar)
    scanner = @createScanner(patterns, firstLine, position)
    @scannersByBaseGrammarName[baseGrammar.name] = scanner unless scanner.anchored
    scanner

  scanInjections: (ruleStack, line, position, firstLine) ->
    baseGrammar = ruleStack[0].grammar
    if injections = baseGrammar.injections
      scanners = injections.getScanners(ruleStack, position, firstLine, @anchorPosition)
      for scanner in scanners
        result = scanner.findNextMatch(line, position)
        return result if result?

  normalizeCaptureIndices: (line, captureIndices) ->
    lineLength = line.length
    captureIndices.forEach (capture) ->
      capture.end = Math.min(capture.end, lineLength)
      capture.start = Math.min(capture.start, lineLength)

  findNextMatch: (ruleStack, line, position, firstLine) ->
    lineWithNewline = "#{line}\n"
    baseGrammar = ruleStack[0].grammar
    results = []

    scanner = @getScanner(baseGrammar, position, firstLine)
    if result = scanner.findNextMatch(lineWithNewline, position)
      results.push(result)

    if result = @scanInjections(ruleStack, lineWithNewline, position, firstLine)
      results.push(result)

    scopes = scopesFromStack(ruleStack)
    for injectionGrammar in _.without(syntax.injectionGrammars, @grammar, baseGrammar)
      if injectionGrammar.injectionSelector.matches(scopes)
        scanner = injectionGrammar.getInitialRule().getScanner(injectionGrammar, position, firstLine)
        if result = scanner.findNextMatch(lineWithNewline, position)
          results.push(result)

    if results.length > 0
      _.min results, (result) =>
        @normalizeCaptureIndices(line, result.captureIndices)
        result.captureIndices[0].start

  getNextTokens: (ruleStack, line, position, firstLine) ->
    result = @findNextMatch(ruleStack, line, position, firstLine)
    return null unless result?
    { index, captureIndices, scanner } = result
    firstCapture = captureIndices[0]
    nextTokens = scanner.patterns[index].handleMatch(ruleStack, line, captureIndices)
    { nextTokens, tokensStartPosition: firstCapture.start, tokensEndPosition: firstCapture.end }

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

  constructor: (@grammar, { name, contentName, @include, match, begin, end, captures, beginCaptures, endCaptures, patterns, @popRule, @hasBackReferences}) ->
    @scopeName = name ? contentName # TODO: We need special treatment of contentName
    if match
      if (end or @popRule) and @hasBackReferences ?= /\\\d+/.test(match)
        @match = match
      else
        @regexSource = match
      @captures = captures
    else if begin
      @regexSource = begin
      @captures = beginCaptures ? captures
      endPattern = new Pattern(@grammar, { match: end, captures: endCaptures ? captures, popRule: true})
      @pushRule = new Rule(@grammar, { @scopeName, patterns, endPattern })

    if @captures?
      for group, capture of @captures
        if capture.patterns?.length > 0 and not capture.rule
          capture.scopeName = @scopeName
          capture.rule = new Rule(@grammar, capture)

    @anchored = @hasAnchor()

  getRegex: (firstLine, position, anchorPosition) ->
    if @anchored
      @replaceAnchor(firstLine, position, anchorPosition)
    else
      @regexSource

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

    for {start, end} in beginCaptureIndices
      beginCaptures.push line[start...end]

    resolvedMatch = @match.replace /\\\d+/g, (match) ->
      index = parseInt(match[1..])
      _.escapeRegExp(beginCaptures[index] ? "\\#{index}")

    new Pattern(@grammar, { hasBackReferences: false, match: resolvedMatch, @captures, @popRule })

  ruleForInclude: (baseGrammar, name) ->
    if name[0] == "#"
      @grammar.getRepository()[name[1..]]
    else if name == "$self"
      @grammar.getInitialRule()
    else if name == "$base"
      baseGrammar.getInitialRule()
    else
      @grammar.addIncludedGrammarScope(name)
      syntax.grammarForScopeName(name)?.getInitialRule()

  getIncludedPatterns: (baseGrammar, included) ->
    if @include
      rule = @ruleForInclude(baseGrammar, @include)
      rule?.getIncludedPatterns(baseGrammar, included) ? []
    else
      [this]

  resolveScopeName: (line, captureIndices) ->
    resolvedScopeName = @scopeName.replace /\${(\d+):\/(downcase|upcase)}/, (match, index, command) ->
      capture = captureIndices[parseInt(index)]
      if capture?
        replacement = line.substring(capture.start, capture.end)
        switch command
          when 'downcase' then replacement.toLowerCase()
          when 'upcase' then replacement.toUpperCase()
          else replacement
      else
        match

    resolvedScopeName.replace /\$(\d+)/, (match, index) ->
      capture = captureIndices[parseInt(index)]
      if capture?
        line.substring(capture.start, capture.end)
      else
        match

  handleMatch: (stack, line, captureIndices) ->
    scopes = scopesFromStack(stack)
    if @scopeName and not @popRule
      scopes.push(@resolveScopeName(line, captureIndices))

    if @captures
      tokens = @getTokensForCaptureIndices(line, _.clone(captureIndices), scopes, stack)
    else
      {start, end} = captureIndices[0]
      zeroLengthMatch = end == start
      if zeroLengthMatch
        tokens = []
      else
        tokens = [new Token(value: line[start...end], scopes: scopes)]
    if @pushRule
      ruleToPush = @pushRule.getRuleToPush(line, captureIndices)
      ruleToPush.anchorPosition = captureIndices[0].end
      stack.push(ruleToPush)
    else if @popRule
      stack.pop()

    tokens

  getTokensForCaptureRule: (rule, line, captureStart, captureEnd, scopes, stack) ->
    captureText = line.substring(captureStart, captureEnd)
    {tokens} = rule.grammar.tokenizeLine(captureText, [stack..., rule])
    tokens

  getTokensForCaptureIndices: (line, captureIndices, scopes, stack) ->
    parentCapture = captureIndices.shift()

    tokens = []
    if scope = @captures[parentCapture.index]?.name
      scopes = scopes.concat(scope)

    if captureRule = @captures[parentCapture.index]?.rule
      captureTokens = @getTokensForCaptureRule(captureRule, line, parentCapture.start, parentCapture.end, scopes, stack)
      tokens.push(captureTokens...)
      # Consume child captures
      while captureIndices.length and captureIndices[0].start < parentCapture.end
        captureIndices.shift()
    else
      previousChildCaptureEnd = parentCapture.start
      while captureIndices.length and captureIndices[0].start < parentCapture.end
        childCapture = captureIndices[0]

        emptyCapture = childCapture.end - childCapture.start == 0
        captureHasNoScope = not @captures[childCapture.index]
        if emptyCapture or captureHasNoScope
          captureIndices.shift()
          continue

        if childCapture.start > previousChildCaptureEnd
          tokens.push(new Token(
            value: line[previousChildCaptureEnd...childCapture.start]
            scopes: scopes
          ))

        captureTokens = @getTokensForCaptureIndices(line, captureIndices, scopes, stack)
        tokens.push(captureTokens...)
        previousChildCaptureEnd = childCapture.end

      if parentCapture.end > previousChildCaptureEnd
        tokens.push(new Token(
          value: line[previousChildCaptureEnd...parentCapture.end]
          scopes: scopes
        ))

    tokens

### Internal ###

scopesFromStack = (stack) ->
  _.compact(_.pluck(stack, "scopeName"))
