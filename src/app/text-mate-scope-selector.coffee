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

  constructor: (@selector) ->
    @matcher = TextMateScopeSelector.createParser().parse(@selector)

  matches: (scopes) ->
    @matcher(scopes)
