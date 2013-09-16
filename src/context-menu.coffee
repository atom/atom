Menu = require 'menu'
BrowserWindow =  require 'browser-window'

module.exports =
class ContextMenu
  constructor: (template) ->
    menu = Menu.buildFromTemplate template
    menu.popup(BrowserWindow.getFocusedWindow())
