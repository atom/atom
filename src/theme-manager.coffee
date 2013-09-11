path = require 'path'
EventEmitter = require 'event-emitter'

_ = require 'underscore'

fsUtils = require 'fs-utils'
Theme = require 'theme'

# Private: Handles discovering and loading available themes.
module.exports =
class ThemeManager
  _.extend @prototype, EventEmitter

  constructor: ->
    @activeThemes = []

  getAvailablePaths: ->
    themePaths = []
    for themeDirPath in config.themeDirPaths
      themePaths.push(fsUtils.listSync(themeDirPath, ['', '.css', 'less'])...)
    _.uniq(themePaths)

  getAvailableNames: ->
    path.basename(themePath).split('.')[0] for themePath in @getAvailablePaths()

  getActiveThemes: ->
    _.clone(@activeThemes)

  unload: ->
    removeStylesheet(@userStylesheetPath) if @userStylesheetPath?
    theme.deactivate() while theme = @activeThemes.pop()

  load: ->
    config.observe 'core.themes', (themeNames) =>
      @unload()
      themeNames = [themeNames] unless _.isArray(themeNames)
      @activateTheme(themeName) for themeName in themeNames
      @loadUserStylesheet()

      @trigger('reloaded')

  activateTheme: (name) ->
    try
      theme = new Theme(name)
      @activeThemes.push(theme)
      @trigger('theme-activated', theme)
    catch error
      console.warn("Failed to load theme #{name}", error.stack ? error)

  getUserStylesheetPath: ->
    stylesheetPath = fsUtils.resolve(path.join(config.configDirPath, 'user'), ['css', 'less'])
    if fsUtils.isFileSync(stylesheetPath)
      stylesheetPath
    else
      null

  getImportPaths: ->
    if @activeThemes.length
      theme.directoryPath for theme in @activeThemes when theme.directoryPath
    else
      themeNames = config.get('core.themes')
      themes = []
      for themeName in themeNames
        themePath = Theme.resolve(themeName)
        themes.push(themePath) if fsUtils.isDirectorySync(themePath)
      themes

  loadUserStylesheet: ->
    if userStylesheetPath = @getUserStylesheetPath()
      @userStylesheetPath = userStylesheetPath
      userStylesheetContents = loadStylesheet(userStylesheetPath)
      applyStylesheet(userStylesheetPath, userStylesheetContents, 'userTheme')
