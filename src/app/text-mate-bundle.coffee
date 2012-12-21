_ = require 'underscore'
fs = require 'fs'
plist = require 'plist'
$ = require 'jquery'

TextMateGrammar = require 'text-mate-grammar'

module.exports =
class TextMateBundle
  @grammarsByFileType: {}
  @grammarsByScopeName: {}
  @preferencesByScopeSelector: {}
  @grammars: []

  @load: (name)->
    bundle = new TextMateBundle(require.resolve(name))

    for scopeSelector, preferences of bundle.getPreferencesByScopeSelector()
      if @preferencesByScopeSelector[scopeSelector]?
        _.extend(@preferencesByScopeSelector[scopeSelector], preferences)
      else
        @preferencesByScopeSelector[scopeSelector] = preferences

    for grammar in bundle.grammars
      @grammars.push(grammar)
      for fileType in grammar.fileTypes
        @grammarsByFileType[fileType] = grammar
        @grammarsByScopeName[grammar.scopeName] = grammar

  @grammarForFilePath: (filePath) ->
    return @grammarsByFileType["txt"] unless filePath

    extension = fs.extension(filePath)?[1...]
    if filePath and extension.length == 0
      extension = fs.base(filePath)

    @grammarsByFileType[extension] or @grammarByShebang(filePath) or @grammarByFileTypeSuffix(filePath) or @grammarsByFileType["txt"]

  @grammarByFileTypeSuffix: (filePath) ->
    for fileType, grammar of @grammarsByFileType
      return grammar if _.endsWith(filePath, fileType)

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

  @getPreferenceValueInScope: (scope, preferenceName, valueName) ->
    values = @getPreferenceInScope(scope, preferenceName)
    (_.find values, ({name}) -> name is valueName)?['value']

  @lineCommentStartStringForScope: (scope) ->
    @getPreferenceValueInScope(scope, 'shellVariables', 'TM_COMMENT_START')

  @lineCommentEndStringForScope: (scope) ->
    @getPreferenceValueInScope(scope, 'shellVariables', 'TM_COMMENT_END')

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
          return unless scope
          for scope in scope.split(',')
            scope = $.trim(scope)
            continue unless scope
            preferencesByScopeSelector[scope] = _.extend(preferencesByScopeSelector[scope] ? {}, settings)

    preferencesByScopeSelector

  getSyntaxesPath: ->
    fs.join(@path, "Syntaxes")

  getPreferencesPath: ->
    fs.join(@path, "Preferences")
