path = require 'path'
{Emitter} = require 'emissary'
Package = require './package'
AtomPackage = require './atom-package'

_ = require 'underscore-plus'
{$} = require './space-pen-extensions'
fsUtils = require './fs-utils'

# Private: Handles discovering and loading available themes.
###
Themes are a subset of packages
###
module.exports =
class ThemeManager
  Emitter.includeInto(this)

  constructor: (@packageManager) ->
    @lessCache = null

  # Internal-only:
  getAvailableNames: ->
    # TODO: Maybe should change to list all the available themes out there?
    @getLoadedNames()

  getLoadedNames: ->
    theme.name for theme in @getLoadedThemes()

  # Internal-only:
  getActiveNames: ->
    theme.name for theme in @getActiveThemes()

  # Internal-only:
  getActiveThemes: ->
    pack for pack in @packageManager.getActivePackages() when pack.isTheme()

  # Internal-only:
  getLoadedThemes: ->
    pack for pack in @packageManager.getLoadedPackages() when pack.isTheme()

  # Internal-only:
  activateThemes: ->
    # atom.config.observe runs the callback once, then on subsequent changes.
    atom.config.observe 'core.themes', (themeNames) =>
      @deactivateThemes()
      themeNames = [themeNames] unless _.isArray(themeNames)

      # Reverse so the first (top) theme is loaded after the others. We want
      # the first/top theme to override later themes in the stack.
      themeNames = _.clone(themeNames).reverse()

      @packageManager.activatePackage(themeName) for themeName in themeNames
      @loadUserStylesheet()
      @reloadBaseStylesheets()
      @emit('reloaded')

  # Internal-only:
  deactivateThemes: ->
    @removeStylesheet(@userStylesheetPath) if @userStylesheetPath?
    @packageManager.deactivatePackage(pack.name) for pack in @getActiveThemes()
    null

  # Public:
  getImportPaths: ->
    activeThemes = @getActiveThemes()
    if activeThemes.length > 0
      themePaths = (theme.getStylesheetsPath() for theme in activeThemes when theme)
    else
      themePaths = []
      for themeName in atom.config.get('core.themes') ? []
        if themePath = @packageManager.resolvePackagePath(themeName)
          themePaths.push(path.join(themePath, AtomPackage.stylesheetsDir))

    themePath for themePath in themePaths when fsUtils.isDirectorySync(themePath)

  # Public:
  getUserStylesheetPath: ->
    stylesheetPath = fsUtils.resolve(path.join(atom.config.configDirPath, 'user'), ['css', 'less'])
    if fsUtils.isFileSync(stylesheetPath)
      stylesheetPath
    else
      null

  # Private:
  loadUserStylesheet: ->
    if userStylesheetPath = @getUserStylesheetPath()
      @userStylesheetPath = userStylesheetPath
      userStylesheetContents = @loadStylesheet(userStylesheetPath)
      @applyStylesheet(userStylesheetPath, userStylesheetContents, 'userTheme')

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
