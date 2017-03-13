path = require 'path'
_ = require 'underscore-plus'
{Emitter, CompositeDisposable} = require 'event-kit'
{File} = require 'pathwatcher'
fs = require 'fs-plus'

# Extended: Handles loading and activating available themes.
#
# An instance of this class is always available as the `atom.themes` global.
module.exports =
class ThemeManager
  constructor: ({@packageManager, @resourcePath, @configDirPath, @safeMode, @config, @styleManager, @notificationManager, @viewRegistry}) ->
    @emitter = new Emitter
    @styleSheetDisposablesBySourcePath = {}
    @lessCache = null
    @initialLoadComplete = false
    @packageManager.registerPackageActivator(this, ['theme'])
    @packageManager.onDidActivateInitialPackages =>
      @onDidChangeActiveThemes => @packageManager.reloadActivePackageStyleSheets()

  ###
  Section: Event Subscription
  ###

  # Essential: Invoke `callback` when style sheet changes associated with
  # updating the list of active themes have completed.
  #
  # * `callback` {Function}
  onDidChangeActiveThemes: (callback) ->
    @emitter.on 'did-change-active-themes', callback

  ###
  Section: Accessing Available Themes
  ###

  getAvailableNames: ->
    # TODO: Maybe should change to list all the available themes out there?
    @getLoadedNames()

  ###
  Section: Accessing Loaded Themes
  ###

  # Public: Returns an {Array} of {String}s of all the loaded theme names.
  getLoadedThemeNames: ->
    theme.name for theme in @getLoadedThemes()

  # Public: Returns an {Array} of all the loaded themes.
  getLoadedThemes: ->
    pack for pack in @packageManager.getLoadedPackages() when pack.isTheme()

  ###
  Section: Accessing Active Themes
  ###

  # Public: Returns an {Array} of {String}s all the active theme names.
  getActiveThemeNames: ->
    theme.name for theme in @getActiveThemes()

  # Public: Returns an {Array} of all the active themes.
  getActiveThemes: ->
    pack for pack in @packageManager.getActivePackages() when pack.isTheme()

  activatePackages: -> @activateThemes()

  ###
  Section: Managing Enabled Themes
  ###

  warnForNonExistentThemes: ->
    themeNames = @config.get('core.themes') ? []
    themeNames = [themeNames] unless _.isArray(themeNames)
    for themeName in themeNames
      unless themeName and typeof themeName is 'string' and @packageManager.resolvePackagePath(themeName)
        console.warn("Enabled theme '#{themeName}' is not installed.")

  # Public: Get the enabled theme names from the config.
  #
  # Returns an array of theme names in the order that they should be activated.
  getEnabledThemeNames: ->
    themeNames = @config.get('core.themes') ? []
    themeNames = [themeNames] unless _.isArray(themeNames)
    themeNames = themeNames.filter (themeName) =>
      if themeName and typeof themeName is 'string'
        return true if @packageManager.resolvePackagePath(themeName)
      false

    # Use a built-in syntax and UI theme any time the configured themes are not
    # available.
    if themeNames.length < 2
      builtInThemeNames = [
        'atom-dark-syntax'
        'atom-dark-ui'
        'atom-light-syntax'
        'atom-light-ui'
        'base16-tomorrow-dark-theme'
        'base16-tomorrow-light-theme'
        'solarized-dark-syntax'
        'solarized-light-syntax'
      ]
      themeNames = _.intersection(themeNames, builtInThemeNames)
      if themeNames.length is 0
        themeNames = ['atom-dark-syntax', 'atom-dark-ui']
      else if themeNames.length is 1
        if _.endsWith(themeNames[0], '-ui')
          themeNames.unshift('atom-dark-syntax')
        else
          themeNames.push('atom-dark-ui')

    # Reverse so the first (top) theme is loaded after the others. We want
    # the first/top theme to override later themes in the stack.
    themeNames.reverse()

  ###
  Section: Private
  ###

  # Resolve and apply the stylesheet specified by the path.
  #
  # This supports both CSS and Less stylsheets.
  #
  # * `stylesheetPath` A {String} path to the stylesheet that can be an absolute
  #   path or a relative path that will be resolved against the load path.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the
  # required stylesheet.
  requireStylesheet: (stylesheetPath) ->
    if fullPath = @resolveStylesheet(stylesheetPath)
      content = @loadStylesheet(fullPath)
      @applyStylesheet(fullPath, content)
    else
      throw new Error("Could not find a file at path '#{stylesheetPath}'")

  unwatchUserStylesheet: ->
    @userStylsheetSubscriptions?.dispose()
    @userStylsheetSubscriptions = null
    @userStylesheetFile = null
    @userStyleSheetDisposable?.dispose()
    @userStyleSheetDisposable = null

  loadUserStylesheet: ->
    @unwatchUserStylesheet()

    userStylesheetPath = @styleManager.getUserStyleSheetPath()
    return unless fs.isFileSync(userStylesheetPath)

    try
      @userStylesheetFile = new File(userStylesheetPath)
      @userStylsheetSubscriptions = new CompositeDisposable()
      reloadStylesheet = => @loadUserStylesheet()
      @userStylsheetSubscriptions.add(@userStylesheetFile.onDidChange(reloadStylesheet))
      @userStylsheetSubscriptions.add(@userStylesheetFile.onDidRename(reloadStylesheet))
      @userStylsheetSubscriptions.add(@userStylesheetFile.onDidDelete(reloadStylesheet))
    catch error
      message = """
        Unable to watch path: `#{path.basename(userStylesheetPath)}`. Make sure
        you have permissions to `#{userStylesheetPath}`.

        On linux there are currently problems with watch sizes. See
        [this document][watches] for more info.
        [watches]:https://github.com/atom/atom/blob/master/docs/build-instructions/linux.md#typeerror-unable-to-watch-path
      """
      @notificationManager.addError(message, dismissable: true)

    try
      userStylesheetContents = @loadStylesheet(userStylesheetPath, true)
    catch
      return

    @userStyleSheetDisposable = @styleManager.addStyleSheet(userStylesheetContents, sourcePath: userStylesheetPath, priority: 2)

  loadBaseStylesheets: ->
    @reloadBaseStylesheets()

  reloadBaseStylesheets: ->
    @requireStylesheet('../static/atom')
    if nativeStylesheetPath = fs.resolveOnLoadPath(process.platform, ['css', 'less'])
      @requireStylesheet(nativeStylesheetPath)

  stylesheetElementForId: (id) ->
    escapedId = id.replace(/\\/g, '\\\\')
    document.head.querySelector("atom-styles style[source-path=\"#{escapedId}\"]")

  resolveStylesheet: (stylesheetPath) ->
    if path.extname(stylesheetPath).length > 0
      fs.resolveOnLoadPath(stylesheetPath)
    else
      fs.resolveOnLoadPath(stylesheetPath, ['css', 'less'])

  loadStylesheet: (stylesheetPath, importFallbackVariables) ->
    if path.extname(stylesheetPath) is '.less'
      @loadLessStylesheet(stylesheetPath, importFallbackVariables)
    else
      fs.readFileSync(stylesheetPath, 'utf8')

  loadLessStylesheet: (lessStylesheetPath, importFallbackVariables=false) ->
    unless @lessCache?
      LessCompileCache = require './less-compile-cache'
      @lessCache = new LessCompileCache({@resourcePath, importPaths: @getImportPaths()})

    try
      if importFallbackVariables
        baseVarImports = """
        @import "variables/ui-variables";
        @import "variables/syntax-variables";
        """
        less = fs.readFileSync(lessStylesheetPath, 'utf8')
        @lessCache.cssForFile(lessStylesheetPath, [baseVarImports, less].join('\n'))
      else
        @lessCache.read(lessStylesheetPath)
    catch error
      error.less = true
      if error.line?
        # Adjust line numbers for import fallbacks
        error.line -= 2 if importFallbackVariables

        message = "Error compiling Less stylesheet: `#{lessStylesheetPath}`"
        detail = """
          Line number: #{error.line}
          #{error.message}
        """
      else
        message = "Error loading Less stylesheet: `#{lessStylesheetPath}`"
        detail = error.message

      @notificationManager.addError(message, {detail, dismissable: true})
      throw error

  removeStylesheet: (stylesheetPath) ->
    @styleSheetDisposablesBySourcePath[stylesheetPath]?.dispose()

  applyStylesheet: (path, text) ->
    @styleSheetDisposablesBySourcePath[path] = @styleManager.addStyleSheet(text, sourcePath: path)

  activateThemes: ->
    new Promise (resolve) =>
      # @config.observe runs the callback once, then on subsequent changes.
      @config.observe 'core.themes', =>
        @deactivateThemes()

        @warnForNonExistentThemes()

        @refreshLessCache() # Update cache for packages in core.themes config

        promises = []
        for themeName in @getEnabledThemeNames()
          if @packageManager.resolvePackagePath(themeName)
            promises.push(@packageManager.activatePackage(themeName))
          else
            console.warn("Failed to activate theme '#{themeName}' because it isn't installed.")

        Promise.all(promises).then =>
          @addActiveThemeClasses()
          @refreshLessCache() # Update cache again now that @getActiveThemes() is populated
          @loadUserStylesheet()
          @reloadBaseStylesheets()
          @initialLoadComplete = true
          @emitter.emit 'did-change-active-themes'
          resolve()

  deactivateThemes: ->
    @removeActiveThemeClasses()
    @unwatchUserStylesheet()
    @packageManager.deactivatePackage(pack.name) for pack in @getActiveThemes()
    null

  isInitialLoadComplete: -> @initialLoadComplete

  addActiveThemeClasses: ->
    if workspaceElement = @viewRegistry.getView(@workspace)
      for pack in @getActiveThemes()
        workspaceElement.classList.add("theme-#{pack.name}")
      return

  removeActiveThemeClasses: ->
    workspaceElement = @viewRegistry.getView(@workspace)
    for pack in @getActiveThemes()
      workspaceElement.classList.remove("theme-#{pack.name}")
    return

  refreshLessCache: ->
    @lessCache?.setImportPaths(@getImportPaths())

  getImportPaths: ->
    activeThemes = @getActiveThemes()
    if activeThemes.length > 0
      themePaths = (theme.getStylesheetsPath() for theme in activeThemes when theme)
    else
      themePaths = []
      for themeName in @getEnabledThemeNames()
        if themePath = @packageManager.resolvePackagePath(themeName)
          deprecatedPath = path.join(themePath, 'stylesheets')
          if fs.isDirectorySync(deprecatedPath)
            themePaths.push(deprecatedPath)
          else
            themePaths.push(path.join(themePath, 'styles'))

    themePaths.filter (themePath) -> fs.isDirectorySync(themePath)
