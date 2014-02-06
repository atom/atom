Package = require './package'
path = require 'path'
_ = require 'underscore-plus'
fs = require 'fs-plus'
async = require 'async'
Q = require 'q'

### Internal ###

module.exports =
class TextMatePackage extends Package
  @testName: (packageName) ->
    packageName = path.basename(packageName)
    /(^language-.+)|((\.|_|-)tmbundle$)/.test(packageName)

  @addPackageToActivationQueue: (pack)->
    @activationQueue ?= []
    @activationQueue.push(pack)
    @activateNextPacakageInQueue() if @activationQueue.length == 1

  @activateNextPacakageInQueue: ->
    if pack = @activationQueue[0]
      pack.loadGrammars()
        .then ->
          pack.loadScopedProperties()
        .then ->
          @activationQueue.shift()
          @activateNextPacakageInQueue()

  constructor: ->
    super
    @grammars = []
    @scopedProperties = []
    @metadata = {@name}

  getType: -> 'textmate'

  load: ->
    @measure 'loadTime', =>
      @metadata = Package.loadMetadata(@path, true)

  activate: ({sync, immediate}={})->
    if sync or immediate
      @loadGrammarsSync()
      @loadScopedPropertiesSync()
    else
      TextMatePackage.addPackageToActivationQueue(this)

  activateConfig: -> # noop

  deactivate: ->
    grammar.deactivate() for grammar in @grammars
    atom.syntax.removeProperties(@path)

  legalGrammarExtensions: ['plist', 'tmLanguage', 'tmlanguage', 'json', 'cson']

  loadGrammars: ->
    deferred = Q.defer()
    fs.isDirectory @getSyntaxesPath(), (isDirectory) =>
      return deferred.resolve() unless isDirectory

      fs.list @getSyntaxesPath(), @legalGrammarExtensions, (error, paths) =>
        if error?
          console.log("Error loading grammars of TextMate package '#{@path}':", error.stack, error)
          deferred.resolve()
        else
          promise = Q()
          promise = promise.then(=> @loadGrammarAtPath(path)) for path in paths

    deferred.promise

  loadGrammarAtPath: (grammarPath, done) =>
    Q.nfcall(atom.syntax.readGrammar, grammarPath)
      .then (grammar) ->
        @addGrammar(grammar)
      .fail (error) ->
        console.log("Error loading grammar at path '#{grammarPath}':", error.stack ? error)

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

  # Deprecated
  loadGrammarsSync: ->
    for grammarPath in fs.listSync(@getSyntaxesPath(), @legalGrammarExtensions)
      @addGrammar(atom.syntax.readGrammarSync(grammarPath))

  # Deprecated
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
