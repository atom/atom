Q = require 'q'
AtomPackage = require './atom-package'

module.exports =
class ThemePackage extends AtomPackage
  getType: -> 'theme'

  getStylesheetType: -> 'theme'

  enable: ->
    atom.config.unshiftAtKeyPath('core.themes', @name)

  disable: ->
    atom.config.removeAtKeyPath('core.themes', @name)

  load: ->
    @measure 'loadTime', =>
      try
        @metadata ?= Package.loadMetadata(@path)
      catch error
        console.warn "Failed to load theme named '#{@name}'", error.stack ? error
    this

  activate: ->
    return @activationDeferred.promise if @activationDeferred?

    @activationDeferred = Q.defer()
    @measure 'activateTime', =>
      @loadStylesheets()
      @activateNow()

    @activationDeferred.promise
