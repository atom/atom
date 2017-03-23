Package = require './package'

module.exports =
class ThemePackage extends Package
  getType: -> 'theme'

  getStyleSheetPriority: -> 1

  enable: ->
    @config.unshiftAtKeyPath('core.themes', @name)

  disable: ->
    @config.removeAtKeyPath('core.themes', @name)

  preload: ->
    @loadTime = 0
    @configSchemaRegisteredOnLoad = @registerConfigSchemaFromMetadata()

  finishLoading: ->


  load: ->
    @loadTime = 0
    @configSchemaRegisteredOnLoad = @registerConfigSchemaFromMetadata()
    this

  activate: ->
    @activationPromise ?= new Promise (resolve, reject) =>
      @resolveActivationPromise = resolve
      @rejectActivationPromise = reject
      @measure 'activateTime', =>
        try
          @loadStylesheets()
          @activateNow()
        catch error
          @handleError("Failed to activate the #{@name} theme", error)
