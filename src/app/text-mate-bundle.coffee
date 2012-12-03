_ = require 'underscore'
fs = require 'fs'
plist = require 'plist'
path = require 'path'

TextMateGrammar = require 'app/text-mate-grammar'

module.exports =
class TextMateBundle
  @grammarsByFileType: {}
  @grammarsByScopeName: {}
  @preferencesByScopeSelector: {}
  @bundles: []
  @grammars: []

  @loadAll: ->
    localBundlePath = path.join(atom.configDirPath, "bundles")
    localBundles = fs.readdirSync(localBundlePath) if fs.existsSync(localBundlePath)

    for bundleName in localBundles ? []
      @registerBundle(new TextMateBundle(path.join(localBundlePath, bundleName)))

  @registerBundle: (bundle) ->
    @bundles.push(bundle)

    for scopeSelector, preferences of bundle.getPreferencesByScopeSelector()
      @preferencesByScopeSelector[scopeSelector] = preferences

    for grammar in bundle.grammars
      @grammars.push(grammar)
      for fileType in grammar.fileTypes
        @grammarsByFileType[fileType] = grammar
        @grammarsByScopeName[grammar.scopeName] = grammar

  @grammarForFilePath: (filePath) ->
    extension = path.extname(filePath)?[1...]
    if filePath and extension.length == 0
      extension = path.basename(filePath)

    @grammarsByFileType[extension] or @grammarByShebang(filePath) or @grammarsByFileType["txt"]

  @grammarByShebang: (filePath) ->
    try
      firstLine = fs.read(filePath).match(/.*/)[0]
    catch e
      null

    _.find @grammars, (grammar) -> grammar.firstLineRegex?.test(firstLine)

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

  constructor: (pathName) ->
    @path = pathName
    @grammars = []

    if fs.existsSync(@getSyntaxesPath())
      for grammarFileName in fs.readdirSync(@getSyntaxesPath())
        grammarPath = path.join(@getSyntaxesPath(), grammarFileName)
        try
          @grammars.push TextMateGrammar.loadFromPath(grammarPath)
        catch e
          console.warn "Failed to load grammar at path '#{grammarPath}'", e.stack

  getPreferencesByScopeSelector: ->
    return {} unless fs.existsSync(@getPreferencesPath())
    preferencesByScopeSelector = {}
    preferencesPath = @getPreferencesPath()
    for preferenceFileName in fs.readdirSync(preferencesPath)
      preferencePath = path.join(preferencesPath, preferenceFileName)
      plist.parseString fs.readFileSync(preferencePath, 'utf8'), (e, data) ->
        if e
          console.warn "Failed to parse preference at path '#{preferencePath}'", e
        else
          { scope, settings } = data[0]
          preferencesByScopeSelector[scope] = _.extend(preferencesByScopeSelector[scope] ? {}, settings)

    preferencesByScopeSelector

  getSyntaxesPath: ->
    path.join(@path, "Syntaxes")

  getPreferencesPath: ->
    path.join(@path, "Preferences")
