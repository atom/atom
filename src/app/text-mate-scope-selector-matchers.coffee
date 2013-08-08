_ = require 'underscore'

### Internal ###

class SegmentMatcher
  constructor: (segment) ->
    @segment = _.flatten(segment).join('')

  matches: (scope) -> scope is @segment

  toCssSelector: ->
    @segment.split('.').map((dotFragment) ->
      '.' + dotFragment.replace(/\+/g, '\\+')
    ).join('')

class TrueMatcher
  constructor: ->

  matches: -> true

  toCssSelector: -> '*'

class ScopeMatcher
  constructor: (first, others) ->
    @segments = [first]
    @segments.push(segment[1]) for segment in others

  matches: (scope) ->
    scopeSegments = scope.split('.')
    return false if scopeSegments.length < @segments.length

    for segment, index in @segments
      return false unless segment.matches(scopeSegments[index])

    true

  toCssSelector: ->
    @segments.map((matcher) -> matcher.toCssSelector()).join('')

class PathMatcher
  constructor: (first, others) ->
    @matchers = [first]
    @matchers.push(matcher[1]) for matcher in others

  matches: (scopes) ->
    index = 0
    matcher = @matchers[index]
    for scope in scopes
      matcher = @matchers[++index] if matcher.matches(scope)
      return true unless matcher?
    false

  toCssSelector: ->
    @matchers.map((matcher) -> matcher.toCssSelector()).join(' ')

class OrMatcher
  constructor: (@left, @right) ->

  matches: (scopes) -> @left.matches(scopes) or @right.matches(scopes)

  toCssSelector: -> "#{@left.toCssSelector()}, #{@right.toCssSelector()}"

class AndMatcher
  constructor: (@left, @right) ->

  matches: (scopes) -> @left.matches(scopes) and @right.matches(scopes)

  toCssSelector: ->
    if @right instanceof NegateMatcher
      "#{@left.toCssSelector()}#{@right.toCssSelector()}"
    else
      "#{@left.toCssSelector()} #{@right.toCssSelector()}"

class NegateMatcher
  constructor: (@matcher) ->

  matches: (scopes) -> not @matcher.matches(scopes)

  toCssSelector: -> ":not(#{@matcher.toCssSelector()})"

class CompositeMatcher
  constructor: (left, operator, right) ->
    switch operator
      when '|' then @matcher = new OrMatcher(left, right)
      when '&' then @matcher = new AndMatcher(left, right)
      when '-' then @matcher = new AndMatcher(left, new NegateMatcher(right))

  matches: (scopes) -> @matcher.matches(scopes)

  toCssSelector: -> @matcher.toCssSelector()

module.exports = {
  AndMatcher
  CompositeMatcher
  NegateMatcher
  OrMatcher
  PathMatcher
  ScopeMatcher
  SegmentMatcher
  TrueMatcher
}
