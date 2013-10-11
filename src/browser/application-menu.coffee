app = require 'app'
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
  menu: null

  constructor: (@version) ->
    @menu = Menu.buildFromTemplate @getDefaultTemplate()
    Menu.setApplicationMenu @menu

  # Public: Updates the entire menu with the given keybindings.
  #
  # * template:
  #   The Object which describes the menu to display.
  # * keystrokesByCommand:
  #   An Object where the keys are commands and the values are Arrays containing
  #   the keystrokes.
  update: (template, keystrokesByCommand) ->
    @translateTemplate template, keystrokesByCommand
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
              .replace(/ctrl/ig, "Ctrl")
              .replace(/alt/ig, "Alt")

    keys = modifiers.concat([key.toUpperCase()])
    keys.join("+")
