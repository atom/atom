AtomWindow = require './atom-window'
BrowserWindow = require 'browser-window'
Menu = require 'menu'
autoUpdater = require 'auto-updater'
app = require 'app'
ipc = require 'ipc'
dialog = require 'dialog'
fs = require 'fs'
path = require 'path'
net = require 'net'
url = require 'url'
_ = require 'underscore'

socketPath = '/tmp/atom.sock'

module.exports =
class AtomApplication
  @open: (options) ->
    createAtomApplication = -> new AtomApplication(options)

    # FIXME: Sometimes when socketPath doesn't exist, net.connect would strangely
    # take a few seconds to trigger 'error' event, it could be a bug of node
    # or atom-shell, before it's fixed we check the existence of socketPath to
    # speedup startup.
    if not fs.existsSync socketPath
      createAtomApplication()
      return

    client = net.connect {path: socketPath}, ->
      client.write JSON.stringify(options), ->
        client.end()
        app.terminate()

    client.on 'error', createAtomApplication

  windows: null
  menu: null
  resourcePath: null
  version: null

  constructor: ({@resourcePath, pathsToOpen, urlsToOpen, @version, test, pidToKillWhenClosed, devMode, newWindow}) ->
    global.atomApplication = this

    @pidsToOpenWindows = {}
    @pathsToOpen ?= []
    @windows = []

    @createDefaultMenu()
    @listenForArgumentsFromNewProcess()
    @setupJavaScriptArguments()
    @handleEvents()
    @checkForUpdates()

    if test
      @runSpecs({exitWhenDone: true, @resourcePath})
    else if pathsToOpen.length > 0
      @openPaths({pathsToOpen, pidToKillWhenClosed, newWindow, devMode})
    else if urlsToOpen.length > 0
      @openUrl({urlToOpen, devMode}) for urlToOpen in urlsToOpen
    else      
      @openPath({pidToKillWhenClosed, newWindow, devMode}) # Always open a editor window if this is the first instance of Atom.

  removeWindow: (window) ->
    @windows.splice @windows.indexOf(window), 1
    @enableWindowMenuItems(false) if @windows.length == 0

  addWindow: (window) ->
    @windows.push window
    @enableWindowMenuItems(true) == 0

  createDefaultMenu: ->
    @menu = Menu.buildFromTemplate [
      label: "Atom"
      submenu: [
          { label: 'Reload', accelerator: 'Command+R', click: -> @focusedWindow()?.reload() }
          { label: 'Close Window', accelerator: 'Command+Shift+W', click: -> @focusedWindow()?.close() }
          { label: 'Toggle Dev Tools', accelerator: 'Command+Alt+I', click: -> @focusedWindow()?.toggleDevTools() }
          { label: 'Quit', accelerator: 'Command+Q', click: -> app.quit }
      ]
    ]

    Menu.setApplicationMenu @menu

  listenForArgumentsFromNewProcess: ->
    fs.unlinkSync socketPath if fs.existsSync(socketPath)
    server = net.createServer (connection) =>
      connection.on 'data', (data) =>
        {pathsToOpen, pidToKillWhenClosed, newWindow} = JSON.parse(data)
        @openPaths({pathsToOpen, pidToKillWhenClosed, newWindow})

    server.listen socketPath
    server.on 'error', (error) -> console.error 'Application server failed', error

  setupJavaScriptArguments: ->
    app.commandLine.appendSwitch 'js-flags', '--harmony_collections'

  checkForUpdates: ->
    versionIsSha = /\w{7}/.test @version

    if versionIsSha
      autoUpdater.setAutomaticallyDownloadsUpdates false
      autoUpdater.setAutomaticallyChecksForUpdates false
    else
      autoUpdater.setAutomaticallyDownloadsUpdates true
      autoUpdater.setAutomaticallyChecksForUpdates true
      autoUpdater.checkForUpdatesInBackground()

  handleEvents: ->
    app.on 'will-quit', =>
      fs.unlinkSync socketPath if fs.existsSync(socketPath) # Clean the socket file when quit normally.

    app.on 'open-file', (event, pathToOpen) =>
      event.preventDefault()
      @openPath({pathToOpen})

    app.on 'open-url', (event, urlToOpen) =>
      event.preventDefault()
      @openUrl(urlToOpen)

    autoUpdater.on 'ready-for-update-on-quit', (event, version, quitAndUpdateCallback) =>
      event.preventDefault()
      updateMenuItem = _.find @allMenuItems(), (menuItem) -> menuItem.label == 'Install update'
      if updateMenuItem
        updateMenuItem.visible = true
        updateMenuItem.click = quitAndUpdateCallback

    ipc.on 'open', (processId, routingId, pathsToOpen) =>
      if pathsToOpen?.length > 0
        @openPaths({pathsToOpen})
      else
        @promptForPath()

    ipc.on 'get-version', (event) =>
      event.result = @version

    ipc.once 'build-menu-bar-from-template', (processId, routingId, menuTemplate) =>
      @buildMenu(menuTemplate)

  buildMenu: (menuTemplate) ->
    @parseMenuTemplate(menuTemplate)
    @menu = Menu.buildFromTemplate(menuTemplate)
    Menu.setApplicationMenu(@menu)
    @enableWindowMenuItems(true)

  allMenuItems: (menu=@menu) ->
    return [] unless menu?

    menuItems = []
    for index, item of menu.items or {}
      menuItems.push(item)
      menuItems = menuItems.concat(@allMenuItems(item.submenu)) if item.submenu

    menuItems

  enableWindowMenuItems: (enable) ->
    for menuItem in @allMenuItems()
      menuItem.enabled = enable if menuItem.metadata?['windowSpecificItem']

  parseMenuTemplate: (menuTemplate) ->
    menuTemplate.forEach (menuItem) =>
      menuItem.metadata = {}
      if menuItem.command
        menuItem.click = => @sendCommand(menuItem.command)
        menuItem.metadata['windowSpecificItem'] = true unless /^application:/.test(menuItem.command)
      if menuItem.submenu
        @parseMenuTemplate(menuItem.submenu)

  sendCommand: (command, args...) ->
    return if @interceptApplicationCommands(command)
    return if @interceptAlternativeWindowCommands(command)
    @focusedWindow()?.sendCommand(command, args...)

  interceptApplicationCommands: (command) ->
    switch command
      when 'application:about' then Menu.sendActionToFirstResponder('orderFrontStandardAboutPanel:')
      when 'application:run-specs' then @runSpecs(exitWhenDone: false, resourcePath: global.devResourcePath)
      when 'application:show-settings' then (@focusedWindow() ? this).openPath("atom://config")
      when 'application:quit' then app.quit()
      when 'application:hide' then Menu.sendActionToFirstResponder('hide:')
      when 'application:hide-other-applications' then Menu.sendActionToFirstResponder('hideOtherApplications:')
      when 'application:unhide-all-applications' then Menu.sendActionToFirstResponder('unhideAllApplications:')
      when 'application:new-window' then  @openPath()
      when 'application:new-file' then (@focusedWindow() ? this).openPath()
      when 'application:open' then @promptForPath()
      when 'application:open-dev' then @promptForPath(devMode: true)
      when 'application:minimize' then Menu.sendActionToFirstResponder('performMiniaturize:')
      when 'application:zoom' then Menu.sendActionToFirstResponder('zoom:')
      when 'application:bring-all-windows-to-front' then Menu.sendActionToFirstResponder('arrangeInFront:')
      else
        return false

    true

  interceptAlternativeWindowCommands: (command) ->
    return if not @focusedWindow()?.isSpecWindow() and @focusedWindow()?.isWebViewFocused()

    switch command
      when 'core:undo' then Menu.sendActionToFirstResponder('undo:')
      when 'core:redo' then Menu.sendActionToFirstResponder('redo:')
      when 'core:copy' then Menu.sendActionToFirstResponder('copy:')
      when 'core:cut' then Menu.sendActionToFirstResponder('cut:')
      when 'core:paste' then Menu.sendActionToFirstResponder('paste:')
      when 'core:select-all' then Menu.sendActionToFirstResponder('selectAll:')
      when 'command-panel:find-in-file' then Menu.sendActionToFirstResponder('performTextFinderAction:')
      when 'window:reload' then @focusedWindow()?.reload()
      when 'window:toggle-dev-tools' then @focusedWindow()?.toggleDevTools()
      when 'window:close' then @focusedWindow()?.close()
      else return false
    return true

  windowForPath: (pathToOpen) ->
    for atomWindow in @windows
      return atomWindow if atomWindow.containsPath(pathToOpen)

  focusedWindow: ->
    _.find @windows, (atomWindow) -> atomWindow.isFocused()

  openPaths: ({pathsToOpen, pidToKillWhenClosed, newWindow, devMode}) ->
    @openPath({pathToOpen, pidToKillWhenClosed, newWindow, devMode}) for pathToOpen in pathsToOpen ? []

  openPath: ({pathToOpen, pidToKillWhenClosed, newWindow, devMode}={}) ->
    unless devMode
      existingWindow = @windowForPath(pathToOpen) unless pidToKillWhenClosed or newWindow
    if existingWindow
      openedWindow = existingWindow
      openedWindow.openPath(pathToOpen)
    else
      bootstrapScript = 'window-bootstrap'
      if devMode
        resourcePath = global.devResourcePath
      else
        resourcePath = @resourcePath
      openedWindow = new AtomWindow({pathToOpen, bootstrapScript, resourcePath, devMode})

    if pidToKillWhenClosed?
      @pidsToOpenWindows[pidToKillWhenClosed] = openedWindow

    openedWindow.browserWindow.on 'destroyed', =>
      for pid, trackedWindow of @pidsToOpenWindows when trackedWindow is openedWindow
        try
          process.kill(pid)
        catch error
          if error.code isnt 'ESRCH'
            console.log("Killing process #{pid} failed: #{error.code}")
        delete @pidsToOpenWindows[pid]

    openedWindow
    
  openUrl: ({urlToOpen, devMode}) ->
    parsedUrl = url.parse(urlToOpen)
    if parsedUrl.host is 'session'
      sessionId = parsedUrl.path.split('/')[1]
      console.log "Joining session #{sessionId}"
      if sessionId
        bootstrapScript = 'collaboration/lib/bootstrap'
        new AtomWindow({bootstrapScript, @resourcePath, sessionId, devMode})
    else
      console.log "Opening unknown url #{urlToOpen}"

  runSpecs: ({exitWhenDone, resourcePath}) ->
    if resourcePath isnt @resourcePath and not fs.existsSync(resourcePath)
      resourcePath = @resourcePath

    bootstrapScript = 'spec-bootstrap'
    isSpec = true
    devMode = true
    new AtomWindow({bootstrapScript, resourcePath, exitWhenDone, isSpec, devMode})

  promptForPath: ({devMode}={}) ->
    pathsToOpen = dialog.showOpenDialog title: 'Open', properties: ['openFile', 'openDirectory', 'multiSelections', 'createDirectory']
    @openPaths({pathsToOpen, devMode})
