_ = require 'underscore-plus'

StartDotRegex = /^\.?/
WhitespaceRegex = /\S/

# Represents a single unit of text as selected by a grammar.
module.exports =
class Token
  value: null
  hasPairedCharacter: false
  scopes: null
  isAtomic: null
  isHardTab: null
  firstNonWhitespaceIndex: null
  firstTrailingWhitespaceIndex: null
  hasInvisibleCharacters: false

  constructor: (properties) ->
    {@value, @scopes, @isAtomic, @isHardTab, @bufferDelta} = properties
    {@hasInvisibleCharacters, @hasPairedCharacter, @isSoftWrapIndentation} = properties
    @firstNonWhitespaceIndex = properties.firstNonWhitespaceIndex ? null
    @firstTrailingWhitespaceIndex = properties.firstTrailingWhitespaceIndex ? null

    @screenDelta = @value.length
    @bufferDelta ?= @screenDelta

  isEqual: (other) ->
    # TODO: scopes is deprecated. This is here for the sake of lang package tests
    @value is other.value and _.isEqual(@scopes, other.scopes) and !!@isAtomic is !!other.isAtomic

  isBracket: ->
    /^meta\.brace\b/.test(_.last(@scopes))

  isOnlyWhitespace: ->
    not WhitespaceRegex.test(@value)

  matchesScopeSelector: (selector) ->
    targetClasses = selector.replace(StartDotRegex, '').split('.')
    _.any @scopes, (scope) ->
      scopeClasses = scope.split('.')
      _.isSubset(targetClasses, scopeClasses)

  hasLeadingWhitespace: ->
    @firstNonWhitespaceIndex? and @firstNonWhitespaceIndex > 0

  hasTrailingWhitespace: ->
    @firstTrailingWhitespaceIndex? and @firstTrailingWhitespaceIndex < @value.length
