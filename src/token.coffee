_ = require 'underscore-plus'

StartDotRegex = /^\.?/

# Represents a single unit of text as selected by a grammar.
module.exports =
class Token
  value: null
  scopes: null

  constructor: (properties) ->
    {@value, @scopes} = properties

  isEqual: (other) ->
    # TODO: scopes is deprecated. This is here for the sake of lang package tests
    @value is other.value and _.isEqual(@scopes, other.scopes)

  isBracket: ->
    /^meta\.brace\b/.test(_.last(@scopes))

  matchesScopeSelector: (selector) ->
    targetClasses = selector.replace(StartDotRegex, '').split('.')
    _.any @scopes, (scope) ->
      scopeClasses = scope.split('.')
      _.isSubset(targetClasses, scopeClasses)
