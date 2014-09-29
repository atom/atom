{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
remote = require 'remote'
path = require 'path'
CSON = require 'season'
fs = require 'fs-plus'
{specificity} = require 'clear-cut'
{Disposable} = require 'event-kit'
MenuHelpers = require './menu-helpers'

SpecificityCache = {}
SequenceCount = 0

# Extended: Provides a registry for commands that you'd like to appear in the
# context menu.
#
# An instance of this class is always available as the `atom.contextMenu`
# global.
module.exports =
class ContextMenuManager
  constructor: ({@resourcePath, @devMode}) ->
    @definitions = {'.overlayer': []} # TODO: Remove once color picker package stops touching private data
    @activeElement = null

    @itemSets = []

    # @devModeDefinitions['.workspace'] = [
    #   label: 'Inspect Element'
    #   command: 'application:inspect'
    #   executeAtBuild: (e) ->
    #     @commandOptions = x: e.pageX, y: e.pageY
    # ]

    atom.keymaps.onDidLoadBundledKeymaps => @loadPlatformItems()

  loadPlatformItems: ->
    menusDirPath = path.join(@resourcePath, 'menus')
    platformMenuPath = fs.resolve(menusDirPath, process.platform, ['cson', 'json'])
    map = CSON.readFileSync(platformMenuPath)
    atom.contextMenu.add(platformMenuPath, map['context-menu'])

  # Public: Creates menu definitions from the object specified by the menu
  # JSON API.
  #
  # * `name` The path of the file that contains the menu definitions.
  # * `object` The 'context-menu' object specified in the menu JSON API.
  # * `options` An optional {Object} with the following keys:
  #   * `devMode` Determines whether the entries should only be shown when
  #     the window is in dev mode.
  add: (name, object, {devMode}={}) ->
    unless typeof arguments[0] is 'object'
      return @add(@convertLegacyItems(object), {devMode})

    itemsBySelector = _.deepClone(arguments[0])
    devMode = arguments[1]?.devMode ? false
    addedItemSets = []

    for selector, items of itemsBySelector
      itemSet = new ContextMenuItemSet(selector, items)
      addedItemSets.push(itemSet)
      @itemSets.push(itemSet)

    new Disposable =>
      for itemSet in addedItemSets
        @itemSets.splice(@itemSets.indexOf(itemSet), 1)

  templateForElement: (element) ->
    template = []
    currentTarget = element

    while currentTarget?
      matchingItemSets =
        @itemSets
          .filter (itemSet) -> currentTarget.webkitMatchesSelector(itemSet.selector)
          .sort (a, b) -> a.compare(b)

      for {items} in matchingItemSets
        MenuHelpers.merge(template, item) for item in items

      currentTarget = currentTarget.parentElement

    template

  convertLegacyItems: (legacyItems) ->
    itemsBySelector = {}

    for selector, commandsByLabel of legacyItems
      itemsBySelector[selector] = items = []

      for label, commandOrSubmenu of commandsByLabel
        if typeof commandOrSubmenu is 'object'
          items.push({label, submenu: @convertLegacyItems(commandOrSubmenu)})
        else if commandOrSubmenu is '-'
          items.push({type: 'separator'})
        else
          items.push({label, command: commandOrSubmenu})

    itemsBySelector

  # Public: Request a context menu to be displayed.
  #
  # * `event` A DOM event.
  showForEvent: (event) ->
    @activeElement = event.target
    menuTemplate = @templateForElement(@activeElement)

    return unless menuTemplate?.length > 0
    # @executeBuildHandlers(event, menuTemplate)
    remote.getCurrentWindow().emit('context-menu', menuTemplate)
    return

class ContextMenuItemSet
  constructor: (@selector, @items) ->
    @specificity = (SpecificityCache[@selector] ?= specificity(@selector))
    @sequenceNumber = SequenceCount++

  compare: (other) ->
    other.specificity - @specificity  or
      other.sequenceNumber - @sequenceNumber
