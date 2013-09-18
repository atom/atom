$ = require 'jquery'
_ = require 'underscore'
remote = require 'remote'

# Public: Provides a registry for commands that you'd like to appear in the
# context menu.
#
# Should be accessed via `atom.contextMenu`.
module.exports =
class ContextMenuManager
  # Private:
  constructor: ->
    @definitions = {}
    @devModeDefinitions = {}
    @activeElement = null

    @devModeDefinitions['#root-view'] = [{ type: 'separator' }]
    @devModeDefinitions['#root-view'].push
      label: 'Inspect Element'
      command: 'application:inspect'
      executeAtBuild: (e) ->
        @.commandOptions = x: e.pageX, y: e.pageY

  # Public: Registers a command to be displayed when the relevant item is right
  # clicked.
  #
  # * selector: The css selector for the active element which should include
  #   the given command in its context menu.
  # * definition: The object containing keys which match the menu template API.
  # * options:
  #    + devMode: Indicates whether this command should only appear while the
  #      editor is in dev mode.
  add: (selector, definition, {devMode}={}) ->
    definitions = if devMode then @devModeDefinitions else @definitions
    (definitions[selector] ?= []).push(definition)

  # Private: Returns definitions which match the element and devMode.
  definitionsForElement: (element, {devMode}={}) ->
    definitions = if devMode then @devModeDefinitions else @definitions
    matchedDefinitions = []
    for selector, items of definitions when element.webkitMatchesSelector(selector)
      matchedDefinitions.push(_.clone(item)) for item in items

    matchedDefinitions

  # Private: Used to generate the context menu for a specific element and it's
  # parents.
  #
  # The menu items are sorted such that menu items that match closest to the
  # active element are listed first. The further down the list you go, the higher
  # up the ancestor hierarchy they match.
  #
  # * element: The DOM element to generate the menu template for.
  menuTemplateForMostSpecificElement: (element, {devMode}={}) ->
    menuTemplate = @definitionsForElement(element, {devMode})
    if element.parentElement
      menuTemplate.concat(@menuTemplateForMostSpecificElement(element.parentElement, {devMode}))
    else
      menuTemplate

  # Private: Returns a menu template for both normal entries as well as
  # development mode entries.
  combinedMenuTemplateForElement: (element) ->
    menuTemplate = @menuTemplateForMostSpecificElement(element)
    menuTemplate.concat(@menuTemplateForMostSpecificElement(element, devMode: true))

  # Private: Executes `executeAtBuild` if defined for each menu item with
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
  showForEvent: (event) ->
    @activeElement = event.target
    menuTemplate = @combinedMenuTemplateForElement(event.target)
    @executeBuildHandlers(event, menuTemplate)
    remote.getCurrentWindow().emit('context-menu', menuTemplate)
