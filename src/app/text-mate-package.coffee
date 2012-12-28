Package = require 'package'
TextMateBundle = require 'text-mate-bundle'
fs = require 'fs'
plist = require 'plist'
_ = require 'underscore'

module.exports =
class TextMatePackage extends Package
  @testName: (packageName) ->
    /(\.|_|-)tmbundle$/.test(packageName)

  @cssSelectorForScopeSelector: (scopeSelector) ->
    scopeSelector.split(', ').map((commaFragment) ->
      commaFragment.split(' ').map((spaceFragment) ->
        spaceFragment.split('.').map((dotFragment) ->
          '.' + dotFragment.replace(/\+/g, '\\+')
        ).join('')
      ).join(' ')
    ).join(', ')

  load: ->
    TextMateBundle.load(@name)
    super

  constructor: ->
    super
    @preferencesPath = fs.join(@path, "Preferences")
    @syntaxesPath = fs.join(@path, "Syntaxes")

  getScopedProperties: ->
    scopedProperties = []
    if fs.exists(@preferencesPath)
      for preferencePath in fs.list(@preferencesPath)
        plist.parseString fs.read(preferencePath), (e, data) =>
          if e
            console.warn "Failed to parse preference at path '#{preferencePath}'", e.stack
          else
            { scope, settings } = data[0]
            if properties = @translateProperties(settings)
              selector = TextMatePackage.cssSelectorForScopeSelector(scope) if scope?
              scopedProperties.push({selector, properties})
    scopedProperties

  translateProperties: (textMateSettings) ->
    if textMateSettings.shellVariables
      shellVariables = {}
      for {name, value} in textMateSettings.shellVariables
        shellVariables[name] = value
      textMateSettings.shellVariables = shellVariables

    editorProperties = _.compactObject(
      commentStart: _.valueForKeyPath(textMateSettings, 'shellVariables.TM_COMMENT_START')
      commentEnd: _.valueForKeyPath(textMateSettings, 'shellVariables.TM_COMMENT_END')
    )
    { editor: editorProperties } if _.size(editorProperties) > 0
