Menu = require 'menu'
BrowserWindow =  require 'browser-window'

module.exports =
class ContextMenu
  constructor: (template) ->
    template = @createClickHandlers(template)
    menu = Menu.buildFromTemplate(template)
    menu.popup(BrowserWindow.getFocusedWindow())

  # Private: It's necessary to build the event handlers in this process, otherwise
  # closures are drug across processes and failed to be garbage collected
  # appropriately.
  createClickHandlers: (template) ->
    for item in template
      if item.command
        (item.commandOptions ?= {}).contextCommand = true
        item.click = do (item) ->
          => global.atomApplication.sendCommand(item.command, item.commandOptions)
      item
