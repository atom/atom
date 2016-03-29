{app, Menu} = require 'electron'
_ = require 'underscore-plus'

# Used to manage the global application menu.
#
# It's created by {AtomApplication} upon instantiation and used to add, remove
# and maintain the state of all menu items.
module.exports =
class ApplicationMenu
  constructor: (@version, @autoUpdateManager) ->
    @windowTemplates = new WeakMap()
    @setActiveTemplate(@getDefaultTemplate())
    @autoUpdateManager.on 'state-changed', (state) => @showUpdateMenuItem(state)

  # Public: Updates the entire menu with the given keybindings.
  #
  # window - The BrowserWindow this menu template is associated with.
  # template - The Object which describes the menu to display.
  # keystrokesByCommand - An Object where the keys are commands and the values
  #                       are Arrays containing the keystroke.
  update: (window, template, keystrokesByCommand) ->
    @translateTemplate(template, keystrokesByCommand)
    @substituteVersion(template)
    @windowTemplates.set(window, template)
    @setActiveTemplate(template) if window is @lastFocusedWindow

  setActiveTemplate: (template) ->
    unless _.isEqual(template, @activeTemplate)
      @activeTemplate = template
      @menu = Menu.buildFromTemplate(_.deepClone(template))
      Menu.setApplicationMenu(@menu)

    @showUpdateMenuItem(@autoUpdateManager.getState())

  # Register a BrowserWindow with this application menu.
  addWindow: (window) ->
    @lastFocusedWindow ?= window

    focusHandler = =>
      @lastFocusedWindow = window
      if template = @windowTemplates.get(window)
        @setActiveTemplate(template)

    window.on 'focus', focusHandler
    window.once 'closed', =>
      @lastFocusedWindow = null if window is @lastFocusedWindow
      @windowTemplates.delete(window)
      window.removeListener 'focus', focusHandler

    @enableWindowSpecificItems(true)

  # Flattens the given menu and submenu items into an single Array.
  #
  # menu - A complete menu configuration object for atom-shell's menu API.
  #
  # Returns an Array of native menu items.
  flattenMenuItems: (menu) ->
    items = []
    for index, item of menu.items or {}
      items.push(item)
      items = items.concat(@flattenMenuItems(item.submenu)) if item.submenu
    items

  # Flattens the given menu template into an single Array.
  #
  # template - An object describing the menu item.
  #
  # Returns an Array of native menu items.
  flattenMenuTemplate: (template) ->
    items = []
    for item in template
      items.push(item)
      items = items.concat(@flattenMenuTemplate(item.submenu)) if item.submenu
    items

  # Public: Used to make all window related menu items are active.
  #
  # enable - If true enables all window specific items, if false disables all
  #          window specific items.
  enableWindowSpecificItems: (enable) ->
    for item in @flattenMenuItems(@menu)
      item.enabled = enable if item.metadata?.windowSpecific
    return

  # Replaces VERSION with the current version.
  substituteVersion: (template) ->
    if (item = _.find(@flattenMenuTemplate(template), ({label}) -> label is 'VERSION'))
      item.label = "Version #{@version}"

  # Sets the proper visible state the update menu items
  showUpdateMenuItem: (state) ->
    checkForUpdateItem = _.find(@flattenMenuItems(@menu), ({label}) -> label is 'Check for Update')
    checkingForUpdateItem = _.find(@flattenMenuItems(@menu), ({label}) -> label is 'Checking for Update')
    downloadingUpdateItem = _.find(@flattenMenuItems(@menu), ({label}) -> label is 'Downloading Update')
    installUpdateItem = _.find(@flattenMenuItems(@menu), ({label}) -> label is 'Restart and Install Update')

    return unless checkForUpdateItem? and checkingForUpdateItem? and downloadingUpdateItem? and installUpdateItem?

    checkForUpdateItem.visible = false
    checkingForUpdateItem.visible = false
    downloadingUpdateItem.visible = false
    installUpdateItem.visible = false

    switch state
      when 'idle', 'error', 'no-update-available'
        checkForUpdateItem.visible = true
      when 'checking'
        checkingForUpdateItem.visible = true
      when 'downloading'
        downloadingUpdateItem.visible = true
      when 'update-available'
        installUpdateItem.visible = true

  # Default list of menu items.
  #
  # Returns an Array of menu item Objects.
  getDefaultTemplate: ->
    [
      label: "Atom"
      submenu: [
          {label: "Check for Update", metadata: {autoUpdate: true}}
          {label: 'Reload', accelerator: 'Command+R', click: => @focusedWindow()?.reload()}
          {label: 'Close Window', accelerator: 'Command+Shift+W', click: => @focusedWindow()?.close()}
          {label: 'Toggle Dev Tools', accelerator: 'Command+Alt+I', click: => @focusedWindow()?.toggleDevTools()}
          {label: 'Quit', accelerator: 'Command+Q', click: -> app.quit()}
      ]
    ]

  focusedWindow: ->
    _.find global.atomApplication.windows, (atomWindow) -> atomWindow.isFocused()

  # Combines a menu template with the appropriate keystroke.
  #
  # template - An Object conforming to atom-shell's menu api but lacking
  #            accelerator and click properties.
  # keystrokesByCommand - An Object where the keys are commands and the values
  #                       are Arrays containing the keystroke.
  #
  # Returns a complete menu configuration object for atom-shell's menu API.
  translateTemplate: (template, keystrokesByCommand) ->
    template.forEach (item) =>
      item.metadata ?= {}
      if item.command
        item.accelerator = @acceleratorForCommand(item.command, keystrokesByCommand)
        item.click = -> global.atomApplication.sendCommand(item.command)
        item.metadata.windowSpecific = true unless /^application:/.test(item.command)
      @translateTemplate(item.submenu, keystrokesByCommand) if item.submenu
    template

  # Determine the accelerator for a given command.
  #
  # command - The name of the command.
  # keystrokesByCommand - An Object where the keys are commands and the values
  #                       are Arrays containing the keystroke.
  #
  # Returns a String containing the keystroke in a format that can be interpreted
  #   by atom shell to provide nice icons where available.
  acceleratorForCommand: (command, keystrokesByCommand) ->
    firstKeystroke = keystrokesByCommand[command]?[0]
    return null unless firstKeystroke

    modifiers = firstKeystroke.split(/-(?=.)/)
    key = modifiers.pop().toUpperCase().replace('+', 'Plus')

    modifiers = modifiers.map (modifier) ->
      modifier.replace(/shift/ig, "Shift")
              .replace(/cmd/ig, "Command")
              .replace(/ctrl/ig, "Ctrl")
              .replace(/alt/ig, "Alt")

    keys = modifiers.concat([key])
    keys.join("+")
