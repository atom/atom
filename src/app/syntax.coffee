_ = require 'underscore'
jQuery = require 'jquery'
Specificity = require 'specificity'
{$$} = require 'space-pen'

module.exports =
class Syntax
  constructor: ->
    @globalProperties = {}
    @propertiesBySelector = {}

  addProperties: (args...) ->
    scopeSelector = args.shift() if args.length > 1
    properties = args.shift()

    if scopeSelector
      @propertiesBySelector[scopeSelector] ?= {}
      _.extend(@propertiesBySelector[scopeSelector], properties)
    else
      _.extend(@globalProperties, properties)

  getProperty: (scope, keyPath) ->
    for object in @propertiesForScope(scope)
      value = _.valueForKeyPath(object, keyPath)
      return value if value?
    undefined

  propertiesForScope: (scope) ->
    matchingSelectors = []
    element = @buildScopeElement(scope)
    while element
      matchingSelectors.push(@matchingSelectorsForElement(element)...)
      element = element.parentNode
    properties = matchingSelectors.map (selector) => @propertiesBySelector[selector]
    properties.concat([@globalProperties])

  matchingSelectorsForElement: (element) ->
    matchingSelectors = []
    for selector of @propertiesBySelector
      matchingSelectors.push(selector) if jQuery.find.matchesSelector(element, selector)
    matchingSelectors.sort (a, b) -> Specificity(b) - Specificity(a)

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
