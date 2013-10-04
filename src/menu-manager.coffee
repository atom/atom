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
    @loadCoreItems()

  # Public: Adds the given item definition to the existing template.
  #
  # * item:
  #   An object which describes a menu item as defined by
  #   https://github.com/atom/atom-shell/blob/master/docs/api/browser/menu.md
  #
  # Returns nothing.
  add: (item) ->
    @merge(@template, item)

  # Public: Refreshes the currently visible menu.
  update: ->
    @sendToBrowserProcess()

  # Private
  loadCoreItems: ->
    menuPaths = fsUtils.listSync(atom.config.bundledMenusDirPath, ['cson', 'json'])
    for menuPath in menuPaths
      data = CSON.readFileSync(menuPath)
      @add(item) for item in data.menu

  # Private: Merges an item in a menu aware way such that new items are always
  # appended to the bottom.
  merge: (template, item) ->
    if match = _.find(template, (t) -> t.label == item.label)
      match.submenu = match.submenu.concat(item.submenu)
    else
      template.push(item)

  # Private
  sendToBrowserProcess: ->
    ipc.sendChannel 'update-application-menu', @template, atom.keymap.keystrokesByCommandForSelector('body')

