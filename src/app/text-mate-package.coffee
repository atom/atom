Package = require 'package'
fsUtils = require 'fs-utils'
plist = require 'plist'
_ = require 'underscore'
TextMateGrammar = require 'text-mate-grammar'
async = require 'async'

module.exports =
class TextMatePackage extends Package
  @testName: (packageName) ->
    /(\.|_|-)tmbundle$/.test(packageName)

  @getLoadQueue: ->
    return @loadQueue if @loadQueue
    @loadQueue = async.queue (pack, done) -> pack.loadGrammars(done)
    @loadQueue

  constructor: ->
    super
    @preferencesPath = fsUtils.join(@path, "Preferences")
    @syntaxesPath = fsUtils.join(@path, "Syntaxes")
    @grammars = []

  load: ({sync}={}) ->
    if sync
      @loadGrammarsSync()
    else
      TextMatePackage.getLoadQueue().push(this)
    @loadScopedProperties()

  activate: ->
    syntax.addGrammar(grammar) for grammar in @grammars
    for { selector, properties } in @scopedProperties
      syntax.addProperties(@path, selector, properties)

  deactivate: ->
    syntax.removeGrammar(grammar) for grammar in @grammars
    syntax.removeProperties(@path)

  legalGrammarExtensions: ['plist', 'tmLanguage', 'tmlanguage']

  loadGrammars: (done) ->
    fsUtils.isDirectoryAsync @syntaxesPath, (isDirectory) =>
      if isDirectory
        fsUtils.listAsync @syntaxesPath, @legalGrammarExtensions, (err, paths) =>
          return console.log("Error loading grammars of TextMate package '#{@path}':", err.stack, err) if err
          async.eachSeries paths, @loadGrammarAtPath, done

  loadGrammarAtPath: (path, done) =>
    TextMateGrammar.load path, (err, grammar) =>
      return console.log("Error loading grammar at path '#{path}':", err.stack ? err) if err
      @addGrammar(grammar)
      done()

  loadGrammarsSync: ->
    for path in fsUtils.list(@syntaxesPath, @legalGrammarExtensions) ? []
      @addGrammar(TextMateGrammar.loadSync(path))

  addGrammar: (grammar) ->
    @grammars.push(grammar)
    syntax.addGrammar(grammar) if atom.isPackageActive(@path)

  getGrammars: -> @grammars

  loadScopedProperties: ->
    @scopedProperties = []

    for grammar in @getGrammars()
      if properties = @propertiesFromTextMateSettings(grammar)
        selector = syntax.cssSelectorFromScopeSelector(grammar.scopeName)
        @scopedProperties.push({selector, properties})

    for {scope, settings} in @getTextMatePreferenceObjects()
      if properties = @propertiesFromTextMateSettings(settings)
        selector = syntax.cssSelectorFromScopeSelector(scope) if scope?
        @scopedProperties.push({selector, properties})

  getTextMatePreferenceObjects: ->
    preferenceObjects = []
    if fsUtils.exists(@preferencesPath)
      for preferencePath in fsUtils.list(@preferencesPath)
        try
          preferenceObjects.push(fsUtils.readObject(preferencePath))
        catch e
          console.warn "Failed to parse preference at path '#{preferencePath}'", e.stack
    preferenceObjects

  propertiesFromTextMateSettings: (textMateSettings) ->
    if textMateSettings.shellVariables
      shellVariables = {}
      for {name, value} in textMateSettings.shellVariables
        shellVariables[name] = value
      textMateSettings.shellVariables = shellVariables

    editorProperties = _.compactObject(
      commentStart: _.valueForKeyPath(textMateSettings, 'shellVariables.TM_COMMENT_START')
      commentEnd: _.valueForKeyPath(textMateSettings, 'shellVariables.TM_COMMENT_END')
      increaseIndentPattern: textMateSettings.increaseIndentPattern
      decreaseIndentPattern: textMateSettings.decreaseIndentPattern
      foldEndPattern: textMateSettings.foldingStopMarker
    )
    { editor: editorProperties } if _.size(editorProperties) > 0
