Package = require './package'
path = require 'path'
_ = require 'underscore-plus'
fs = require 'fs-plus'
Q = require 'q'

module.exports =
class TextMatePackage extends Package
  @testName: (packageName) ->
    packageName = path.basename(packageName)
    /(^language-.+)|((\.|_|-)tmbundle$)/.test(packageName)

  @addToActivationPromise = (pack) ->
    @activationPromise ?= Q()
    @activationPromise = @activationPromise.then =>
      pack.loadGrammars()
        .then -> pack.loadScopedProperties()
        .fail (error) -> console.log pack.name, error.stack ? error

  constructor: ->
    super
    @grammars = []
    @scopedProperties = []
    @metadata = {@name}

  getType: -> 'textmate'

  load: ->
    @measure 'loadTime', =>
      @metadata = Package.loadMetadata(@path, true)

  activate: ->
    @measure 'activateTime', =>
      TextMatePackage.addToActivationPromise(this)

  activateSync: ->
    @loadGrammarsSync()
    @loadScopedPropertiesSync()

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
          promises = paths.map (path) => @loadGrammarAtPath(path)
          Q.all(promises).then -> deferred.resolve()

    deferred.promise

  loadGrammarAtPath: (grammarPath) ->
    deferred = Q.defer()
    atom.syntax.readGrammar grammarPath, (error, grammar) =>
      if error?
        console.log("Error loading grammar at path '#{grammarPath}':", error.stack ? error)
      else
        @addGrammar(grammar)
      deferred.resolve()

    deferred.promise

  addGrammar: (grammar) ->
    @grammars.push(grammar)
    grammar.activate()

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

  loadScopedProperties: ->
    scopedProperties = []

    for grammar in @getGrammars()
      if properties = @propertiesFromTextMateSettings(grammar)
        selector = atom.syntax.cssSelectorFromScopeSelector(grammar.scopeName)
        scopedProperties.push({selector, properties})

    @loadTextMatePreferenceObjects().then (preferenceObjects=[]) =>
      for {scope, settings} in preferenceObjects
        if properties = @propertiesFromTextMateSettings(settings)
          selector = atom.syntax.cssSelectorFromScopeSelector(scope) if scope?
          scopedProperties.push({selector, properties})

      @scopedProperties = scopedProperties
      for {selector, properties} in @scopedProperties
        atom.syntax.addProperties(@path, selector, properties)

  loadTextMatePreferenceObjects: ->
    deferred = Q.defer()
    fs.isDirectory @getPreferencesPath(), (isDirectory) =>
      return deferred.resolve() unless isDirectory
      fs.list @getPreferencesPath(), (error, paths) =>
        if error?
          console.log("Error loading preferences of TextMate package '#{@path}':", error.stack, error)
          deferred.resolve()
        else
          promises = paths.map (path) => @loadPreferencesAtPath(path)
          Q.all(promises).then (preferenceObjects) -> deferred.resolve(preferenceObjects)

    deferred.promise

  loadPreferencesAtPath: (preferencePath) ->
    deferred = Q.defer()
    fs.readObject preferencePath, (error, preference) ->
      if error?
        console.warn("Failed to parse preference at path '#{preferencePath}'", error.stack, error)
      deferred.resolve(preference)
    deferred.promise

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

    for {selector, properties} in @scopedProperties
      atom.syntax.addProperties(@path, selector, properties)
