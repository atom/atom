{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
remote = require 'remote'

# Public: Provides a registry for commands that you'd like to appear in the
# context menu.
#
# An instance of this class is always available as the `atom.contextMenu`
# global.
module.exports =
class ContextMenuManager
  constructor: (@devMode=false) ->
    @definitions = {}
    @devModeDefinitions = {}
    @activeElement = null

    @devModeDefinitions['.workspace'] = [
      label: 'Inspect Element'
      command: 'application:inspect'
      executeAtBuild: (e) ->
        @commandOptions = x: e.pageX, y: e.pageY
    ]

  # Public: Creates menu definitions from the object specified by the menu
  # JSON API.
  #
  # * `name` The path of the file that contains the menu definitions.
  # * `object` The 'context-menu' object specified in the menu JSON API.
  # * `options` An optional {Object} with the following keys:
  #   * `devMode` Determines whether the entries should only be shown when
  #               the window is in dev mode.
  add: (name, object, {devMode}={}) ->
    for selector, items of object
      for label, commandOrSubmenu of items
        if typeof commandOrSubmenu is 'object'
          submenu = []
          for submenuLabel, command of commandOrSubmenu
            submenu.push(@buildMenuItem(submenuLabel, command))
          @addBySelector(selector, {label: label, submenu: submenu}, {devMode})
        else
          menuItem = @buildMenuItem(label, commandOrSubmenu)
          @addBySelector(selector, menuItem, {devMode})

    undefined

  buildMenuItem: (label, command) ->
    if command is '-'
      {type: 'separator'}
    else
      {label, command}

  # Registers a command to be displayed when the relevant item is right
  # clicked.
  #
  # * `selector` The css selector for the active element which should include
  #              the given command in its context menu.
  # * `definition` The object containing keys which match the menu template API.
  # * `options` An optional {Object} with the following keys:
  #   * `devMode` Indicates whether this command should only appear while the
  #               editor is in dev mode.
  addBySelector: (selector, definition, {devMode}={}) ->
    definitions = if devMode then @devModeDefinitions else @definitions
    if not _.findWhere(definitions[selector], definition) or _.isEqual(definition, {type: 'separator'})
      (definitions[selector] ?= []).push(definition)

  # Returns definitions which match the element and devMode.
  definitionsForElement: (element, {devMode}={}) ->
    definitions = if devMode then @devModeDefinitions else @definitions
    matchedDefinitions = []
    for selector, items of definitions when element.webkitMatchesSelector(selector)
      matchedDefinitions.push(_.clone(item)) for item in items

    matchedDefinitions

  # Used to generate the context menu for a specific element and it's
  # parents.
  #
  # The menu items are sorted such that menu items that match closest to the
  # active element are listed first. The further down the list you go, the higher
  # up the ancestor hierarchy they match.
  #
  # * `element` The DOM element to generate the menu template for.
  menuTemplateForMostSpecificElement: (element, {devMode}={}) ->
    menuTemplate = @definitionsForElement(element, {devMode})
    if element.parentElement
      menuTemplate.concat(@menuTemplateForMostSpecificElement(element.parentElement, {devMode}))
    else
      menuTemplate

  # Returns a menu template for both normal entries as well as
  # development mode entries.
  combinedMenuTemplateForElement: (element) ->
    normalItems = @menuTemplateForMostSpecificElement(element)
    devItems = if @devMode then @menuTemplateForMostSpecificElement(element, devMode: true) else []

    menuTemplate = normalItems
    menuTemplate.push({ type: 'separator' }) if normalItems.length > 0 and devItems.length > 0
    menuTemplate.concat(devItems)

  # Executes `executeAtBuild` if defined for each menu item with
  # the provided event and then removes the `executeAtBuild` property from
  # the menu item.
  #
  # This is useful for commands that need to provide data about the event
  # to the command.
  executeBuildHandlers: (event, menuTemplate) ->
    for template in menuTemplate
      template?.executeAtBuild?.call(template, event)
      delete template.executeAtBuild

  # Public: Request a context menu to be displayed.
  #
  # * `event` A DOM event.
  showForEvent: (event) ->
    @activeElement = event.target
    menuTemplate = @combinedMenuTemplateForElement(event.target)
    return unless menuTemplate?.length > 0
    @executeBuildHandlers(event, menuTemplate)
    remote.getCurrentWindow().emit('context-menu', menuTemplate)
    undefined
