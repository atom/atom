_ = require 'underscore'
fsUtils = require 'fs-utils'
path = require 'path'
EventEmitter = require 'event-emitter'

### Internal ###

module.exports =
class Theme
  _.extend @prototype, EventEmitter

  stylesheetPath: null
  stylesheets: null

  @resolve: (themeName) ->
    if fsUtils.exists(themeName)
      themeName
    else
      fsUtils.resolve(config.themeDirPaths..., themeName, ['', '.css', 'less'])

  constructor: (name) ->
    @stylesheets = []
    @stylesheetPath = Theme.resolve(name)

    throw new Error("No theme exists named '#{name}'") unless @stylesheetPath

    @activate()

  getPath: ->
    @stylesheetPath

  getStylesheetPaths: ->
    _.clone(@stylesheets)

  isFile: ->
    path.extname(@stylesheetPath) in ['.css', '.less']

  # Loads the stylesheets found in a `package.cson` file. If no package.json
  # file, it will load them in alphabetical order.
  activate: ->
    if @isFile()
      @loadStylesheet(@stylesheetPath)
    else
      @directoryPath = @stylesheetPath
      metadataPath = fsUtils.resolveExtension(path.join(@stylesheetPath, 'package'), ['cson', 'json'])
      if fsUtils.isFileSync(metadataPath)
        @metadata = fsUtils.readObjectSync(metadataPath)
        if @metadata?.stylesheets
          for name in @metadata.stylesheets
            filename = fsUtils.resolveExtension(path.join(@stylesheetPath, name), ['.css', '.less', ''])
            @loadStylesheet(filename)
      else
        @loadStylesheet(stylesheetPath) for stylesheetPath in fsUtils.listSync(@stylesheetPath, ['.css', '.less'])

  deactivate: ->
    window.removeStylesheet(stylesheetPath) for stylesheetPath in @stylesheets
    @trigger('deactivated')

  # Given a path, this loads it as a stylesheet. Can be called more than once
  # to reload a stylesheet.
  #
  # * stylesheetPath: A {String} to a stylesheet
  loadStylesheet: (stylesheetPath) ->
    @stylesheets.push(stylesheetPath) unless _.contains(@stylesheets, stylesheetPath)
    content = window.loadStylesheet(stylesheetPath)
    window.applyStylesheet(stylesheetPath, content, 'userTheme')

