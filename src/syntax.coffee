_ = require 'underscore-plus'
{deprecate} = require 'grim'
{specificity} = require 'clear-cut'
{Subscriber} = require 'emissary'
{GrammarRegistry, ScopeSelector} = require 'first-mate'
ScopedPropertyStore = require 'scoped-property-store'
PropertyAccessors = require 'property-accessors'

{$, $$} = require './space-pen-extensions'
Token = require './token'

# Extended: Syntax class holding the grammars used for tokenizing.
#
# An instance of this class is always available as the `atom.syntax` global.
#
# The Syntax class also contains properties for things such as the
# language-specific comment regexes. See {::getProperty} for more details.
module.exports =
class Syntax extends GrammarRegistry
  PropertyAccessors.includeInto(this)
  Subscriber.includeInto(this)
  atom.deserializers.add(this)

  @deserialize: ({grammarOverridesByPath}) ->
    syntax = new Syntax()
    syntax.grammarOverridesByPath = grammarOverridesByPath
    syntax

  constructor: ->
    super(maxTokensPerLine: 100)
    @propertyStore = new ScopedPropertyStore

  serialize: ->
    {deserializer: @constructor.name, @grammarOverridesByPath}

  createToken: (value, scopes) -> new Token({value, scopes})

  # Deprecated: Used by settings-view to display snippets for packages
  @::accessor 'scopedProperties', ->
    deprecate("Use Syntax::getProperty instead")
    @propertyStore.propertySets

  addProperties: (args...) ->
    name = args.shift() if args.length > 2
    [selector, properties] = args
    propertiesBySelector = {}
    propertiesBySelector[selector] = properties
    @propertyStore.addProperties(name, propertiesBySelector)

  removeProperties: (name) ->
    @propertyStore.removeProperties(name)

  clearProperties: ->
    @propertyStore = new ScopedPropertyStore

  # Public: Get a property for the given scope and key path.
  #
  # ## Examples
  #
  # ```coffee
  # comment = atom.syntax.getProperty(['.source.ruby'], 'editor.commentStart')
  # console.log(comment) # '# '
  # ```
  #
  # * `scope` An {Array} of {String} scopes.
  # * `keyPath` A {String} key path.
  #
  # Returns a {String} property value or undefined.
  getProperty: (scope, keyPath) ->
    scopeChain = scope
      .map (scope) ->
        scope = ".#{scope}" unless scope[0] is '.'
        scope
      .join(' ')
    @propertyStore.getPropertyValue(scopeChain, keyPath)

  propertiesForScope: (scope, keyPath) ->
    scopeChain = scope
      .map (scope) ->
        scope = ".#{scope}" unless scope[0] is '.'
        scope
      .join(' ')

    @propertyStore.getProperties(scopeChain, keyPath)

  cssSelectorFromScopeSelector: (scopeSelector) ->
    new ScopeSelector(scopeSelector).toCssSelector()
