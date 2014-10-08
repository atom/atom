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
  @::accessor 'propertyStore', ->
    deprecate("Do not use this. Use a public method on Config")
    atom.config.scopedSettingsStore

  addProperties: (args...) ->
    args.unshift(null) if args.length == 2
    deprecate 'Consider using atom.config.set() instead. A direct (but private) replacement is available at atom.config.addScopedSettings().'
    atom.config.addScopedSettings(args...)

  removeProperties: (name) ->
    deprecate 'atom.config.addScopedSettings() now returns a disposable you can call .dispose() on'
    atom.config.scopedSettingsStore.removeProperties(name)

  getProperty: (scope, keyPath) ->
    deprecate 'A direct (but private) replacement is available at atom.config.getRawScopedValue().'
    atom.config.getRawScopedValue(scope, keyPath)

  propertiesForScope: (scope, keyPath) ->
    deprecate 'A direct (but private) replacement is available at atom.config.scopedSettingsForScopeDescriptor().'
    atom.config.settingsForScopeDescriptor(scope, keyPath)
