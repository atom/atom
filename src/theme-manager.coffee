path = require 'path'

_ = require 'underscore-plus'
{Emitter} = require 'emissary'
fs = require 'fs-plus'
Q = require 'q'

{$} = require './space-pen-extensions'
Package = require './package'
{File} = require 'pathwatcher'

# Public: Handles loading and activating available themes.
#
# An instance of this class is always available as the `atom.themes` global.
module.exports =
class ThemeManager
  Emitter.includeInto(this)

  constructor: ({@packageManager, @resourcePath, @configDirPath}) ->
    @lessCache = null
    @packageManager.registerPackageActivator(this, ['theme'])

  getAvailableNames: ->
    # TODO: Maybe should change to list all the available themes out there?
    @getLoadedNames()

  # Public: Get an array of all the loaded theme names.
  getLoadedNames: ->
    theme.name for theme in @getLoadedThemes()

  # Public: Get an array of all the active theme names.
  getActiveNames: ->
    theme.name for theme in @getActiveThemes()

  # Public: Get an array of all the active themes.
  getActiveThemes: ->
    pack for pack in @packageManager.getActivePackages() when pack.isTheme()

  # Public: Get an array of all the loaded themes.
  getLoadedThemes: ->
    pack for pack in @packageManager.getLoadedPackages() when pack.isTheme()

  activatePackages: (themePackages) -> @activateThemes()

  # Get the enabled theme names from the config.
  #
  # Returns an array of theme names in the order that they should be activated.
  getEnabledThemeNames: ->
    themeNames = atom.config.get('core.themes') ? []
    themeNames = [themeNames] unless _.isArray(themeNames)
    themeNames = themeNames.filter (themeName) ->
      themeName and typeof themeName is 'string'

    # Reverse so the first (top) theme is loaded after the others. We want
    # the first/top theme to override later themes in the stack.
    themeNames.reverse()

  activateThemes: ->
    deferred = Q.defer()

    # atom.config.observe runs the callback once, then on subsequent changes.
    atom.config.observe 'core.themes', =>
      @deactivateThemes()

      @refreshLessCache() # Update cache for packages in core.themes config

      promises = []
      for themeName in @getEnabledThemeNames()
        if @packageManager.resolvePackagePath(themeName)
          promises.push(@packageManager.activatePackage(themeName))
        else
          console.warn("Failed to activate theme '#{themeName}' because it isn't installed.")

      Q.all(promises).then =>
        @refreshLessCache() # Update cache again now that @getActiveThemes() is populated
        @loadUserStylesheet()
        @reloadBaseStylesheets()
        @emit('reloaded')
        deferred.resolve()

    deferred.promise

  deactivateThemes: ->
    @unwatchUserStylesheet()
    @packageManager.deactivatePackage(pack.name) for pack in @getActiveThemes()
    null

  refreshLessCache: ->
    @lessCache?.setImportPaths(@getImportPaths())

  # Public: Set the list of enabled themes.
  #
  # enabledThemeNames - An {Array} of {String} theme names.
  setEnabledThemes: (enabledThemeNames) ->
    atom.config.set('core.themes', enabledThemeNames)

  getImportPaths: ->
    activeThemes = @getActiveThemes()
    if activeThemes.length > 0
      themePaths = (theme.getStylesheetsPath() for theme in activeThemes when theme)
    else
      themePaths = []
      for themeName in @getEnabledThemeNames()
        if themePath = @packageManager.resolvePackagePath(themeName)
          themePaths.push(path.join(themePath, Package.stylesheetsDir))

    themePaths.filter (themePath) -> fs.isDirectorySync(themePath)

  # Public: Returns the {String} path to the user's stylesheet under ~/.atom
  getUserStylesheetPath: ->
    stylesheetPath = fs.resolve(path.join(@configDirPath, 'styles'), ['css', 'less'])
    if fs.isFileSync(stylesheetPath)
      stylesheetPath
    else
      path.join(@configDirPath, 'styles.less')

  unwatchUserStylesheet: ->
    @userStylesheetFile?.off()
    @userStylesheetFile = null
    @removeStylesheet(@userStylesheetPath) if @userStylesheetPath?

  loadUserStylesheet: ->
    @unwatchUserStylesheet()
    userStylesheetPath = @getUserStylesheetPath()
    return unless fs.isFileSync(userStylesheetPath)

    @userStylesheetPath = userStylesheetPath
    @userStylesheetFile = new File(userStylesheetPath)
    @userStylesheetFile.on 'contents-changed moved removed', =>
      @loadUserStylesheet()
    userStylesheetContents = @loadStylesheet(userStylesheetPath)
    @applyStylesheet(userStylesheetPath, userStylesheetContents, 'userTheme')

  loadBaseStylesheets: ->
    @requireStylesheet('bootstrap/less/bootstrap')
    @reloadBaseStylesheets()

  reloadBaseStylesheets: ->
    @requireStylesheet('../static/atom')
    if nativeStylesheetPath = fs.resolveOnLoadPath(process.platform, ['css', 'less'])
      @requireStylesheet(nativeStylesheetPath)

  stylesheetElementForId: (id, htmlElement=$('html')) ->
    htmlElement.find("""head style[id="#{id}"]""")

  resolveStylesheet: (stylesheetPath) ->
    if path.extname(stylesheetPath).length > 0
      fs.resolveOnLoadPath(stylesheetPath)
    else
      fs.resolveOnLoadPath(stylesheetPath, ['css', 'less'])

  # Public: Resolve and apply the stylesheet specified by the path.
  #
  # This supports both CSS and LESS stylsheets.
  #
  # stylesheetPath - A {String} path to the stylesheet that can be an absolute
  #                  path or a relative path that will be resolved against the
  #                  load path.
  #
  # Returns the absolute path to the required stylesheet.
  requireStylesheet: (stylesheetPath, type = 'bundled', htmlElement) ->
    if fullPath = @resolveStylesheet(stylesheetPath)
      content = @loadStylesheet(fullPath)
      @applyStylesheet(fullPath, content, type = 'bundled', htmlElement)
    else
      throw new Error("Could not find a file at path '#{stylesheetPath}'")

    fullPath

  loadStylesheet: (stylesheetPath) ->
    if path.extname(stylesheetPath) is '.less'
      @loadLessStylesheet(stylesheetPath)
    else
      fs.readFileSync(stylesheetPath, 'utf8')

  loadLessStylesheet: (lessStylesheetPath) ->
    unless @lessCache?
      LessCompileCache = require './less-compile-cache'
      @lessCache = new LessCompileCache({@resourcePath, importPaths: @getImportPaths()})

    try
      @lessCache.read(lessStylesheetPath)
    catch e
      console.error """
        Error compiling less stylesheet: #{lessStylesheetPath}
        Line number: #{e.line}
        #{e.message}
      """

  stringToId: (string) ->
    string.replace(/\\/g, '/')

  removeStylesheet: (stylesheetPath) ->
    fullPath = @resolveStylesheet(stylesheetPath) ? stylesheetPath
    element = @stylesheetElementForId(@stringToId(fullPath))
    if element.length > 0
      stylesheet = element[0].sheet
      element.remove()
      @emit 'stylesheet-removed', stylesheet
      @emit 'stylesheets-changed'

  applyStylesheet: (path, text, type = 'bundled', htmlElement=$('html')) ->
    styleElement = @stylesheetElementForId(@stringToId(path), htmlElement)
    if styleElement.length
      @emit 'stylesheet-removed', styleElement[0].sheet
      styleElement.text(text)
    else
      styleElement = $("<style class='#{type}' id='#{@stringToId(path)}'>#{text}</style>")
      if htmlElement.find("head style.#{type}").length
        htmlElement.find("head style.#{type}:last").after(styleElement)
      else
        htmlElement.find("head").append(styleElement)

    @emit 'stylesheet-added', styleElement[0].sheet
    @emit 'stylesheets-changed'
