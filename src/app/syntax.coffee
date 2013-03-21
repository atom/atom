_ = require 'underscore'
jQuery = require 'jquery'
Specificity = require 'specificity'
{$$} = require 'space-pen'
fs = require 'fs-utils'
EventEmitter = require 'event-emitter'

module.exports =
class Syntax
  constructor: ->
    @grammars = []
    @grammarsByFileType = {}
    @grammarsByScopeName = {}
    @globalProperties = {}
    @scopedPropertiesIndex = 0
    @scopedProperties = []

  addGrammar: (grammar) ->
    @grammars.push(grammar)
    for fileType in grammar.fileTypes
      @grammarsByFileType[fileType] = grammar
      @grammarsByScopeName[grammar.scopeName] = grammar

  selectGrammar: (filePath, fileContents) ->
    return @grammarsByFileType["txt"] unless filePath

    extension = fs.extension(filePath)?[1..]
    if filePath and extension.length == 0
      extension = fs.base(filePath)

    @grammarByFirstLineRegex(filePath, fileContents) or
      @grammarsByFileType[extension] or
      @grammarByFileTypeSuffix(filePath) or
      @grammarsByFileType["txt"]

  grammarByFileTypeSuffix: (filePath) ->
    for fileType, grammar of @grammarsByFileType
      return grammar if _.endsWith(filePath, fileType)

  grammarByFirstLineRegex: (filePath, fileContents) ->
    try
      fileContents ?= fs.read(filePath)
    catch e
      return

    return unless fileContents

    lines = fileContents.split('\n')
    _.find @grammars, (grammar) ->
      regex = grammar.firstLineRegex
      return unless regex?

      escaped = false
      numberOfNewlinesInRegex = 0
      for character in regex.source
        switch character
          when '\\'
            escaped = !escaped
          when 'n'
            numberOfNewlinesInRegex++ if escaped
            escaped = false
          else
            escaped = false

      regex.test(lines[0..numberOfNewlinesInRegex].join('\n'))

  grammarForScopeName: (scopeName) ->
    @grammarsByScopeName[scopeName]

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
    matchingScopedProperties = candidates.filter ({selector}) ->
      jQuery.find.matchesSelector(element, selector)
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
    scopeSelector.split(', ').map((commaFragment) ->
      commaFragment.split(' ').map((spaceFragment) ->
        spaceFragment.split('.').map((dotFragment) ->
          '.' + dotFragment.replace(/\+/g, '\\+')
        ).join('')
      ).join(' ')
    ).join(', ')

_.extend(Syntax.prototype, EventEmitter)
