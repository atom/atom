_ = require 'underscore'

module.exports =
class Native
  constructor: (nativeMethods)->
    _.extend(this, nativeMethods)

  alert: (message, detailedMessage, buttons) ->
    $native.alert(message, detailedMessage, buttons)

  # path - Optional. The String path to the file to base it on.
  newWindow: (path) ->
    controller = OSX.NSApp.createController path
    controller.window
    controller.window.makeKeyAndOrderFront null

  # Returns null or a file path.
  openPanel: ->
    $native.openPanel()

  # Returns null or a file path.
  savePanel: ->
    panel = OSX.NSSavePanel.savePanel
    if panel.runModal isnt OSX.NSFileHandlingPanelOKButton
      return null
    panel.filenames.lastObject.valueOf()

  writeToPasteboard: (text) ->
    $native.writeToPasteboard text

  readFromPasteboard: ->
    $native.readFromPasteboard()