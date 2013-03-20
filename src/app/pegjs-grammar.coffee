PEG = require('pegjs')
fs = require('fs')
_ = require('underscore')

module.exports =
class PEGjsGrammar

  constructor: (@name, @grammarFile, @fileTypes, @scopeName) ->
    @parser = PEG.buildParser fs.read(@grammarFile),
                                cache:    false
                                output:   "parser"
                                optimize: "speed"
                                plugins:  []
    @cache  = {}

  tokenizeLine: (line, ruleStack=undefined, lineNumber) ->
    @cache = {} if lineNumber == 0

    mixedOutput = @parser.parse(line, cache: @cache)
    tokenDAG = @normalizeOutput(mixedOutput)
    flatRules = @flattenToRules(tokenDAG)
    rules = @reduceRules(flatRules)

    {tokens: rules}

  flattenToRules: (token) ->
    childRules = _.flatten(token.tokens.map((child)=>@flattenToRules(child)))

    @resolveRules(token, childRules)

  resolveRules: (token, childRules) ->
    return [@buildRule(token.text, token.type)] if childRules.length == 0

    childText = childRules.map((childRule)->childRule.value).join('')

    return childRules if childText == token.text

    rules = []
    buf = token.text

    for childRule in childRules
      if childRule.value?.length
        [text, buf...] = buf.split(childRule.value)
        buf = buf.join(childRule.value)

        if text?.length
          rules.push(@buildRule(text, token.type))

        rules.push(childRule)

    rules

  buildRule: (text, type) ->
    value: text
    scopes: @buildScopes(type)

  reduceRules: (rules) ->
    return rules if rules.length < 2

    [first, second, remaining...] = rules

    if _.isEqual(first.scopes, second.scopes)
      return @reduceRules([@combineRules(first, second), remaining...])
    else
      [first, @reduceRules([second, remaining...])...]

  combineRules: (a, b) ->
    value: [a.value, b.value].join('')
    scopes: _.uniq(a.scopes, b.scopes)

  buildScopes: (type) ->
    types = _.flatten([type])
    types.unshift(@scopeName)
    _.compact(types)

  normalizeOutput: (output) ->
    if @isToken(output)
      @buildDAG(output)
    else if @isArray(output)
      @buildDAG({tokens: output})
    else if @isLiteral(output)
      @buildDAG({text: output})

  isToken: (output) ->
    (typeof output == "object") && (!@isArray(output))

  isArray: (output) ->
    (output instanceof Array)

  isLiteral: (output) ->
    (typeof output == "string")

  buildDAG: (parent) ->
    if @isArray(parent.tokens)
      outputs = parent.tokens
    else if @isToken(parent.tokens)
      outputs = [parent.tokens]
    else
      outputs = []

    children = outputs.map((output)=>@normalizeOutput(output))

    parent.tokens = children

    if children?.length
      parent.text ?= @textFrom(children)
      parent.offset ?= @offsetFrom(children)
      parent.line ?= @lineFrom(children)
      parent.column ?= @columnFrom(children)

      @determineOffsets(parent, children) if parent.offset?
      @determineLines(parent, children) if parent.line?
      @determineColumns(parent, children) if parent.column?

    parent

  textFrom: (children) -> children.map((child)->child.text).join('')
  offsetFrom: (children) -> children.first?.offset
  lineFrom: (children) -> children.first?.line
  columnFrom: (children) -> children.first?.column

  determineOffsets: (parent, children) ->
  determineLines: (parent, children) ->
  determineColumns: (parent, children) ->
