path = require 'path'
EventEmitter = require 'event-emitter'

_ = require 'underscore'

fsUtils = require 'fs-utils'
Theme = require 'theme'

module.exports =
class ThemeManager
  _.extend @prototype, EventEmitter

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

      @trigger('reload')

  loadTheme: (name) ->
    try
      @loadedThemes.push(new Theme(name))
    catch error
      console.warn("Failed to load theme #{name}", error.stack ? error)

  getUserStylesheetPath: ->
    stylesheetPath = fsUtils.resolve(path.join(config.configDirPath, 'user'), ['css', 'less'])
    if fsUtils.isFileSync(stylesheetPath)
      stylesheetPath
    else
      null

  getImportPaths: ->
    theme.directoryPath for theme in @loadedThemes when theme.directoryPath

  loadUserStylesheet: ->
    if userStylesheetPath = @getUserStylesheetPath()
      @userStylesheetPath = userStylesheetPath
      userStylesheetContents = loadStylesheet(userStylesheetPath)
      applyStylesheet(userStylesheetPath, userStylesheetContents, 'userTheme')
