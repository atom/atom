ipc = require 'ipc'

# Public: Provides a registry for menu items that you'd like to appear in the
# application menu.
#
# Should be accessed via `atom.menu`.
module.exports =
class MenuManager
  # Private:
  constructor: ->
    @template = {}

  # Public: Refreshes the currently visible menu.
  update: ->
    @sendToBrowserProcess()

  # Private: Request a context menu to be displayed.
  sendToBrowserProcess: ->
    ipc.sendChannel 'update-application-menu', atom.keymap.keystrokesByCommandForSelector('body')

