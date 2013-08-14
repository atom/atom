fsUtils = require 'fs-utils'
path = require 'path'

### Internal ###

module.exports =
class Theme
  stylesheetPath: null
  stylesheets: null

  constructor: (name) ->
    @stylesheets = []
    if fsUtils.exists(name)
      @stylesheetPath = name
    else
      @stylesheetPath = fsUtils.resolve(config.themeDirPaths..., name, ['', '.css', 'less'])

    throw new Error("No theme exists named '#{name}'") unless @stylesheetPath

    @load()

  # Loads the stylesheets found in a `package.cson` file.
  load: ->
    if path.extname(@stylesheetPath) in ['.css', '.less']
      @loadStylesheet(@stylesheetPath)
    else
      metadataPath = fsUtils.resolveExtension(path.join(@stylesheetPath, 'package'), ['cson', 'json'])
      if fsUtils.isFileSync(metadataPath)
        stylesheetNames = fsUtils.readObjectSync(metadataPath)?.stylesheets
        if stylesheetNames
          for name in stylesheetNames
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
