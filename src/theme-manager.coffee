path = require 'path'
EventEmitter = require 'event-emitter'
Package = require 'package'
AtomPackage = require 'atom-package'

_ = require 'underscore'

fsUtils = require 'fs-utils'

# Private: Handles discovering and loading available themes.
module.exports =
class ThemeManager
  _.extend @prototype, EventEmitter

  constructor: ->
    @loadedThemes = []
    @activeThemes = []

  # Internal-only:
  register: (theme) ->
    @loadedThemes.push(theme)
    theme

  # Internal-only:
  getAvailableNames: ->
    _.map(@loadedThemes, (t) -> t.metadata.name)

  # Internal-only:
  getActiveThemes: ->
    _.clone(@activeThemes)

  # Internal-only:
  unload: ->
    removeStylesheet(@userStylesheetPath) if @userStylesheetPath?
    theme.deactivate() while theme = @activeThemes.pop()

  # Internal-only:
  load: ->
    config.observe 'core.themes', (themeNames) =>
      @unload()
      themeNames = [themeNames] unless _.isArray(themeNames)
      @activateTheme(themeName) for themeName in themeNames
      @loadUserStylesheet()

      @trigger('reloaded')

  # Private:
  loadTheme: (name, options) ->
    if themePath = @resolveThemePath(name)
      return theme if theme = @getLoadedTheme(name)
      pack = Package.load(themePath, options)
      if pack.isTheme()
        @register(pack)
      else
        throw new Error("Attempted to load a non-theme package '#{name}' as a theme")
    else
      throw new Error("Could not resolve '#{name}' to a theme path")

  # Private:
  getLoadedTheme: (name) ->
    _.find(@loadedThemes, (t) -> t.metadata.name == name)

  # Private:
  resolveThemePath: (name) ->
    return name if fsUtils.isDirectorySync(name)

    packagePath = fsUtils.resolve(config.packageDirPaths..., name)
    return packagePath if fsUtils.isDirectorySync(packagePath)

    packagePath = path.join(window.resourcePath, 'node_modules', name)
    return packagePath if @isThemePath(packagePath)

  # Private:
  isThemePath: (packagePath) ->
    {engines, theme} = Package.loadMetadata(packagePath, true)
    engines?.atom? and theme

  # Private:
  activateTheme: (name) ->
    try
      theme = @loadTheme(name)
      theme.activate()
      @activeThemes.push(theme)
      @trigger('theme-activated', theme)
    catch error
      console.warn("Failed to load theme #{name}", error.stack ? error)

  # Public:
  getUserStylesheetPath: ->
    stylesheetPath = fsUtils.resolve(path.join(config.configDirPath, 'user'), ['css', 'less'])
    if fsUtils.isFileSync(stylesheetPath)
      stylesheetPath
    else
      null

  # Public:
  getImportPaths: ->
    if @activeThemes.length > 0
      themePaths = (theme.getStylesheetsPath() for theme in @activeThemes when theme)
    else
      themeNames = config.get('core.themes')
      themePaths = (path.join(@resolveThemePath(themeName), AtomPackage.stylesheetsDir) for themeName in themeNames)

    themePath for themePath in themePaths when fsUtils.isDirectorySync(themePath)

  # Private:
  loadUserStylesheet: ->
    if userStylesheetPath = @getUserStylesheetPath()
      @userStylesheetPath = userStylesheetPath
      userStylesheetContents = loadStylesheet(userStylesheetPath)
      applyStylesheet(userStylesheetPath, userStylesheetContents, 'userTheme')
