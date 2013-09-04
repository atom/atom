fsUtils = require 'fs-utils'
path = require 'path'

### Internal ###

module.exports =
class Theme
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

    @load()

  # Loads the stylesheets found in a `package.cson` file.
  load: ->
    if path.extname(@stylesheetPath) in ['.css', '.less']
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

  # Given a path, this loads it as a stylesheet.
  #
  # stylesheetPath - A {String} to a stylesheet
  loadStylesheet: (stylesheetPath) ->
    @stylesheets.push stylesheetPath
    content = window.loadStylesheet(stylesheetPath)
    window.applyStylesheet(stylesheetPath, content, 'userTheme')

  deactivate: ->
    window.removeStylesheet(stylesheetPath) for stylesheetPath in @stylesheets
