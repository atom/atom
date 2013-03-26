_ = require 'underscore'
jQuery = require 'jquery'
Specificity = require 'specificity'
{$$} = require 'space-pen'
fs = require 'fs-utils'
EventEmitter = require 'event-emitter'
NullGrammar = require 'null-grammar'
nodePath = require 'path'
pathSplitRegex = new RegExp("[#{nodePath.sep}.]")

module.exports =
class Syntax
  registerDeserializer(this)

  @deserialize: ({grammarOverridesByPath}) ->
    syntax = new Syntax()
    syntax.grammarOverridesByPath = grammarOverridesByPath
    syntax

  constructor: ->
    @grammars = []
    @grammarsByFileType = {}
    @grammarsByScopeName = {}
    @grammarOverridesByPath = {}
    @scopedPropertiesIndex = 0
    @scopedProperties = []
    @nullGrammar = new NullGrammar

  serialize: ->
    { deserializer: @constructor.name, @grammarOverridesByPath }

  addGrammar: (grammar) ->
    @grammars.push(grammar)
    @grammarsByFileType[fileType] = grammar for fileType in grammar.fileTypes
    @grammarsByScopeName[grammar.scopeName] = grammar

  removeGrammar: (grammar) ->
    if _.include(@grammars, grammar)
      _.remove(@grammars, grammar)
      delete @grammarsByFileType[fileType] for fileType in grammar.fileTypes
      delete @grammarsByScopeName[grammar.scopeName]

  setGrammarOverrideForPath: (path, scopeName) ->
    @grammarOverridesByPath[path] = scopeName

  clearGrammarOverrideForPath: (path) ->
    delete @grammarOverridesByPath[path]

  clearGrammarOverrides: ->
    @grammarOverridesByPath = {}

  selectGrammar: (filePath, fileContents) ->

    return @grammarsByFileType["txt"] ? @nullGrammar unless filePath

    @grammarOverrideForPath(filePath) ?
      @grammarByFirstLineRegex(filePath, fileContents) ?
      @grammarByPath(filePath) ?
      @grammarsByFileType["txt"] ?
      @nullGrammar

  grammarOverrideForPath: (path) ->
    @grammarsByScopeName[@grammarOverridesByPath[path]]

  grammarByPath: (path) ->
    pathComponents = path.split(pathSplitRegex)
    for fileType, grammar of @grammarsByFileType
      fileTypeComponents = fileType.split(pathSplitRegex)
      pathSuffix = pathComponents[-fileTypeComponents.length..-1]
      return grammar if _.isEqual(pathSuffix, fileTypeComponents)

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
    name = args.shift() if args.length > 2
    [selector, properties] = args

    @scopedProperties.unshift(
      name: name
      selector: selector,
      properties: properties,
      specificity: Specificity(selector),
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
