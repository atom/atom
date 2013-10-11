path = require 'path'

_ = require 'underscore'
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
    @sendToBrowserProcess(@template, atom.keymap.keystrokesByCommandForSelector('body'))

  # Private
  loadCoreItems: ->
    menuPaths = fsUtils.listSync(atom.config.bundledMenusDirPath, ['cson', 'json'])
    for menuPath in menuPaths
      data = CSON.readFileSync(menuPath)
      @add(data.menu)

  # Private: Merges an item in a submenu aware way such that new items are always
  # appended to the bottom of existing menus where possible.
  merge: (menu, item) ->
    if item.submenu? and match = _.find(menu, (o) -> o.submenu? and o.label == item.label)
      @merge(match.submenu, i) for i in item.submenu
    else
      menu.push(item)

  # Private
  sendToBrowserProcess: (template, keystrokesByCommand) ->
    ipc.sendChannel 'update-application-menu', template, keystrokesByCommand
