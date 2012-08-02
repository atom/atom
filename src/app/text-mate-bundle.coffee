_ = require 'underscore'
fs = require 'fs'
plist = require 'plist'

TextMateGrammar = require 'text-mate-grammar'


module.exports =
class TextMateBundle
  @grammarsByFileType: {}
  @preferencesByScopeSelector: {}
  @bundles: []

  @loadAll: ->
    for bundlePath in fs.list(require.resolve("bundles"))
      @registerBundle(new TextMateBundle(bundlePath))

  @registerBundle: (bundle)->
    @bundles.push(bundle)

    for scopeSelector, preferences of bundle.getPreferencesByScopeSelector()
      @preferencesByScopeSelector[scopeSelector] = preferences

    for grammar in bundle.grammars
      for fileType in grammar.fileTypes
        @grammarsByFileType[fileType] = grammar

  @grammarForFileName: (fileName) ->
    extension = fs.extension(fileName)[1...]
    @grammarsByFileType[extension] or @grammarsByFileType["txt"]

  @getPreferenceForScopeSelector: (name, scopeSelector) ->
    @preferencesByScopeSelector[scopeSelector][name]

  grammars: null

  constructor: (@path) ->
    @grammars = []
    if fs.exists(@getSyntaxesPath())
      for syntaxPath in fs.list(@getSyntaxesPath())
        @grammars.push TextMateGrammar.loadFromPath(syntaxPath)

  getPreferencesByScopeSelector: ->
    return {} unless fs.exists(@getPreferencesPath())
    preferencesByScopeSelector = {}
    for preferencePath in fs.list(@getPreferencesPath())
      plist.parseString fs.read(preferencePath), (e, data) ->
        throw new Error(e) if e
        { scope, settings } = data[0]

        preferencesByScopeSelector[scope] = _.extend(preferencesByScopeSelector[scope] ? {}, settings)
        console.log preferencesByScopeSelector

    preferencesByScopeSelector

  getSyntaxesPath: ->
    fs.join(@path, "Syntaxes")

  getPreferencesPath: ->
    fs.join(@path, "Preferences")

