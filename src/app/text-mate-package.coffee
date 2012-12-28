Package = require 'package'
TextMateBundle = require 'text-mate-bundle'
fs = require 'fs'
plist = require 'plist'
_ = require 'underscore'

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

  load: ->
    @bundle = TextMateBundle.load(@name)
    @grammars = @bundle.grammars
    super

  constructor: ->
    super
    @preferencesPath = fs.join(@path, "Preferences")
    @syntaxesPath = fs.join(@path, "Syntaxes")

  getScopedProperties: ->
    scopedProperties = []

    for grammar in @grammars
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