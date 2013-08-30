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
    @registeredThemes = []
    @activeThemes = []

  register: (theme) ->
    @registeredThemes.push(theme)

  getAvailableNames: ->
    _.map(@registeredThemes, (t) -> t?.metadata?.name)

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
    theme = _.find(@registeredThemes, (t) -> t.metadata.name == name)
    return console.warn("Theme '#{name}' not found.") unless theme

    try
      theme.activate()
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
      theme.getStylesheetPath() for theme in @activeThemes when theme.getStylesheetPath
    else
      themeNames = config.get('core.themes')
      themes = []
      for themeName in themeNames
        theme = _.find(@registeredTheme, (t) -> t.metadata.name == themeName)
        themes.push(theme.getStylesheetPath()) if theme?.getStylesheetPath
      themes

  loadUserStylesheet: ->
    if userStylesheetPath = @getUserStylesheetPath()
      @userStylesheetPath = userStylesheetPath
      userStylesheetContents = loadStylesheet(userStylesheetPath)
      applyStylesheet(userStylesheetPath, userStylesheetContents, 'userTheme')
