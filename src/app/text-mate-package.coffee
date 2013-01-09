Package = require 'package'
fs = require 'fs'
plist = require 'plist'
_ = require 'underscore'
TextMateGrammar = require 'text-mate-grammar'

module.exports =
class TextMatePackage extends Package
  @testName: (packageName) ->
    /(\.|_|-)tmbundle$/.test(packageName)

  @cssSelectorFromScopeSelector: (scopeSelector) ->
    scopeSelector.split(', ').map((commaFragment) ->
      commaFragment.split(' ').map((spaceFragment) ->
        spaceFragment.split('.').map((dotFragment) ->
          '.' + dotFragment.replace(/\+/g, '\\+')
        ).join('')
      ).join(' ')
    ).join(', ')

  constructor: ->
    super
    @preferencesPath = fs.join(@path, "Preferences")
    @syntaxesPath = fs.join(@path, "Syntaxes")

  load: ->
    try
      for grammar in @getGrammars()
        syntax.addGrammar(grammar)

      for { selector, properties } in @getScopedProperties()
        syntax.addProperties(selector, properties)
    catch e
      console.warn "Failed to load package named '#{@name}'", e.stack

  getGrammars: ->
    return @grammars if @grammars
    @grammars = []
    if fs.exists(@syntaxesPath)
      for grammarPath in fs.list(@syntaxesPath)
        try
          @grammars.push TextMateGrammar.loadFromPath(grammarPath)
        catch e
          console.warn "Failed to load grammar at path '#{grammarPath}'", e.stack
    @grammars

  getScopedProperties: ->
    scopedProperties = []

    for grammar in @getGrammars()
      if properties = @propertiesFromTextMateSettings(grammar)
        selector = @cssSelectorFromScopeSelector(grammar.scopeName)
        scopedProperties.push({selector, properties})

    for {scope, settings} in @getTextMatePreferenceObjects()
      if properties = @propertiesFromTextMateSettings(settings)
        selector = @cssSelectorFromScopeSelector(scope) if scope?
        scopedProperties.push({selector, properties})

    scopedProperties

  getTextMatePreferenceObjects: ->
    preferenceObjects = []
    if fs.exists(@preferencesPath)
      for preferencePath in fs.list(@preferencesPath)
        plist.parseString fs.read(preferencePath), (e, data) =>
          if e
            console.warn "Failed to parse preference at path '#{preferencePath}'", e.stack
          else
            preferenceObjects.push(data[0])
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

  cssSelectorFromScopeSelector: (scopeSelector) ->
    @constructor.cssSelectorFromScopeSelector(scopeSelector)
