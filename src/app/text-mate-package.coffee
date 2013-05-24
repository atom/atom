Package = require 'package'
fsUtils = require 'fs-utils'
_ = require 'underscore'
TextMateGrammar = require 'text-mate-grammar'
async = require 'async'

### Internal ###

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
    @scopedProperties = []
    @metadata = {@name}

  load: ({sync}={}) ->
    if sync
      @loadGrammarsSync()
      @loadScopedPropertiesSync()
    else
      TextMatePackage.getLoadQueue().push(this)

  activate: ->
    syntax.addGrammar(grammar) for grammar in @grammars
    for { selector, properties } in @scopedProperties
      syntax.addProperties(@path, selector, properties)

  activateConfig: -> # noop

  deactivate: ->
    syntax.removeGrammar(grammar) for grammar in @grammars
    syntax.removeProperties(@path)

  legalGrammarExtensions: ['plist', 'tmLanguage', 'tmlanguage', 'json']

  loadGrammars: (done) ->
    fsUtils.isDirectoryAsync @syntaxesPath, (isDirectory) =>
      return done() unless isDirectory

      fsUtils.listAsync @syntaxesPath, @legalGrammarExtensions, (error, paths) =>
        if error?
          console.log("Error loading grammars of TextMate package '#{@path}':", error.stack, error)
          done()
          return

        async.waterfall [
            (next) =>
              async.eachSeries paths, @loadGrammarAtPath, next
            (next) =>
              @loadScopedProperties()
              next()
        ], done

  loadGrammarAtPath: (path, done) =>
    TextMateGrammar.load path, (err, grammar) =>
      return console.log("Error loading grammar at path '#{path}':", err.stack ? err) if err
      @addGrammar(grammar)
      done()

  loadGrammarsSync: ->
    for path in fsUtils.list(@syntaxesPath, @legalGrammarExtensions)
      @addGrammar(TextMateGrammar.loadSync(path))

  addGrammar: (grammar) ->
    @grammars.push(grammar)
    syntax.addGrammar(grammar) if @isActive()

  getGrammars: -> @grammars

  loadScopedPropertiesSync: ->
    for grammar in @getGrammars()
      if properties = @propertiesFromTextMateSettings(grammar)
        selector = syntax.cssSelectorFromScopeSelector(grammar.scopeName)
        @scopedProperties.push({selector, properties})

    for path in fsUtils.list(@preferencesPath)
      {scope, settings} = fsUtils.readObject(path)
      if properties = @propertiesFromTextMateSettings(settings)
        selector = syntax.cssSelectorFromScopeSelector(scope) if scope?
        @scopedProperties.push({selector, properties})

    for {selector, properties} in @scopedProperties
      syntax.addProperties(@path, selector, properties)

  loadScopedProperties: ->
    scopedProperties = []

    for grammar in @getGrammars()
      if properties = @propertiesFromTextMateSettings(grammar)
        selector = syntax.cssSelectorFromScopeSelector(grammar.scopeName)
        scopedProperties.push({selector, properties})

    preferenceObjects = []
    done = =>
      for {scope, settings} in preferenceObjects
        if properties = @propertiesFromTextMateSettings(settings)
          selector = syntax.cssSelectorFromScopeSelector(scope) if scope?
          scopedProperties.push({selector, properties})

      @scopedProperties = scopedProperties
      if @isActive()
        for {selector, properties} in @scopedProperties
          syntax.addProperties(@path, selector, properties)
    @loadTextMatePreferenceObjects(preferenceObjects, done)

  loadTextMatePreferenceObjects: (preferenceObjects, done) ->
    fsUtils.isDirectoryAsync @preferencesPath, (isDirectory) =>
      return done() unless isDirectory

      fsUtils.listAsync @preferencesPath, (error, paths) =>
        if error?
          console.log("Error loading preferences of TextMate package '#{@path}':", error.stack, error)
          done()
          return

        loadPreferencesAtPath = (path, done) ->
          fsUtils.readObjectAsync path, (error, preferences) =>
            if error?
              console.warn("Failed to parse preference at path '#{path}'", error.stack, error)
            else
              preferenceObjects.push(preferences)
            done()
        async.eachSeries paths, loadPreferencesAtPath, done

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
