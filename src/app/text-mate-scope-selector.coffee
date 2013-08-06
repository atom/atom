PEG = require 'pegjs'
fsUtils = require 'fs-utils'

# Internal: Test a stack of scopes to see if they match a scope selector.
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

  # Create a new scope selector.
  #
  # source - A {String} to parse as a scope selector.
  constructor: (@source) ->
    @matcher = TextMateScopeSelector.createParser().parse(@source)

  # Check if this scope selector matches the scopes.
  #
  # scopes - An {Array} of {String}s.
  #
  # Return a {Boolean}.
  matches: (scopes) ->
    @matcher.matches(scopes)

  toCssSelector: -> @matcher.toCssSelector()
