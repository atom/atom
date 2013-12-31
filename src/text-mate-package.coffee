Package = require './package'
path = require 'path'
_ = require 'underscore-plus'
fs = require 'fs-plus'
async = require 'async'

### Internal ###

module.exports =
class TextMatePackage extends Package
  @testName: (packageName) ->
    packageName = path.basename(packageName)
    /(^language-.+)|((\.|_|-)tmbundle$)/.test(packageName)

  @getLoadQueue: ->
    return @loadQueue if @loadQueue
    @loadQueue = async.queue (pack, done) ->
      pack.loadGrammars ->
        pack.loadScopedProperties(done)

    @loadQueue

  constructor: ->
    super
    @grammars = []
    @scopedProperties = []
    @metadata = {@name}

  getType: -> 'textmate'

  load: ({sync}={}) ->
    @measure 'loadTime', =>
      @metadata = Package.loadMetadata(@path, true)

      if sync
        @loadGrammarsSync()
        @loadScopedPropertiesSync()
      else
        TextMatePackage.getLoadQueue().push(this)

  activate: ->
    @measure 'activateTime', =>
      grammar.activate() for grammar in @grammars
      for { selector, properties } in @scopedProperties
        atom.syntax.addProperties(@path, selector, properties)

  activateConfig: -> # noop

  deactivate: ->
    grammar.deactivate() for grammar in @grammars
    atom.syntax.removeProperties(@path)

  legalGrammarExtensions: ['plist', 'tmLanguage', 'tmlanguage', 'json', 'cson']

  loadGrammars: (done) ->
    fs.isDirectory @getSyntaxesPath(), (isDirectory) =>
      if isDirectory
        fs.list @getSyntaxesPath(), @legalGrammarExtensions, (error, paths) =>
          if error?
            console.log("Error loading grammars of TextMate package '#{@path}':", error.stack, error)
            done()
          else
            async.eachSeries(paths, @loadGrammarAtPath, done)
      else
        done()

  loadGrammarAtPath: (grammarPath, done) =>
    atom.syntax.readGrammar grammarPath, (error, grammar) =>
      if error?
        console.log("Error loading grammar at path '#{grammarPath}':", error.stack ? error)
      else
        @addGrammar(grammar)
        done?()

  loadGrammarsSync: ->
    for grammarPath in fs.listSync(@getSyntaxesPath(), @legalGrammarExtensions)
      @addGrammar(atom.syntax.readGrammarSync(grammarPath))

  addGrammar: (grammar) ->
    @grammars.push(grammar)
    grammar.activate() if @isActive()

  getGrammars: -> @grammars

  getSyntaxesPath: ->
    syntaxesPath = path.join(@path, "syntaxes")
    if fs.isDirectorySync(syntaxesPath)
      syntaxesPath
    else
      path.join(@path, "Syntaxes")

  getPreferencesPath: ->
    preferencesPath = path.join(@path, "preferences")
    if fs.isDirectorySync(preferencesPath)
      preferencesPath
    else
      path.join(@path, "Preferences")

  loadScopedPropertiesSync: ->
    for grammar in @getGrammars()
      if properties = @propertiesFromTextMateSettings(grammar)
        selector = atom.syntax.cssSelectorFromScopeSelector(grammar.scopeName)
        @scopedProperties.push({selector, properties})

    for preferencePath in fs.listSync(@getPreferencesPath())
      {scope, settings} = fs.readObjectSync(preferencePath)
      if properties = @propertiesFromTextMateSettings(settings)
        selector = atom.syntax.cssSelectorFromScopeSelector(scope) if scope?
        @scopedProperties.push({selector, properties})

    if @isActive()
      for {selector, properties} in @scopedProperties
        atom.syntax.addProperties(@path, selector, properties)

  loadScopedProperties: (callback) ->
    scopedProperties = []

    for grammar in @getGrammars()
      if properties = @propertiesFromTextMateSettings(grammar)
        selector = atom.syntax.cssSelectorFromScopeSelector(grammar.scopeName)
        scopedProperties.push({selector, properties})

    preferenceObjects = []
    done = =>
      for {scope, settings} in preferenceObjects
        if properties = @propertiesFromTextMateSettings(settings)
          selector = atom.syntax.cssSelectorFromScopeSelector(scope) if scope?
          scopedProperties.push({selector, properties})

      @scopedProperties = scopedProperties
      if @isActive()
        for {selector, properties} in @scopedProperties
          atom.syntax.addProperties(@path, selector, properties)
      callback?()
    @loadTextMatePreferenceObjects(preferenceObjects, done)

  loadTextMatePreferenceObjects: (preferenceObjects, done) ->
    fs.isDirectory @getPreferencesPath(), (isDirectory) =>
      return done() unless isDirectory

      fs.list @getPreferencesPath(), (error, paths) =>
        if error?
          console.log("Error loading preferences of TextMate package '#{@path}':", error.stack, error)
          done()
          return

        loadPreferencesAtPath = (preferencePath, done) ->
          fs.readObject preferencePath, (error, preferences) =>
            if error?
              console.warn("Failed to parse preference at path '#{preferencePath}'", error.stack, error)
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
      completions: textMateSettings.completions
    )
    { editor: editorProperties } if _.size(editorProperties) > 0
