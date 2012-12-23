_ = require 'underscore'
jQuery = require 'jquery'
Specificity = require 'specificity'
{$$} = require 'space-pen'

module.exports =
class Syntax
  constructor: ->
    @globalProperties = {}
    @scopedPropertiesIndex = 0
    @scopedProperties = []
    @propertiesBySelector = {}

  addProperties: (args...) ->
    selector = args.shift() if args.length > 1
    properties = args.shift()

    if selector
      @scopedProperties.unshift(
        selector: selector,
        properties: properties,
        specificity: Specificity(selector),
        index: @scopedPropertiesIndex++
      )
    else
      _.extend(@globalProperties, properties)

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
    matchingProperties.concat([@globalProperties])

  matchingPropertiesForElement: (element, candidates) ->
    matchingScopedProperties = candidates.filter ({selector}) -> jQuery.find.matchesSelector(element, selector)
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
