crypto = require 'crypto'
ipc = require 'ipc'
keytar = require 'keytar'
os = require 'os'
path = require 'path'
remote = require 'remote'
shell = require 'shell'
dialog = remote.require 'dialog'
app = remote.require 'app'

_ = require 'underscore-plus'
{Document} = require 'telepath'
fs = require 'fs-plus'
{Subscriber} = require 'emissary'

{$} = require './space-pen-extensions'
DeserializerManager = require './deserializer-manager'
Package = require './package'
SiteShim = require './site-shim'
WindowEventHandler = require './window-event-handler'

# Public: Atom global for dealing with packages, themes, menus, and the window.
#
# An instance of this class is always available as the `atom` global.
#
# ## Useful properties available:
#
#  * `atom.config`      - A {Config} instance
#  * `atom.contextMenu` - A {ContextMenuManager} instance
#  * `atom.keymap`      - A {Keymap} instance
#  * `atom.menu`        - A {MenuManager} instance
#  * `atom.workspaceView`    - A {WorkspaceView} instance
#  * `atom.packages`    - A {PackageManager} instance
#  * `atom.pasteboard`  - A {Pasteboard} instance
#  * `atom.project`     - A {Project} instance
#  * `atom.syntax`      - A {Syntax} instance
#  * `atom.themes`      - A {ThemeManager} instance
module.exports =
class Atom
  Subscriber.includeInto(this)

  # Private:
  constructor: ->
    @workspaceViewParentSelector = 'body'
    @deserializers = new DeserializerManager()

  # Private: Initialize all the properties in this object.
  initialize: ->
    @unsubscribe()
    @setBodyPlatformClass()

    {devMode, resourcePath} = atom.getLoadSettings()
    configDirPath = @getConfigDirPath()

    Config = require './config'
    Keymap = require './keymap'
    PackageManager = require './package-manager'
    Pasteboard = require './pasteboard'
    Syntax = require './syntax'
    ThemeManager = require './theme-manager'
    ContextMenuManager = require './context-menu-manager'
    MenuManager = require './menu-manager'

    @config = new Config({configDirPath, resourcePath})
    @keymap = new Keymap({configDirPath, resourcePath})
    @packages = new PackageManager({devMode, configDirPath, resourcePath})

    @subscribe @packages, 'activated', => @watchThemes()
    @themes = new ThemeManager({packageManager: @packages, configDirPath, resourcePath})
    @contextMenu = new ContextMenuManager(devMode)
    @menu = new MenuManager({resourcePath})
    @pasteboard = new Pasteboard()
    @syntax = @deserializers.deserialize(@getWindowState('syntax')) ? new Syntax()

  # Private: This method is called in any window needing a general environment, including specs
  setUpEnvironment: (@windowMode) ->
    @initialize()

  # Private:
  setBodyPlatformClass: ->
    document.body.classList.add("platform-#{process.platform}")

  # Public: Create a new telepath model. This won't be needed when Atom is itself
  # a telepath model.
  create: (model) ->
    @site.createDocument(model)

  # Public: Get the current window
  getCurrentWindow: ->
    remote.getCurrentWindow()

  # Public: Get the dimensions of this window.
  #
  # Returns an object with x, y, width, and height keys.
  getDimensions: ->
    browserWindow = @getCurrentWindow()
    [x, y] = browserWindow.getPosition()
    [width, height] = browserWindow.getSize()
    {x, y, width, height}

  # Public: Set the dimensions of the window.
  #
  # The window will be centered if either the x or y coordinate is not set
  # in the dimensions parameter.
  #
  # * dimensions:
  #    + x:
  #      The new x coordinate.
  #    + y:
  #      The new y coordinate.
  #    + width:
  #      The new width.
  #    + height:
  #      The new height.
  setDimensions: ({x, y, width, height}) ->
    browserWindow = @getCurrentWindow()
    browserWindow.setSize(width, height)
    if x? and y?
      browserWindow.setPosition(x, y)
    else
      browserWindow.center()

  # Private:
  restoreDimensions: ->
    dimensions = @getWindowState().getObject('dimensions')
    unless dimensions?.width and dimensions?.height
      {height, width} = @getLoadSettings().initialSize ? {}
      height ?= screen.availHeight
      width ?= Math.min(screen.availWidth, 1024)
      dimensions = {width, height}
    @setDimensions(dimensions)

  # Public: Get the load settings for the current window.
  #
  # Returns an object containing all the load setting key/value pairs.
  getLoadSettings: ->
    @loadSettings ?= _.deepClone(@getCurrentWindow().loadSettings)
    _.deepClone(@loadSettings)

  # Private:
  deserializeProject: ->
    Project = require './project'
    @project = @getWindowState('project')
    unless @project instanceof Project
      @project = new Project(path: @getLoadSettings().initialPath)
      @setWindowState('project', @project)

  # Private:
  deserializeWorkspaceView: ->
    WorkspaceView = require './workspace-view'
    state = @getWindowState()
    @workspaceView = @deserializers.deserialize(state.get('workspaceView'))
    unless @workspaceView?
      @workspaceView = new WorkspaceView()
      state.set('workspaceView', @workspaceView.getState())
    $(@workspaceViewParentSelector).append(@workspaceView)

  # Private:
  deserializePackageStates: ->
    state = @getWindowState()
    @packages.packageStates = state.getObject('packageStates') ? {}
    state.remove('packageStates')

  # Private:
  deserializeEditorWindow: ->
    @deserializePackageStates()
    @deserializeProject()
    @deserializeWorkspaceView()

  # Private: This method is only called when opening a real application window
  startEditorWindow: ->
    if process.platform is 'darwin'
      CommandInstaller = require './command-installer'
      CommandInstaller.installAtomCommand()
      CommandInstaller.installApmCommand()

    @windowEventHandler = new WindowEventHandler
    @restoreDimensions()
    @config.load()
    @config.setDefaults('core', require('./workspace-view').configDefaults)
    @config.setDefaults('editor', require('./editor-view').configDefaults)
    @keymap.loadBundledKeymaps()
    @themes.loadBaseStylesheets()
    @packages.loadPackages()
    @deserializeEditorWindow()
    @packages.activate()
    @keymap.loadUserKeymap()
    @requireUserInitScript()
    @menu.update()

    $(window).on 'unload', =>
      $(document.body).hide()
      @unloadEditorWindow()
      false

    @displayWindow()

  # Private:
  unloadEditorWindow: ->
    return if not @project and not @workspaceView

    windowState = @getWindowState()
    windowState.set('project', @project)
    windowState.set('syntax', @syntax.serialize())
    windowState.set('workspaceView', @workspaceView.serialize())
    @packages.deactivatePackages()
    windowState.set('packageStates', @packages.packageStates)
    @saveWindowState()
    @workspaceView.remove()
    @project.destroy()
    @windowEventHandler?.unsubscribe()
    @windowState = null

  # Set up the default event handlers and menus for a non-editor window.
  #
  # This can be used by packages to have a minimum level of keybindings and
  # menus available when not using the standard editor window.
  #
  # This should only be called after setUpEnvironment() has been called.
  setUpDefaultEvents: ->
    @windowEventHandler = new WindowEventHandler
    @keymap.loadBundledKeymaps()
    @menu.update()

  # Private:
  loadThemes: ->
    @themes.load()

  # Private:
  watchThemes: ->
    @themes.on 'reloaded', =>
      # Only reload stylesheets from non-theme packages
      for pack in @packages.getActivePackages() when pack.getType() isnt 'theme'
        pack.reloadStylesheets?()
      null

  # Public: Open a new Atom window using the given options.
  #
  # Calling this method without an options parameter will open a prompt to pick
  # a file/folder to open in the new window.
  #
  # * options
  #   * pathsToOpen: A string array of paths to open
  open: (options) ->
    ipc.sendChannel('open', options)

  # Public: Open a confirm dialog.
  #
  # ## Example:
  # ```coffeescript
  #   atom.confirm
  #      message: 'How you feeling?'
  #      detailedMessage: 'Be honest.'
  #      buttons:
  #        Good: -> window.alert('good to hear')
  #        Bad: ->  window.alert('bummer')
  # ```
  #
  # * options:
  #    + message: The string message to display.
  #    + detailedMessage: The string detailed message to display.
  #    + buttons: Either an array of strings or an object where the values
  #      are callbacks to invoke when clicked.
  #
  # Returns the chosen index if buttons was an array or the return of the
  # callback if buttons was an object.
  confirm: ({message, detailedMessage, buttons}={}) ->
    buttons ?= {}
    if _.isArray(buttons)
      buttonLabels = buttons
    else
      buttonLabels = Object.keys(buttons)

    chosen = dialog.showMessageBox @getCurrentWindow(),
      type: 'info'
      message: message
      detail: detailedMessage
      buttons: buttonLabels

    if _.isArray(buttons)
      chosen
    else
      callback = buttons[buttonLabels[chosen]]
      callback?()

  # Private:
  showSaveDialog: (callback) ->
    callback(showSaveDialogSync())

  # Private:
  showSaveDialogSync: (defaultPath) ->
    defaultPath ?= @project?.getPath()
    currentWindow = @getCurrentWindow()
    dialog.showSaveDialog currentWindow, {title: 'Save File', defaultPath}

  # Public: Open the dev tools for the current window.
  openDevTools: ->
    @getCurrentWindow().openDevTools()

  # Public: Toggle the visibility of the dev tools for the current window.
  toggleDevTools: ->
    @getCurrentWindow().toggleDevTools()

  # Public: Reload the current window.
  reload: ->
    @getCurrentWindow().restart()

  # Public: Focus the current window.
  focus: ->
    @getCurrentWindow().focus()
    $(window).focus()

  # Public: Show the current window.
  show: ->
    @getCurrentWindow().show()

  # Public: Hide the current window.
  hide: ->
    @getCurrentWindow().hide()

  # Private: Schedule the window to be shown and focused on the next tick.
  #
  # This is done in a next tick to prevent a white flicker from occurring
  # if called synchronously.
  displayWindow: ->
    setImmediate =>
      @show()
      @focus()
      @setFullScreen(true) if @workspaceView.getState().get('fullScreen')

  # Public: Close the current window.
  close: ->
    @getCurrentWindow().close()

  # Private:
  exit: (status) -> app.exit(status)

  # Public: Is the current window in development mode?
  inDevMode: ->
    @getLoadSettings().devMode

  # Public: Is the current window running specs?
  inSpecMode: ->
    @getLoadSettings().isSpec

  # Public: Toggle the full screen state of the current window.
  toggleFullScreen: ->
    @setFullScreen(!@isFullScreen())

  # Public: Set the full screen state of the current window.
  setFullScreen: (fullScreen=false) ->
    @getCurrentWindow().setFullScreen(fullScreen)

  # Public: Is the current window in full screen mode?
  isFullScreen: ->
    @getCurrentWindow().isFullScreen()

  # Public: Get the version of the Atom application.
  getVersion: ->
    app.getVersion()

  getGitHubAuthTokenName: ->
    'Atom GitHub API Token'

  # Public: Set the the github token in the keychain
  setGitHubAuthToken: (token) ->
    keytar.replacePassword(@getGitHubAuthTokenName(), 'github', token)

  # Public: Get the github token from the keychain
  getGitHubAuthToken: ->
    keytar.getPassword(@getGitHubAuthTokenName(), 'github')

  # Public: Get the directory path to Atom's configuration area.
  #
  # Returns the absolute path to ~/.atom
  getConfigDirPath: ->
    @configDirPath ?= fs.absolute('~/.atom')

  # Public: Get the directory path to Atom's storage area.
  #
  # Returns the absoluste path to ~/.atom/storage
  getStorageDirPath: ->
    @storageDirPath ?= path.join(@getConfigDirPath(), 'storage')

  # Private:
  getWindowStatePath: ->
    switch @windowMode
      when 'spec'
        filename = @windowMode
      when 'editor'
        {initialPath} = @getLoadSettings()
        if initialPath
          sha1 = crypto.createHash('sha1').update(initialPath).digest('hex')
          filename = "editor-#{sha1}"

    if filename
      path.join(@getStorageDirPath(), filename)
    else
      null

  # Public: Set the window state of the given keypath to the value.
  setWindowState: (keyPath, value) ->
    windowState = @getWindowState()
    windowState.set(keyPath, value)
    windowState

  # Private
  loadSerializedWindowState: ->
    if windowStatePath = @getWindowStatePath()
      if fs.existsSync(windowStatePath)
        try
          documentStateJson  = fs.readFileSync(windowStatePath, 'utf8')
        catch error
          console.warn "Error reading window state: #{windowStatePath}", error.stack, error
    else
      documentStateJson = @getLoadSettings().windowState

    try
      documentState = JSON.parse(documentStateJson) if documentStateJson
    catch error
      console.warn "Error parsing window state: #{windowStatePath}", error.stack, error

  # Private:
  loadWindowState: ->
    serializedWindowState = @loadSerializedWindowState()
    doc = Document.deserialize(serializedWindowState) if serializedWindowState?
    doc ?= Document.create()
    doc.registerModelClasses(require('./text-buffer'), require('./project'), require('./tokenized-buffer'))
    # TODO: Remove this when everything is using telepath models
    if @site?
      @site.setRootDocument(doc)
    else
      @site = new SiteShim(doc)
    doc

  # Private:
  saveWindowState: ->
    windowState = @getWindowState()
    if windowStatePath = @getWindowStatePath()
      windowState.saveSync(windowStatePath)
    else
      @getCurrentWindow().loadSettings.windowState = JSON.stringify(windowState.serializeForPersistence())

  # Public: Get the window state for the key path.
  getWindowState: (keyPath) ->
    @windowState ?= @loadWindowState()
    if keyPath
      @windowState.get(keyPath)
    else
      @windowState

  # Private: Returns a replicated copy of the current state.
  replicate: ->
    @getWindowState().replicate()

  # Private:
  crashMainProcess: ->
    remote.process.crash()

  # Private:
  crashRenderProcess: ->
    process.crash()

  # Public: Visually and audibly trigger a beep.
  beep: ->
    shell.beep() if @config.get('core.audioBeep')
    @workspaceView.trigger 'beep'

  # Private:
  requireUserInitScript: ->
    if userInitScriptPath = fs.resolve(@getConfigDirPath(), 'user', ['js', 'coffee'])
      try
        require userInitScriptPath
      catch error
        console.error "Failed to load `#{userInitScriptPath}`", error.stack, error

  # Public: Require the module with the given globals.
  #
  # The globals will be set on the `window` object and removed after the
  # require completes.
  requireWithGlobals: (id, globals={}) ->
    existingGlobals = {}
    for key, value of globals
      existingGlobals[key] = window[key]
      window[key] = value

    require(id)

    for key, value of existingGlobals
      if value is undefined
        delete window[key]
      else
        window[key] = value
