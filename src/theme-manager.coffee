path = require 'path'
EventEmitter = require './event-emitter'
Package = require './package'
AtomPackage = require './atom-package'

_ = require './underscore-extensions'
$ = require './jquery-extensions'
fsUtils = require './fs-utils'

# Private: Handles discovering and loading available themes.
module.exports =
class ThemeManager
  _.extend @prototype, EventEmitter

  constructor: ->
    @loadedThemes = []
    @activeThemes = []
    @lessCache = null

  # Internal-only:
  register: (theme) ->
    @loadedThemes.push(theme)
    theme

  # Internal-only:
  getAvailableNames: ->
    _.map @loadedThemes, (theme) -> theme.metadata.name

  # Internal-only:
  getActiveThemes: ->
    _.clone(@activeThemes)

  # Internal-only:
  getLoadedThemes: ->
    _.clone(@loadedThemes)

  # Internal-only:
  loadBaseStylesheets: ->
    @requireStylesheet('bootstrap/less/bootstrap')
    @reloadBaseStylesheets()

  # Internal-only:
  reloadBaseStylesheets: ->
    @requireStylesheet('../static/atom')
    if nativeStylesheetPath = fsUtils.resolveOnLoadPath(process.platform, ['css', 'less'])
      @requireStylesheet(nativeStylesheetPath)

  # Internal-only:
  stylesheetElementForId: (id) ->
    $("""head style[id="#{id}"]""")

  # Internal-only:
  resolveStylesheet: (stylesheetPath) ->
    if path.extname(stylesheetPath).length > 0
      fsUtils.resolveOnLoadPath(stylesheetPath)
    else
      fsUtils.resolveOnLoadPath(stylesheetPath, ['css', 'less'])

  # Public: resolves and applies the stylesheet specified by the path.
  #
  # * stylesheetPath: String. Can be an absolute path or the name of a CSS or
  #   LESS file in the stylesheets path.
  #
  # Returns the absolute path to the stylesheet
  requireStylesheet: (stylesheetPath) ->
    if fullPath = @resolveStylesheet(stylesheetPath)
      content = @loadStylesheet(fullPath)
      @applyStylesheet(fullPath, content)
    else
      throw new Error("Could not find a file at path '#{stylesheetPath}'")

    fullPath

  # Internal-only:
  loadStylesheet: (stylesheetPath) ->
    if path.extname(stylesheetPath) is '.less'
      @loadLessStylesheet(stylesheetPath)
    else
      fsUtils.read(stylesheetPath)

  # Internal-only:
  loadLessStylesheet: (lessStylesheetPath) ->
    unless lessCache?
      LessCompileCache = require './less-compile-cache'
      @lessCache = new LessCompileCache()

    try
      @lessCache.read(lessStylesheetPath)
    catch e
      console.error """
        Error compiling less stylesheet: #{lessStylesheetPath}
        Line number: #{e.line}
        #{e.message}
      """

  # Internal-only:
  removeStylesheet: (stylesheetPath) ->
    unless fullPath = @resolveStylesheet(stylesheetPath)
      throw new Error("Could not find a file at path '#{stylesheetPath}'")
    @stylesheetElementForId(fullPath).remove()

  # Internal-only:
  applyStylesheet: (id, text, ttype = 'bundled') ->
    styleElement = @stylesheetElementForId(id)
    if styleElement.length
      styleElement.text(text)
    else
      if $("head style.#{ttype}").length
        $("head style.#{ttype}:last").after "<style class='#{ttype}' id='#{id}'>#{text}</style>"
      else
        $("head").append "<style class='#{ttype}' id='#{id}'>#{text}</style>"

  # Internal-only:
  unload: ->
    @removeStylesheet(@userStylesheetPath) if @userStylesheetPath?
    theme.deactivate() while theme = @activeThemes.pop()

  # Internal-only:
  load: ->
    config.observe 'core.themes', (themeNames) =>
      @unload()
      themeNames = [themeNames] unless _.isArray(themeNames)

      # Reverse so the first (top) theme is loaded after the others. We want
      # the first/top theme to override later themes in the stack.
      themeNames = _.clone(themeNames).reverse()

      @activateTheme(themeName) for themeName in themeNames
      @loadUserStylesheet()
      @reloadBaseStylesheets()
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
    _.find @loadedThemes, (theme) -> theme.metadata.name is name

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
      themePaths = []
      for themeName in config.get('core.themes') ? []
        if themePath = @resolveThemePath(themeName)
          themePaths.push(path.join(themePath, AtomPackage.stylesheetsDir))

    themePath for themePath in themePaths when fsUtils.isDirectorySync(themePath)

  # Private:
  loadUserStylesheet: ->
    if userStylesheetPath = @getUserStylesheetPath()
      @userStylesheetPath = userStylesheetPath
      userStylesheetContents = @loadStylesheet(userStylesheetPath)
      @applyStylesheet(userStylesheetPath, userStylesheetContents, 'userTheme')
