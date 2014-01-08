_ = require 'underscore-plus'
{specificity} = require 'clear-cut'
{Subscriber} = require 'emissary'
{GrammarRegistry, ScopeSelector} = require 'first-mate'

{$, $$} = require './space-pen-extensions'
Token = require './token'

### Public ###
module.exports =
class Syntax extends GrammarRegistry
  Subscriber.includeInto(this)

  atom.deserializers.add(this)

  @deserialize: ({grammarOverridesByPath}) ->
    syntax = new Syntax()
    syntax.grammarOverridesByPath = grammarOverridesByPath
    syntax

  constructor: ->
    super

    @scopedPropertiesIndex = 0
    @scopedProperties = []

  serialize: ->
    {deserializer: @constructor.name, @grammarOverridesByPath}

  createToken: (value, scopes) -> new Token({value, scopes})

  addProperties: (args...) ->
    name = args.shift() if args.length > 2
    [selector, properties] = args

    @scopedProperties.unshift(
      name: name
      selector: selector,
      properties: properties,
      specificity: specificity(selector),
      index: @scopedPropertiesIndex++
    )

  removeProperties: (name) ->
    for properties in @scopedProperties.filter((properties) -> properties.name is name)
      _.remove(@scopedProperties, properties)

  clearProperties: ->
    @scopedProperties = []
    @scopedPropertiesIndex = 0

  getProperty: (scope, keyPath) ->
    for object in @propertiesForScope(scope, keyPath)
      value = _.valueForKeyPath(object, keyPath)
      return value if value?
    undefined

  propertiesForScope: (scope, keyPath) ->
    matchingProperties = []
    candidates = @scopedProperties.filter ({properties}) -> _.valueForKeyPath(properties, keyPath)?
    if candidates.length
      element = @buildScopeElement(scope)
      while element
        matchingProperties.push(@matchingPropertiesForElement(element, candidates)...)
        element = element.parentNode
    matchingProperties

  matchingPropertiesForElement: (element, candidates) ->
    matchingScopedProperties = candidates.filter ({selector}) ->
      $.find.matchesSelector(element, selector)
    matchingScopedProperties.sort (a, b) ->
      if a.specificity == b.specificity
        b.index - a.index
      else
        b.specificity - a.specificity
    _.pluck matchingScopedProperties, 'properties'

  buildScopeElement: (scope) ->
    scope = scope.slice()
    element = $$ ->
      elementsForRemainingScopes = =>
        classString = scope.shift()
        classes = classString.replace(/^\./, '').replace(/\./g, ' ')
        if scope.length
          @div class: classes, elementsForRemainingScopes
        else
          @div class: classes
      elementsForRemainingScopes()

    deepestChild = element.find(":not(:has(*))")
    if deepestChild.length
      deepestChild[0]
    else
      element[0]

  cssSelectorFromScopeSelector: (scopeSelector) ->
    new ScopeSelector(scopeSelector).toCssSelector()
