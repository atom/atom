path = require 'path'

_ = require 'underscore'

fsUtils = require 'fs-utils'
Theme = require 'theme'

module.exports =
class ThemeManager
  constructor: ->
    @loadedThemes = []

  getAvailablePaths: ->
    themePaths = []
    for themeDirPath in config.themeDirPaths
      themePaths.push(fsUtils.listSync(themeDirPath, ['', '.css', 'less'])...)
    _.uniq(themePaths)

  getAvailableNames: ->
    path.basename(themePath).split('.')[0] for themePath in @getAvailablePaths()

  load: ->
    config.observe 'core.themes', (themeNames) =>
      removeStylesheet(@userStylesheetPath) if @userStylesheetPath?
      theme.deactivate() while theme = @loadedThemes.pop()
      themeNames = [themeNames] unless _.isArray(themeNames)
      @loadTheme(themeName) for themeName in themeNames
      @loadUserStylesheet()

  loadTheme: (name) -> @loadedThemes.push(new Theme(name))

  getUserStylesheetPath: ->
    stylesheetPath = fsUtils.resolve(path.join(config.configDirPath, 'user'), ['css', 'less'])
    if fsUtils.isFileSync(stylesheetPath)
      stylesheetPath
    else
      null

  loadUserStylesheet: ->
    if userStylesheetPath = @getUserStylesheetPath()
      @userStylesheetPath = userStylesheetPath
      userStylesheetContents = loadStylesheet(userStylesheetPath)
      applyStylesheet(userStylesheetPath, userStylesheetContents, 'userTheme')
