AtomPackage = require './atom-package'
Package = require './package'

### Internal: Loads and resolves packages. ###

module.exports =
class ThemePackage extends AtomPackage

  getType: -> 'theme'

  getStylesheetType: -> 'theme'

  enable: ->
    themes = atom.config.get('core.themes') ? []
    themes.unshift(@metadata.name)
    atom.config.set('core.themes', themes)

  disable: ->
    atom.config.removeAtKeyPath('core.themes', @metadata.name)

  load: ->
    @measure 'loadTime', =>
      try
        @metadata ?= Package.loadMetadata(@path)
      catch e
        console.warn "Failed to load theme named '#{@name}'", e.stack ? e
    this

  activate: ->
    @measure 'activateTime', =>
      @loadStylesheets()
      @activateNow()
