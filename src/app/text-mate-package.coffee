Package = require 'package'
TextMateBundle = require 'text-mate-bundle'
fs = require 'fs'
plist = require 'plist'

module.exports =
class TextMatePackage extends Package
  @testName: (packageName) ->
    /(\.|_|-)tmbundle$/.test(packageName)

  @translateScopeSelector: (scopeSelector) ->
    scopeSelector.split(', ').map((commaFragment) ->
      commaFragment.split(' ').map((spaceFragment) ->
        spaceFragment.split('.').map((dotFragment) ->
          '.' + dotFragment
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
        plist.parseString fs.read(preferencePath), (e, data) ->
          if e
            console.warn "Failed to parse preference at path '#{preferencePath}'", e.stack
          else
            { scope, settings } = data[0]
            selector = TextMatePackage.translateScopeSelector(scope) if scope?
            scopedProperties.push({selector: selector, properties: settings})
    scopedProperties
