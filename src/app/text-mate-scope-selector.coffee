PEG = require 'pegjs'
fsUtils = require 'fs-utils'

module.exports =
class TextMateScopeSelector
  @parser: null

  @createParser: ->
    unless TextMateScopeSelector.parser?
      patternPath = require.resolve('text-mate-scope-selector-pattern.pegjs')
      TextMateScopeSelector.parser = PEG.buildParser(fsUtils.read(patternPath))
    TextMateScopeSelector.parser

  source: null
  matcher: null

  constructor: (@source) ->
    @matcher = TextMateScopeSelector.createParser().parse(@source)

  matches: (scopes) ->
    @matcher.matches(scopes)
