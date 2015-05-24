path = require 'path'
_ = require 'underscore-plus'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
{File} = require 'pathwatcher'
fs = require 'fs-plus'
Q = require 'q'
Grim = require 'grim'

# Extended: Handles loading and activating available themes.
#
# An instance of this class is always available as the `atom.themes` global.
module.exports =
class ThemeManager
  constructor: ({@packageManager, @resourcePath, @configDirPath, @safeMode}) ->
    @emitter = new Emitter
    @styleSheetDisposablesBySourcePath = {}
    @lessCache = null
    @initialLoadComplete = false
    @packageManager.registerPackageActivator(this, ['theme'])
    @sheetsByStyleElement = new WeakMap

    stylesElement = document.head.querySelector('atom-styles')
    stylesElement.onDidAddStyleElement @styleElementAdded.bind(this)
    stylesElement.onDidRemoveStyleElement @styleElementRemoved.bind(this)
    stylesElement.onDidUpdateStyleElement @styleElementUpdated.bind(this)

  styleElementAdded: (styleElement) ->
    {sheet} = styleElement
    @sheetsByStyleElement.set(styleElement, sheet)
    @emit 'stylesheet-added', sheet if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-add-stylesheet', sheet
    @emit 'stylesheets-changed' if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-change-stylesheets'

  styleElementRemoved: (styleElement) ->
    sheet = @sheetsByStyleElement.get(styleElement)
    @emit 'stylesheet-removed', sheet if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-remove-stylesheet', sheet
    @emit 'stylesheets-changed' if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-change-stylesheets'

  styleElementUpdated: ({sheet}) ->
    @emit 'stylesheet-removed', sheet if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-remove-stylesheet', sheet
    @emit 'stylesheet-added', sheet if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-add-stylesheet', sheet
    @emit 'stylesheets-changed' if Grim.includeDeprecatedAPIs
    @emitter.emit 'did-change-stylesheets'

  ###
  Section: Event Subscription
  ###

  # Essential: Invoke `callback` when style sheet changes associated with
  # updating the list of active themes have completed.
  #
  # * `callback` {Function}
  onDidChangeActiveThemes: (callback) ->
    @emitter.on 'did-change-active-themes', callback
    @emitter.on 'did-reload-all', callback # TODO: Remove once deprecated pre-1.0 APIs are gone

  ###
  Section: Accessing Available Themes
  ###

  getAvailableNames: ->
    # TODO: Maybe should change to list all the available themes out there?
    @getLoadedNames()

  ###
  Section: Accessing Loaded Themes
  ###

  # Public: Get an array of all the loaded theme names.
  getLoadedThemeNames: ->
    theme.name for theme in @getLoadedThemes()

  # Public: Get an array of all the loaded themes.
  getLoadedThemes: ->
    pack for pack in @packageManager.getLoadedPackages() when pack.isTheme()

  ###
  Section: Accessing Active Themes
  ###

  # Public: Get an array of all the active theme names.
  getActiveThemeNames: ->
    theme.name for theme in @getActiveThemes()

  # Public: Get an array of all the active themes.
  getActiveThemes: ->
    pack for pack in @packageManager.getActivePackages() when pack.isTheme()

  activatePackages: -> @activateThemes()

  ###
  Section: Managing Enabled Themes
  ###

  # Public: Get the enabled theme names from the config.
  #
  # Returns an array of theme names in the order that they should be activated.
  getEnabledThemeNames: ->
    themeNames = atom.config.get('core.themes') ? []
    themeNames = [themeNames] unless _.isArray(themeNames)
    themeNames = themeNames.filter (themeName) ->
      if themeName and typeof themeName is 'string'
        return true if atom.packages.resolvePackagePath(themeName)
        console.warn("Enabled theme '#{themeName}' is not installed.")
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

    userStylesheetPath = atom.styles.getUserStyleSheetPath()
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
      atom.notifications.addError(message, dismissable: true)

    try
      userStylesheetContents = @loadStylesheet(userStylesheetPath, true)
    catch
      return

    @userStyleSheetDisposable = atom.styles.addStyleSheet(userStylesheetContents, sourcePath: userStylesheetPath, priority: 2)

  loadBaseStylesheets: ->
    @requireStylesheet('../static/bootstrap')
    @reloadBaseStylesheets()

  reloadBaseStylesheets: ->
    @requireStylesheet('../static/atom')
    if nativeStylesheetPath = fs.resolveOnLoadPath(process.platform, ['css', 'less'])
      @requireStylesheet(nativeStylesheetPath)

  stylesheetElementForId: (id) ->
    document.head.querySelector("atom-styles style[source-path=\"#{id}\"]")

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

      atom.notifications.addError(message, {detail, dismissable: true})
      throw error

  removeStylesheet: (stylesheetPath) ->
    @styleSheetDisposablesBySourcePath[stylesheetPath]?.dispose()

  applyStylesheet: (path, text) ->
    @styleSheetDisposablesBySourcePath[path] = atom.styles.addStyleSheet(text, sourcePath: path)

  stringToId: (string) ->
    string.replace(/\\/g, '/')

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
        @addActiveThemeClasses()
        @refreshLessCache() # Update cache again now that @getActiveThemes() is populated
        @loadUserStylesheet()
        @reloadBaseStylesheets()
        @initialLoadComplete = true
        @emit 'reloaded' if Grim.includeDeprecatedAPIs
        @emitter.emit 'did-change-active-themes'
        deferred.resolve()

    deferred.promise

  deactivateThemes: ->
    @removeActiveThemeClasses()
    @unwatchUserStylesheet()
    @packageManager.deactivatePackage(pack.name) for pack in @getActiveThemes()
    null

  isInitialLoadComplete: -> @initialLoadComplete

  addActiveThemeClasses: ->
    workspaceElement = atom.views.getView(atom.workspace)
    for pack in @getActiveThemes()
      workspaceElement.classList.add("theme-#{pack.name}")
    return

  removeActiveThemeClasses: ->
    workspaceElement = atom.views.getView(atom.workspace)
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

