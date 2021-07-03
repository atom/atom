path = require 'path'
CSON = require 'season'
fs = require 'fs-plus'
{calculateSpecificity, validateSelector} = require 'clear-cut'
{Disposable} = require 'event-kit'
{remote} = require 'electron'
MenuHelpers = require './menu-helpers'
{sortMenuItems} = require './menu-sort-helpers'
_ = require 'underscore-plus'

platformContextMenu = require('../package.json')?._atomMenu?['context-menu']

# Extended: Provides a registry for commands that you'd like to appear in the
# context menu.
#
# An instance of this class is always available as the `atom.contextMenu`
# global.
#
# ## Context Menu CSON Format
#
# ```coffee
# 'atom-workspace': [{label: 'Help', command: 'application:open-documentation'}]
# 'atom-text-editor': [{
#   label: 'History',
#   submenu: [
#     {label: 'Undo', command:'core:undo'}
#     {label: 'Redo', command:'core:redo'}
#   ]
# }]
# ```
#
# In your package's menu `.cson` file you need to specify it under a
# `context-menu` key:
#
# ```coffee
# 'context-menu':
#   'atom-workspace': [{label: 'Help', command: 'application:open-documentation'}]
#   ...
# ```
#
# The format for use in {::add} is the same minus the `context-menu` key. See
# {::add} for more information.
module.exports =
class ContextMenuManager
  constructor: ({@keymapManager}) ->
    @definitions = {'.overlayer': []} # TODO: Remove once color picker package stops touching private data
    @clear()

    @keymapManager.onDidLoadBundledKeymaps => @loadPlatformItems()

  initialize: ({@resourcePath, @devMode}) ->

  loadPlatformItems: ->
    if platformContextMenu?
      @add(platformContextMenu, @devMode ? false)
    else
      menusDirPath = path.join(@resourcePath, 'menus')
      platformMenuPath = fs.resolve(menusDirPath, process.platform, ['cson', 'json'])
      map = CSON.readFileSync(platformMenuPath)
      @add(map['context-menu'])

  # Public: Add context menu items scoped by CSS selectors.
  #
  # ## Examples
  #
  # To add a context menu, pass a selector matching the elements to which you
  # want the menu to apply as the top level key, followed by a menu descriptor.
  # The invocation below adds a global 'Help' context menu item and a 'History'
  # submenu on the editor supporting undo/redo. This is just for example
  # purposes and not the way the menu is actually configured in Atom by default.
  #
  # ```coffee
  # atom.contextMenu.add {
  #   'atom-workspace': [{label: 'Help', command: 'application:open-documentation'}]
  #   'atom-text-editor': [{
  #     label: 'History',
  #     submenu: [
  #       {label: 'Undo', command:'core:undo'}
  #       {label: 'Redo', command:'core:redo'}
  #     ]
  #   }]
  # }
  # ```
  #
  # ## Arguments
  #
  # * `itemsBySelector` An {Object} whose keys are CSS selectors and whose
  #   values are {Array}s of item {Object}s containing the following keys:
  #   * `label` (optional) A {String} containing the menu item's label.
  #   * `command` (optional) A {String} containing the command to invoke on the
  #     target of the right click that invoked the context menu.
  #   * `enabled` (optional) A {Boolean} indicating whether the menu item
  #     should be clickable. Disabled menu items typically appear grayed out.
  #     Defaults to `true`.
  #   * `submenu` (optional) An {Array} of additional items.
  #   * `type` (optional) If you want to create a separator, provide an item
  #      with `type: 'separator'` and no other keys.
  #   * `visible` (optional) A {Boolean} indicating whether the menu item
  #     should appear in the menu. Defaults to `true`.
  #   * `created` (optional) A {Function} that is called on the item each time a
  #     context menu is created via a right click. You can assign properties to
  #    `this` to dynamically compute the command, label, etc. This method is
  #    actually called on a clone of the original item template to prevent state
  #    from leaking across context menu deployments. Called with the following
  #    argument:
  #     * `event` The click event that deployed the context menu.
  #   * `shouldDisplay` (optional) A {Function} that is called to determine
  #     whether to display this item on a given context menu deployment. Called
  #     with the following argument:
  #     * `event` The click event that deployed the context menu.
  #
  #   * `id` (internal) A {String} containing the menu item's id.
  # Returns a {Disposable} on which `.dispose()` can be called to remove the
  # added menu items.
  add: (itemsBySelector, throwOnInvalidSelector = true) ->
    addedItemSets = []

    for selector, items of itemsBySelector
      validateSelector(selector) if throwOnInvalidSelector
      itemSet = new ContextMenuItemSet(selector, items)
      addedItemSets.push(itemSet)
      @itemSets.push(itemSet)

    new Disposable =>
      for itemSet in addedItemSets
        @itemSets.splice(@itemSets.indexOf(itemSet), 1)
      return

  templateForElement: (target) ->
    @templateForEvent({target})

  templateForEvent: (event) ->
    template = []
    currentTarget = event.target

    while currentTarget?
      currentTargetItems = []
      matchingItemSets =
        @itemSets.filter (itemSet) -> currentTarget.webkitMatchesSelector(itemSet.selector)

      for itemSet in matchingItemSets
        for item in itemSet.items
          itemForEvent = @cloneItemForEvent(item, event)
          if itemForEvent
            MenuHelpers.merge(currentTargetItems, itemForEvent, itemSet.specificity)

      for item in currentTargetItems
        MenuHelpers.merge(template, item, false)

      currentTarget = currentTarget.parentElement

    @pruneRedundantSeparators(template)
    @addAccelerators(template)

    return @sortTemplate(template)

  # Adds an `accelerator` property to items that have key bindings. Electron
  # uses this property to surface the relevant keymaps in the context menu.
  addAccelerators: (template) ->
    for id, item of template
      if item.command
        keymaps = @keymapManager.findKeyBindings({command: item.command, target: document.activeElement})
        keystrokes = keymaps?[0]?.keystrokes
        if keystrokes
          # Electron does not support multi-keystroke accelerators. Therefore,
          # when the command maps to a multi-stroke key binding, show the
          # keystrokes next to the item's label.
          if keystrokes.includes(' ')
            item.label += " [#{_.humanizeKeystroke(keystrokes)}]"
          else
            item.accelerator = MenuHelpers.acceleratorForKeystroke(keystrokes)
      if Array.isArray(item.submenu)
        @addAccelerators(item.submenu)

  pruneRedundantSeparators: (menu) ->
    keepNextItemIfSeparator = false
    index = 0
    while index < menu.length
      if menu[index].type is 'separator'
        if not keepNextItemIfSeparator or index is menu.length - 1
          menu.splice(index, 1)
        else
          index++
      else
        keepNextItemIfSeparator = true
        index++

  sortTemplate: (template) ->
    template = sortMenuItems(template)
    for id, item of template
      if Array.isArray(item.submenu)
        item.submenu = @sortTemplate(item.submenu)
    return template

  # Returns an object compatible with `::add()` or `null`.
  cloneItemForEvent: (item, event) ->
    return null if item.devMode and not @devMode
    item = Object.create(item)
    if typeof item.shouldDisplay is 'function'
      return null unless item.shouldDisplay(event)
    item.created?(event)
    if Array.isArray(item.submenu)
      item.submenu = item.submenu
        .map((submenuItem) => @cloneItemForEvent(submenuItem, event))
        .filter((submenuItem) -> submenuItem isnt null)
    return item

  showForEvent: (event) ->
    @activeElement = event.target
    menuTemplate = @templateForEvent(event)

    return unless menuTemplate?.length > 0
    remote.getCurrentWindow().emit('context-menu', menuTemplate)
    return

  clear: ->
    @activeElement = null
    @itemSets = []
    inspectElement = {
      'atom-workspace': [{
        label: 'Inspect Element'
        command: 'application:inspect'
        devMode: true
        created: (event) ->
          {pageX, pageY} = event
          @commandDetail = {x: pageX, y: pageY}
      }]
    }
    @add(inspectElement, false)

class ContextMenuItemSet
  constructor: (@selector, @items) ->
    @specificity = calculateSpecificity(@selector)
