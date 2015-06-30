{Emitter} = require 'event-kit'
{includeDeprecatedAPIs, deprecate} = require 'grim'
FirstMate = require 'first-mate'
Token = require './token'

# Extended: Syntax class holding the grammars used for tokenizing.
#
# An instance of this class is always available as the `atom.grammars` global.
#
# The Syntax class also contains properties for things such as the
# language-specific comment regexes. See {::getProperty} for more details.
module.exports =
class GrammarRegistry extends FirstMate.GrammarRegistry
  @deserialize: ({grammarOverridesByPath}) ->
    grammarRegistry = new GrammarRegistry()
    grammarRegistry.grammarOverridesByPath = grammarOverridesByPath
    grammarRegistry

  atom.deserializers.add(this)

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
  selectGrammar: (filePath, fileContents) ->
    bestMatch = null
    highestScore = -Infinity
    for grammar in @grammars
      score = grammar.getScore(filePath, fileContents)
      if score > highestScore or not bestMatch?
        bestMatch = grammar
        highestScore = score
      else if score is highestScore and bestMatch?.bundledPackage
        bestMatch = grammar unless grammar.bundledPackage
    bestMatch

  clearObservers: ->
    @off() if includeDeprecatedAPIs
    @emitter = new Emitter

if includeDeprecatedAPIs
  PropertyAccessors = require 'property-accessors'
  PropertyAccessors.includeInto(GrammarRegistry)

  {Subscriber} = require 'emissary'
  Subscriber.includeInto(GrammarRegistry)

  # Support old serialization
  atom.deserializers.add(name: 'Syntax', deserialize: GrammarRegistry.deserialize)

  # Deprecated: Used by settings-view to display snippets for packages
  GrammarRegistry::accessor 'propertyStore', ->
    deprecate("Do not use this. Use a public method on Config")
    atom.config.scopedSettingsStore

  GrammarRegistry::addProperties = (args...) ->
    args.unshift(null) if args.length is 2
    deprecate 'Consider using atom.config.set() instead. A direct (but private) replacement is available at atom.config.addScopedSettings().'
    atom.config.addScopedSettings(args...)

  GrammarRegistry::removeProperties = (name) ->
    deprecate 'atom.config.addScopedSettings() now returns a disposable you can call .dispose() on'
    atom.config.scopedSettingsStore.removeProperties(name)

  GrammarRegistry::getProperty = (scope, keyPath) ->
    deprecate 'A direct (but private) replacement is available at atom.config.getRawScopedValue().'
    atom.config.getRawScopedValue(scope, keyPath)

  GrammarRegistry::propertiesForScope = (scope, keyPath) ->
    deprecate 'Use atom.config.getAll instead.'
    atom.config.settingsForScopeDescriptor(scope, keyPath)
