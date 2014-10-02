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

  serialize: ->
    {deserializer: @constructor.name, @grammarOverridesByPath}

  createToken: (value, scopes) -> new Token({value, scopes})

  # Deprecated: Used by settings-view to display snippets for packages
  @::accessor 'scopedProperties', ->
    deprecate("Use Syntax::getProperty instead")
    @propertyStore.propertySets

  addProperties: (args...) ->
    atom.config.addScopedDefaults(args...)

  removeProperties: (name) ->
    atom.config.removeScopedSettingsForName(name)

  clearProperties: ->
    atom.config.clearScopedSettings()

  getProperty: (scope, keyPath) ->
    atom.config.getRawScopedValue(scope, keyPath)

  propertiesForScope: (scope, keyPath) ->
    atom.config.settingsForScopeDescriptor(scope, keyPath)
