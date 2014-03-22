_ = require 'underscore-plus'
{specificity} = require 'clear-cut'
{Subscriber} = require 'emissary'
{GrammarRegistry, ScopeSelector} = require 'first-mate'
ScopedPropertyStore = require 'scoped-property-store'

{$, $$} = require './space-pen-extensions'
Token = require './token'

# Public: Syntax class holding the grammars used for tokenizing.
#
# An instance of this class is always available as the `atom.syntax` global.
#
# The Syntax class also contains properties for things such as the
# language-specific comment regexes.
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
    @scopedProperties = new ScopedPropertyStore

  serialize: ->
    {deserializer: @constructor.name, @grammarOverridesByPath}

  createToken: (value, scopes) -> new Token({value, scopes})

  addProperties: (args...) ->
    name = args.shift() if args.length > 2
    [selector, properties] = args
    propertiesBySelector = {}
    propertiesBySelector[selector] = properties
    @scopedProperties.addProperties(name, propertiesBySelector)

  removeProperties: (name) ->
    @scopedProperties.removeProperties(name)

  clearProperties: ->
    @scopedProperties = new ScopedPropertyStore

  # Public: Get a property for the given scope and key path.
  #
  # ## Example
  # ```coffee
  # comment = atom.syntax.getProperty(['.source.ruby'], 'editor.commentStart')
  # console.log(comment) # '# '
  # ```
  #
  # scope - An {Array} of {String} scopes.
  # keyPath - A {String} key path.
  #
  # Returns a {String} property value or undefined.
  getProperty: (scope, keyPath) ->
    scopeChain = scope
      .map (scope) ->
        scope = ".#{scope}" unless scope.indexOf('.') is 0
        scope
      .join(' ')
    @scopedProperties.getPropertyValue(scopeChain, keyPath)

  propertiesForScope: (scope, keyPath) ->
    scopeChain = scope
      .map (scope) ->
        scope = ".#{scope}" unless scope.indexOf('.') is 0
        scope
      .join(' ')

    @scopedProperties.getProperties(scopeChain, keyPath)

  cssSelectorFromScopeSelector: (scopeSelector) ->
    new ScopeSelector(scopeSelector).toCssSelector()
