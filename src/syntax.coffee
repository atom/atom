_ = require 'underscore-plus'
{specificity} = require 'clear-cut'
{Emitter, Subscriber} = require 'emissary'
FirstMate = require 'first-mate'
TextMateScopeSelector = FirstMate.ScopeSelector
TextMateGrammarRegistry = FirstMate.GrammarRegistry

{$, $$} = require './space-pen-extensions'

### Internal ###
module.exports =
class Syntax
  Emitter.includeInto(this)
  Subscriber.includeInto(this)

  atom.deserializers.add(this)

  @deserialize: ({grammarOverridesByPath}) ->
    syntax = new Syntax()
    syntax.registry.grammarOverridesByPath = grammarOverridesByPath
    syntax

  constructor: ->
    @registry = new TextMateGrammarRegistry()

    #TODO Remove once packages have been updated
    @subscribe @registry, 'grammar-added', (grammar) =>
      @emit 'grammar-added', grammar
    @subscribe @registry, 'grammar-updated', (grammar) =>
      @emit 'grammar-updated', grammar
    @__defineGetter__ 'grammars', -> @registry.grammars
    @nullGrammar = @registry.nullGrammar

    @scopedPropertiesIndex = 0
    @scopedProperties = []

  serialize: ->
    deserializer: @constructor.name
    grammarOverridesByPath: @registry.grammarOverridesByPath

  addGrammar: (grammar) ->
    @registry.addGrammar(grammar)

  removeGrammar: (grammar) ->
    @registry.removeGrammar(grammar)

  setGrammarOverrideForPath: (path, scopeName) ->
    @registry.setGrammarOverrideForPath(path, scopeName)

  clearGrammarOverrideForPath: (path) ->
    @registry.clearGrammarOverrideForPath(path)

  clearGrammarOverrides: ->
    @registry.clearGrammarOverrides()

  selectGrammar: (filePath, fileContents) ->
    @registry.selectGrammar(filePath, fileContents)

  grammarOverrideForPath: (path) ->
    @grammarOverridesByPath[path]

  grammarForScopeName: (scopeName) ->
    @registry.grammarForScopeName(scopeName)

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
    scope = new Array(scope...)
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
    new TextMateScopeSelector(scopeSelector).toCssSelector()
