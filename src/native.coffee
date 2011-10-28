module.exports =
class Native
  # path - Optional. The String path to the file to base it on.
  @newWindow: (path) ->
    controller = OSX.NSApp.createController
    controller.window
    controller.window.makeKeyAndOrderFront null

  # Returns null or a file path.
  @openPanel: ->
    panel = OSX.NSOpenPanel.openPanel
    panel.setCanChooseDirectories true
    if panel.runModal isnt OSX.NSFileHandlingPanelOKButton
      return null
    filename = panel.filenames.lastObject
    localStorage.lastOpenedPath = filename
    filename.toString()

  @openURL: (url) ->
    window.location = url
    App = require 'app'
    App.activeWindow.setTitle _.last url.replace(/\/$/,'').split '/'

  # Returns null or a file path.
  @savePanel: ->
    panel = OSX.NSSavePanel.savePanel
    if panel.runModal isnt OSX.NSFileHandlingPanelOKButton
      return null
    panel.filenames.lastObject

  @writeToPasteboard: (text) ->
    pb = OSX.NSPasteboard.generalPasteboard
    pb.declareTypes_owner [OSX.NSStringPboardType], null
    pb.setString_forType text, OSX.NSStringPboardType