if Grim.includeDeprecatedAPIs
  EmitterMixin = require('emissary').Emitter
  EmitterMixin.includeInto(ThemeManager)

  ThemeManager::on = (eventName) ->
    switch eventName
      when 'reloaded'
        Grim.deprecate 'Use ThemeManager::onDidChangeActiveThemes instead'
      when 'stylesheet-added'
        Grim.deprecate 'Use ThemeManager::onDidAddStylesheet instead'
      when 'stylesheet-removed'
        Grim.deprecate 'Use ThemeManager::onDidRemoveStylesheet instead'
      when 'stylesheet-updated'
        Grim.deprecate 'Use ThemeManager::onDidUpdateStylesheet instead'
      when 'stylesheets-changed'
        Grim.deprecate 'Use ThemeManager::onDidChangeStylesheets instead'
      else
        Grim.deprecate 'ThemeManager::on is deprecated. Use event subscription methods instead.'
    EmitterMixin::on.apply(this, arguments)

  ThemeManager::onDidReloadAll = (callback) ->
    Grim.deprecate("Use `::onDidChangeActiveThemes` instead.")
    @onDidChangeActiveThemes(callback)

  ThemeManager::onDidAddStylesheet = (callback) ->
    Grim.deprecate("Use atom.styles.onDidAddStyleElement instead")
    @emitter.on 'did-add-stylesheet', callback

  ThemeManager::onDidRemoveStylesheet = (callback) ->
    Grim.deprecate("Use atom.styles.onDidRemoveStyleElement instead")
    @emitter.on 'did-remove-stylesheet', callback

  ThemeManager::onDidUpdateStylesheet = (callback) ->
    Grim.deprecate("Use atom.styles.onDidUpdateStyleElement instead")
    @emitter.on 'did-update-stylesheet', callback

  ThemeManager::onDidChangeStylesheets = (callback) ->
    Grim.deprecate("Use atom.styles.onDidAdd/RemoveStyleElement instead")
    @emitter.on 'did-change-stylesheets', callback

  ThemeManager::getUserStylesheetPath = ->
    Grim.deprecate("Call atom.styles.getUserStyleSheetPath() instead")
    atom.styles.getUserStyleSheetPath()

  ThemeManager::getLoadedNames = ->
    Grim.deprecate("Use `::getLoadedThemeNames` instead.")
    @getLoadedThemeNames()

  ThemeManager::getActiveNames = ->
    Grim.deprecate("Use `::getActiveThemeNames` instead.")
    @getActiveThemeNames()

  ThemeManager::setEnabledThemes = (enabledThemeNames) ->
    Grim.deprecate("Use `atom.config.set('core.themes', arrayOfThemeNames)` instead")
    atom.config.set('core.themes', enabledThemeNames)
