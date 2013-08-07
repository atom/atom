fsUtils = require 'fs-utils'

### Internal ###

module.exports =
class Theme
  @resolve: (name) ->
    if fsUtils.exists(name)
      name
    else
      fsUtils.resolve(config.themeDirPaths..., name, ['', '.tmTheme', '.css', 'less'])

  @load: (name) ->
    TextMateTheme = require 'text-mate-theme'
    AtomTheme = require 'atom-theme'

    path = Theme.resolve(name)
    throw new Error("No theme exists named '#{name}'") unless path

    theme =
      if TextMateTheme.testPath(path)
        new TextMateTheme(path)
      else
        new AtomTheme(path)

    theme.load()
    theme

  constructor: (@path) ->
    @stylesheets = {}

  load: ->
    for stylesheetPath, stylesheetContent of @stylesheets
      applyStylesheet(stylesheetPath, stylesheetContent, 'userTheme')

  deactivate: ->
    for stylesheetPath, stylesheetContent of @stylesheets
      removeStylesheet(stylesheetPath)
