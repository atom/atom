path = require 'path'

_ = require 'underscore-plus'
EmitterMixin = require('emissary').Emitter
{Emitter, Disposable} = require 'event-kit'
{File} = require 'pathwatcher'
fs = require 'fs-plus'
Q = require 'q'
{deprecate} = require 'grim'

Package = require './package'

# Extended: Handles loading and activating available themes.
#
# An instance of this class is always available as the `atom.themes` global.
module.exports =
class ThemeManager
  EmitterMixin.includeInto(this)

  constructor: ({@packageManager, @resourcePath, @configDirPath, @safeMode}) ->
    @emitter = new Emitter
    @lessCache = null
    @initialLoadComplete = false
    @packageManager.registerPackageActivator(this, ['theme'])

  ###
  Section: Event Subscription
  ###

  # Essential: Invoke `callback` when all styles have been reloaded.
  #
  # * `callback` {Function}
  onDidReloadAll: (callback) ->
    @emitter.on 'did-reload-all', callback

  # Essential: Invoke `callback` when a stylesheet has been added to the dom.
  #
  # * `callback` {Function}
  #   * `stylesheet` {StyleSheet} the style node
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddStylesheet: (callback) ->
    @emitter.on 'did-add-stylesheet', callback

  # Essential: Invoke `callback` when a stylesheet has been removed from the dom.
  #
  # * `callback` {Function}
  #   * `stylesheet` {StyleSheet} the style node
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidRemoveStylesheet: (callback) ->
    @emitter.on 'did-remove-stylesheet', callback

  # Essential: Invoke `callback` when a stylesheet has been updated.
  #
  # * `callback` {Function}
  #   * `stylesheet` {StyleSheet} the style node
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidUpdateStylesheet: (callback) ->
    @emitter.on 'did-update-stylesheet', callback

  # Essential: Invoke `callback` when any stylesheet has been updated, added, or removed.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeStylesheets: (callback) ->
    @emitter.on 'did-change-stylesheets', callback

  on: (eventName) ->
    switch eventName
      when 'reloaded'
        deprecate 'Use ThemeManager::onDidReloadAll instead'
      when 'stylesheet-added'
        deprecate 'Use ThemeManager::onDidAddStylesheet instead'
      when 'stylesheet-removed'
        deprecate 'Use ThemeManager::onDidRemoveStylesheet instead'
      when 'stylesheet-updated'
        deprecate 'Use ThemeManager::onDidUpdateStylesheet instead'
      when 'stylesheets-changed'
        deprecate 'Use ThemeManager::onDidChangeStylesheets instead'
      else
        deprecate 'ThemeManager::on is deprecated. Use event subscription methods instead.'
    EmitterMixin::on.apply(this, arguments)

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
  getLoadedNames: ->
    theme.name for theme in @getLoadedThemes()

  # Public: Get an array of all the loaded themes.
  getLoadedThemes: ->
    pack for pack in @packageManager.getLoadedPackages() when pack.isTheme()

  ###
  Section: Accessing Active Themes
  ###

  # Public: Get an array of all the active theme names.
  getActiveNames: ->
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
      themeName and typeof themeName is 'string'

    # Use a built-in syntax and UI theme when in safe mode since themes
    # installed to ~/.atom/packages will not be loaded.
    if @safeMode
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

  # Public: Set the list of enabled themes.
  #
  # * `enabledThemeNames` An {Array} of {String} theme names.
  setEnabledThemes: (enabledThemeNames) ->
    atom.config.set('core.themes', enabledThemeNames)

  ###
  Section: Managing Stylesheets
  ###

  # Public: Returns the {String} path to the user's stylesheet under ~/.atom
  getUserStylesheetPath: ->
    stylesheetPath = fs.resolve(path.join(@configDirPath, 'styles'), ['css', 'less'])
    if fs.isFileSync(stylesheetPath)
      stylesheetPath
    else
      path.join(@configDirPath, 'styles.less')

  # Public: Resolve and apply the stylesheet specified by the path.
  #
  # This supports both CSS and Less stylsheets.
  #
  # * `stylesheetPath` A {String} path to the stylesheet that can be an absolute
  #   path or a relative path that will be resolved against the load path.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the
  # required stylesheet.
  requireStylesheet: (stylesheetPath, type='bundled') ->
    if fullPath = @resolveStylesheet(stylesheetPath)
      content = @loadStylesheet(fullPath)
      @applyStylesheet(fullPath, content, type)
      new Disposable => @removeStylesheet(fullPath)
    else
      throw new Error("Could not find a file at path '#{stylesheetPath}'")

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
    userStylesheetContents = @loadStylesheet(userStylesheetPath, true)
    @applyStylesheet(userStylesheetPath, userStylesheetContents, 'userTheme')

  loadBaseStylesheets: ->
    @requireStylesheet('bootstrap/less/bootstrap')
    @reloadBaseStylesheets()

  reloadBaseStylesheets: ->
    @requireStylesheet('../static/atom')
    if nativeStylesheetPath = fs.resolveOnLoadPath(process.platform, ['css', 'less'])
      @requireStylesheet(nativeStylesheetPath)

  stylesheetElementForId: (id) ->
    document.head.querySelector("""style[id="#{id}"]""")

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
      console.error """
        Error compiling Less stylesheet: #{lessStylesheetPath}
        Line number: #{error.line}
        #{error.message}
      """

  removeStylesheet: (stylesheetPath) ->
    fullPath = @resolveStylesheet(stylesheetPath) ? stylesheetPath
    element = @stylesheetElementForId(@stringToId(fullPath))
    if element?
      {sheet} = element
      element.remove()
      @emit 'stylesheet-removed', sheet
      @emitter.emit 'did-remove-stylesheet', sheet
      @emit 'stylesheets-changed'
      @emitter.emit 'did-change-stylesheets'

  applyStylesheet: (path, text, type='bundled') ->
    styleId = @stringToId(path)
    styleElement = @stylesheetElementForId(styleId)

    if styleElement?
      @emit 'stylesheet-removed', styleElement.sheet
      @emitter.emit 'did-remove-stylesheet', styleElement.sheet
      styleElement.textContent = text
    else
      styleElement = document.createElement('style')
      styleElement.setAttribute('class', type)
      styleElement.setAttribute('id', styleId)
      styleElement.textContent = text

      elementToInsertBefore = _.last(document.head.querySelectorAll("style.#{type}"))?.nextElementSibling
      if elementToInsertBefore?
        document.head.insertBefore(styleElement, elementToInsertBefore)
      else
        document.head.appendChild(styleElement)

    @emit 'stylesheet-added', styleElement.sheet
    @emitter.emit 'did-add-stylesheet', styleElement.sheet
    @emit 'stylesheets-changed'
    @emitter.emit 'did-change-stylesheets'

  ###
  Section: Private
  ###

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
        @emit 'reloaded'
        @emitter.emit 'did-reload-all'
        deferred.resolve()

    deferred.promise

  deactivateThemes: ->
    @removeActiveThemeClasses()
    @unwatchUserStylesheet()
    @packageManager.deactivatePackage(pack.name) for pack in @getActiveThemes()
    null

  isInitialLoadComplete: -> @initialLoadComplete

  addActiveThemeClasses: ->
    for pack in @getActiveThemes()
      atom.workspaceView?[0]?.classList.add("theme-#{pack.name}")
    return

  removeActiveThemeClasses: ->
    for pack in @getActiveThemes()
      atom.workspaceView?[0]?.classList.remove("theme-#{pack.name}")
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
          themePaths.push(path.join(themePath, Package.stylesheetsDir))

    themePaths.filter (themePath) -> fs.isDirectorySync(themePath)

  updateGlobalEditorStyle: (property, value) ->
    unless styleNode = @stylesheetElementForId('global-editor-styles')
      @applyStylesheet('global-editor-styles', 'atom-text-editor {}')
      styleNode = @stylesheetElementForId('global-editor-styles')

    {sheet} = styleNode
    editorRule = sheet.cssRules[0]
    editorRule.style[property] = value

    @emit 'stylesheet-updated', sheet
    @emitter.emit 'did-update-stylesheet', sheet
    @emit 'stylesheets-changed'
    @emitter.emit 'did-change-stylesheets'
