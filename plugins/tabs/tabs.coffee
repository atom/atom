$ = require 'jquery'

Plugin = require 'plugin'
File = require 'fs'
TabsPane = require 'tabs/tabspane'

module.exports =
class Tabs extends Plugin
  # The Editor pane we're managing.
  editor: null

  keymap: ->
    'Command-W': 'closeActiveTab'
    'Command-Shift-[': 'prevTab'
    'Command-Shift-]': 'nextTab'
    'Command-1': -> @pane.switchToTab 1
    'Command-2': -> @pane.switchToTab 2
    'Command-3': -> @pane.switchToTab 3
    'Command-4': -> @pane.switchToTab 4
    'Command-5': -> @pane.switchToTab 5
    'Command-6': -> @pane.switchToTab 6
    'Command-7': -> @pane.switchToTab 7
    'Command-8': -> @pane.switchToTab 8
    'Command-9': -> @pane.switchToTab 9

  constructor: (args...) ->
    super args...

    @pane = new TabsPane @window, @
    @pane.toggle()

    @window.on 'open', ({filename}) =>
      return if File.isDirectory filename  # Ignore directories
      @pane.addTab filename

    @window.on 'close', ({filename}) =>
      @pane.removeTab filename

  # Move all of this methods below to pane? I think so
  closeActiveTab: ->
    activeTab = $('#tabs ul .active')
    @editor.close(activeTab.data 'path')

  nextTab: ->
    @switchToTab $('#tabs ul .active').next()

  prevTab: ->
    @switchToTab $('#tabs ul .active').prev()
