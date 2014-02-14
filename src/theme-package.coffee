Q = require 'q'
AtomPackage = require './atom-package'

module.exports =
class ThemePackage extends AtomPackage
  getType: -> 'theme'

  getStylesheetType: -> 'theme'

  enable: ->
    atom.config.unshiftAtKeyPath('core.themes', @metadata.name)

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
    return @activationDeferred.promise if @activationDeferred?

    @activationDeferred = Q.defer()
    @measure 'activateTime', =>
      @loadStylesheets()
      @activateNow()

    @activationDeferred.promise
