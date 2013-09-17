$ = require 'jquery'

# Public: Provides a registry for commands that you'd like to appear in the
# context menu.
#
# Should be accessed via `atom.contextMenuMap`.
module.exports =
class ContextMenuMap
  # Private:
  constructor: ->
    @mappings = {}
    @devModeMappings = {}

  # Public: Registers a command to be displayed when the relevant item is right
  # clicked.
  #
  # * selector: The css selector for the active element which should include
  #   the given command in its context menu.
  # * label: The text that should appear in the context menu.
  # * command: The command string that should be triggered on the activeElement
  #   which matches your selector.
  # * options:
  #    + devMode: Indicates whether this command should only appear while the
  #      editor is in dev mode.
  add: (selector, label, command, {devMode}={}) ->
    mappings = if devMode then @devModeMappings else @mappings
    mappings[selector] ?= []
    mappings[selector].push({label, command})

  # Private:
  bindingsForElement: (element, {devMode}={}) ->
    mappings = if devMode then @devModeMappings else @mappings
    items for selector, items of mappings when element.webkitMatchesSelector(selector)

  # Public: Used to generate the context menu for a specific element.
  #
  # * element: The DOM element to generate the menu template for.
  menuTemplateForElement: (element) ->
    menuTemplate = []
    for devMode in [false, true]
      for items in @bindingsForElement(element, {devMode})
        for {label, command} in items
          template = {label}
          template.click = -> $(element).trigger(command)
          menuTemplate.push(template)

    menuTemplate
