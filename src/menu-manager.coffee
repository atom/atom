path = require 'path'

_ = require 'underscore-plus'
ipc = require 'ipc'
CSON = require 'season'

fsUtils = require './fs-utils'

# Public: Provides a registry for menu items that you'd like to appear in the
# application menu.
#
# Should be accessed via `atom.menu`.
module.exports =
class MenuManager
  # Private:
  constructor: ->
    @template = []
    atom.keymap.on 'bundled-keymaps-loaded', => @loadCoreItems()

  # Public: Adds the given item definition to the existing template.
  #
  # * item:
  #   An object which describes a menu item as defined by
  #   https://github.com/atom/atom-shell/blob/master/docs/api/browser/menu.md
  #
  # Returns nothing.
  add: (items) ->
    @merge(@template, item) for item in items
    @update()

  # Public: Refreshes the currently visible menu.
  update: ->
    keystrokesByCommand = atom.keymap.keystrokesByCommandForSelector('body')
    _.extend(keystrokesByCommand, atom.keymap.keystrokesByCommandForSelector('.editor'))
    _.extend(keystrokesByCommand, atom.keymap.keystrokesByCommandForSelector('.editor:not(.mini)'))
    @sendToBrowserProcess(@template, keystrokesByCommand)

  # Private
  loadCoreItems: ->
    menuPaths = fsUtils.listSync(atom.config.bundledMenusDirPath, ['cson', 'json'])
    for menuPath in menuPaths
      data = CSON.readFileSync(menuPath)
      @add(data.menu)

  # Private: Merges an item in a submenu aware way such that new items are always
  # appended to the bottom of existing menus where possible.
  merge: (menu, item) ->
    item = _.deepClone(item)

    if item.submenu? and match = _.find(menu, (i) -> i.submenu? and i.label == item.label)
      @merge(match.submenu, i) for i in item.submenu
    else
      menu.push(item) unless _.find(menu, (i) -> i.label == item.label)

  # Private: OSX can't handle displaying accelerators for multiple keystrokes.
  # If they are sent across, it will stop processing accelerators for the rest
  # of the menu items.
  filterMultipleKeystrokes: (keystrokesByCommand) ->
    filtered = {}
    for key, bindings of keystrokesByCommand
      for binding in bindings
        continue if binding.indexOf(' ') != -1

        # Currently being implemented in atom-shell
        continue if binding.indexOf('-=') != -1
        continue if binding.indexOf('-up') != -1
        continue if binding.indexOf('-down') != -1
        continue if binding.indexOf('tab') != -1

        console.log binding if binding.indexOf('alt-meta') !=-1
        filtered[key] ?= []
        filtered[key].push(binding)
    filtered

  # Private
  sendToBrowserProcess: (template, keystrokesByCommand) ->
    keystrokesByCommand = @filterMultipleKeystrokes(keystrokesByCommand)
    ipc.sendChannel 'update-application-menu', template, keystrokesByCommand
