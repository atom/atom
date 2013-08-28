ipc = require 'ipc'
Menu = require 'menu'
_ = require 'underscore'

# Private: Used to manage the global application menu.
#
# It's created by {AtomApplication} upon instantiation and used to add, remove
# and maintain the state of all menu items.
module.exports =
class ApplicationMenu
  version: null
  devMode: null
  menu: null

  constructor: (@version, @devMode) ->
    @menu = Menu.buildFromTemplate @getDefaultTemplate()
    Menu.setApplicationMenu @menu

  # Public: Updates the entire menu with the given keybindings.
  #
  # * keystrokesByCommand:
  #   An Object where the keys are commands and the values are Arrays containing
  #   the keystrokes.
  update: (keystrokesByCommand) ->
    template = @getTemplate(keystrokesByCommand)
    @menu = Menu.buildFromTemplate(template)
    Menu.setApplicationMenu(@menu)

  # Private: Flattens the given menu and submenu items into an single Array.
  #
  # * menu:
  #   A complete menu configuration object for atom-shell's menu API.
  #
  # Returns an Array of native menu items.
  allItems: (menu=@menu) ->
    items = []
    for index, item of menu.items or {}
      items.push(item)
      items = items.concat(@allItems(item.submenu)) if item.submenu
    items

  # Public: Used to make all window related menu items are active.
  #
  # * enable:
  #   If true enables all window specific items, if false disables all  window
  #   specific items.
  enableWindowSpecificItems: (enable) ->
    for item in @allItems()
      item.enabled = enable if item.metadata?['windowSpecific']

  # Public: Makes the download menu item visible if available.
  #
  # Note: The update menu item's must match 'Install update' exactly otherwise
  # this function will fail to work.
  #
  # * newVersion:
  #   FIXME: Unused.
  # * quitAndUpdateCallback:
  #   Function to call when the install menu item has been clicked.
  showDownloadUpdateItem: (newVersion, quitAndUpdateCallback) ->
    downloadUpdateItem = _.find @allItems(), (item) -> item.label == 'Install update'
    if downloadUpdateItem
      downloadUpdateItem.visible = true
      downloadUpdateItem.click = quitAndUpdateCallback

  # Private: Default list of menu items.
  #
  # Returns an Array of menu item Objects.
  getDefaultTemplate: ->
    [
      label: "Atom"
      submenu: [
          { label: 'Reload', accelerator: 'Command+R', click: -> @focusedWindow()?.reload() }
          { label: 'Close Window', accelerator: 'Command+Shift+W', click: -> @focusedWindow()?.close() }
          { label: 'Toggle Dev Tools', accelerator: 'Command+Alt+I', click: -> @focusedWindow()?.toggleDevTools() }
          { label: 'Quit', accelerator: 'Command+Q', click: -> app.quit() }
      ]
    ]

  # Private: The complete list of menu items.
  #
  # * keystrokesByCommand:
  #   An Object where the keys are commands and the values are Arrays containing
  #   the keystrokes.
  #
  # Returns a complete menu configuration Object for use with atom-shell's
  #   native menu API.
  getTemplate: (keystrokesByCommand) ->
    atomMenu =
      label: 'Atom'
      submenu: [
        { label: 'About Atom', command: 'application:about' }
        { label: "Version #{@version}", enabled: false }
        { label: "Install update", command: 'application:install-update', visible: false }
        { type: 'separator' }
        { label: 'Preferences...', command: 'application:show-settings' }
        { label: 'Hide Atom', command: 'application:hide' }
        { label: 'Hide Others', command: 'application:hide-other-applications' }
        { label: 'Show All', command: 'application:unhide-all-applications' }
        { type: 'separator' }
        { label: 'Run Atom Specs', command: 'application:run-all-specs' }
        { type: 'separator' }
        { label: 'Quit', command: 'application:quit' }
      ]

    fileMenu =
      label: 'File'
      submenu: [
        { label: 'New Window', command: 'application:new-window' }
        { label: 'New File', command: 'application:new-file' }
        { type: 'separator' }
        { label: 'Open...', command: 'application:open' }
        { label: 'Open In Dev Mode...', command: 'application:open-dev' }
        { type: 'separator' }
        { label: 'Close Window', command: 'window:close' }
      ]

    editMenu =
      label: 'Edit'
      submenu: [
        { label: 'Undo', command: 'core:undo' }
        { label: 'Redo', command: 'core:redo' }
        { type: 'separator' }
        { label: 'Cut', command: 'core:cut' }
        { label: 'Copy', command: 'core:copy' }
        { label: 'Paste', command: 'core:paste' }
        { label: 'Select All', command: 'core:select-all' }
      ]

    viewMenu =
      label: 'View'
      submenu: [
        { label: 'Reload', command: 'window:reload' }
        { label: 'Toggle Full Screen', command: 'window:toggle-full-screen' }
        { label: 'Toggle Developer Tools', command: 'window:toggle-dev-tools' }
      ]

    windowMenu =
      label: 'Window'
      submenu: [
        { label: 'Minimize', command: 'application:minimize' }
        { label: 'Zoom', command: 'application:zoom' }
        { type: 'separator' }
        { label: 'Bring All to Front', command: 'application:bring-all-windows-to-front' }
      ]

    devMenu =
      label: '\uD83D\uDC80' # Skull emoji
      submenu: [ { label: 'In Development Mode', enabled: false } ]

    template = [atomMenu, fileMenu, editMenu, viewMenu, windowMenu]
    template.push devMenu if @devMode

    @translateTemplate template, keystrokesByCommand

  # Private: Combines a menu template with the appropriate keystrokes.
  #
  # * template:
  #   An Object conforming to atom-shell's menu api but lacking accelerator and
  #   click properties.
  # * keystrokesByCommand:
  #   An Object where the keys are commands and the values are Arrays containing
  #   the keystrokes.
  #
  # Returns a complete menu configuration object for atom-shell's menu API.
  translateTemplate: (template, keystrokesByCommand) ->
    template.forEach (item) =>
      item.metadata = {}
      if item.command
        item.accelerator = @acceleratorForCommand(item.command, keystrokesByCommand)
        item.click = => global.atomApplication.sendCommand(item.command)
        item.metadata['windowSpecific'] = true unless /^application:/.test(item.command)
      @translateTemplate(item.submenu, keystrokesByCommand) if item.submenu
    template

  # Private: Determine the accelerator for a given command.
  #
  # * command:
  #   The name of the command.
  # * keystrokesByCommand:
  #   An Object where the keys are commands and the values are Arrays containing
  #   the keystrokes.
  #
  # Returns a String containing the keystroke in a format that can be interpreted
  #   by atom shell to provide nice icons where available.
  acceleratorForCommand: (command, keystrokesByCommand) ->
    keystroke = keystrokesByCommand[command]?[0]
    return null unless keystroke

    modifiers = keystroke.split('-')
    key = modifiers.pop()

    modifiers.push("Shift") if key != key.toLowerCase()
    modifiers = modifiers.map (modifier) ->
      modifier.replace(/shift/ig, "Shift")
              .replace(/meta/ig, "Command")
              .replace(/ctrl/ig, "MacCtrl")
              .replace(/alt/ig, "Alt")

    keys = modifiers.concat([key.toUpperCase()])
    keys.join("+")
