_ = require 'underscore'
fs = require 'fs'
plist = require 'plist'

TextMateGrammar = require 'text-mate-grammar'

module.exports =
class TextMateBundle
  @grammarsByFileType: {}
  @grammarsByScopeName: {}
  @preferencesByScopeSelector: {}
  @bundles: []

  @loadAll: ->
    globalBundles = fs.list(require.resolve("bundles"))

    localBundlePath = fs.join(atom.configDirPath, "bundles")
    localBundles = fs.list(localBundlePath) if fs.exists(localBundlePath)

    for bundlePath in globalBundles.concat(localBundles ? [])
      @registerBundle(new TextMateBundle(bundlePath))

  @registerBundle: (bundle)->
    @bundles.push(bundle)

    for scopeSelector, preferences of bundle.getPreferencesByScopeSelector()
      @preferencesByScopeSelector[scopeSelector] = preferences

    for grammar in bundle.grammars
      for fileType in grammar.fileTypes
        @grammarsByFileType[fileType] = grammar
        @grammarsByScopeName[grammar.scopeName] = grammar

  @grammarForFileName: (fileName) ->
    extension = fs.extension(fileName)?[1...]
    if fileName and extension.length == 0
      extension = fileName

    @grammarsByFileType[extension] or @grammarsByFileType["txt"]

  @grammarForScopeName: (scopeName) ->
    @grammarsByScopeName[scopeName]

  @getPreferenceInScope: (scopeSelector, preferenceName) ->
    @preferencesByScopeSelector[scopeSelector]?[preferenceName]

  @lineCommentStringForScope: (scope) ->
    shellVariables = @getPreferenceInScope(scope, 'shellVariables')
    (_.find shellVariables, ({name}) -> name == "TM_COMMENT_START")?['value']

  @indentRegexForScope: (scope) ->
    if source = @getPreferenceInScope(scope, 'increaseIndentPattern')
      new OnigRegExp(source)

  @outdentRegexForScope: (scope) ->
    if source = @getPreferenceInScope(scope, 'decreaseIndentPattern')
      new OnigRegExp(source)

  @foldEndRegexForScope: (grammar, scope) ->
    marker =  @getPreferenceInScope(scope, 'foldingStopMarker')
    if marker
      new OnigRegExp(marker)
    else
      new OnigRegExp(grammar.foldingStopMarker)

  grammars: null

  constructor: (@path) ->
    @grammars = []
    if fs.exists(@getSyntaxesPath())
      for syntaxPath in fs.list(@getSyntaxesPath())
        try
          @grammars.push TextMateGrammar.loadFromPath(syntaxPath)
        catch e
          console.warn "Failed to load grammar at path '#{syntaxPath}'", e

  getPreferencesByScopeSelector: ->
    return {} unless fs.exists(@getPreferencesPath())
    preferencesByScopeSelector = {}
    for preferencePath in fs.list(@getPreferencesPath())
      plist.parseString fs.read(preferencePath), (e, data) ->
        if e
          console.warn "Failed to parse preference at path '#{preferencePath}'", e
        else
          { scope, settings } = data[0]
          preferencesByScopeSelector[scope] = _.extend(preferencesByScopeSelector[scope] ? {}, settings)

    preferencesByScopeSelector

  getSyntaxesPath: ->
    fs.join(@path, "Syntaxes")

  getPreferencesPath: ->
    fs.join(@path, "Preferences")

