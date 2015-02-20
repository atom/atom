_ = require 'underscore-plus'
{deprecate} = require 'grim'
{specificity} = require 'clear-cut'
{Subscriber} = require 'emissary'
FirstMate = require 'first-mate'
{ScopeSelector} = FirstMate
ScopedPropertyStore = require 'scoped-property-store'
PropertyAccessors = require 'property-accessors'

{$, $$} = require './space-pen-extensions'
Token = require './token'

# Extended: Syntax class holding the grammars used for tokenizing.
#
# An instance of this class is always available as the `atom.grammars` global.
#
# The Syntax class also contains properties for things such as the
# language-specific comment regexes. See {::getProperty} for more details.
module.exports =
class GrammarRegistry extends FirstMate.GrammarRegistry
  PropertyAccessors.includeInto(this)
  Subscriber.includeInto(this)

  @deserialize: ({grammarOverridesByPath}) ->
    grammarRegistry = new GrammarRegistry()
    grammarRegistry.grammarOverridesByPath = grammarOverridesByPath
    grammarRegistry

  atom.deserializers.add(this)
  atom.deserializers.add(name: 'Syntax', deserialize: @deserialize) # Support old serialization

  constructor: ->
    super(maxTokensPerLine: 100)

  serialize: ->
    {deserializer: @constructor.name, @grammarOverridesByPath}

  createToken: (value, scopes) -> new Token({value, scopes})

  # Extended: Select a grammar for the given file path and file contents.
  #
  # This picks the best match by checking the file path and contents against
  # each grammar.
  #
  # * `filePath` A {String} file path.
  # * `fileContents` A {String} of text for the file path.
  #
  # Returns a {Grammar}, never null.
  selectGrammar: (filePath, fileContents) -> super

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
    deprecate 'Use atom.config.getAll instead.'
    atom.config.settingsForScopeDescriptor(scope, keyPath)
