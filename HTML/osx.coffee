# This is the CoffeeScript API that wraps all of Cocoa.

# Handles the UI chrome
Chrome =
  # Returns null or a file path.
  openPanel: ->
    panel = OSX.NSOpenPanel.openPanel
    if panel.runModal isnt OSX.NSFileHandlingPanelOKButton
      return null
    panel.filenames.lastObject

  # Returns null or a file path.
  savePanel: ->
    panel = OSX.NSSavePanel.savePane
    if panel.runModal isnt OSX.NSFileHandlingPanelOKButton
      return null
    panel.filenames.lastObject

  writeToPasteboard: (text) ->
    pb = OSX.NSPasteboard.generalPasteboard
    pb.declareTypes_owner [OSX.NSStringPboardType], null
    pb.setString_forType text, OSX.NSStringPboardType



# Handles the file system
File =
  read: (path) ->
    OSX.NSString.stringWithContentsOfFile path
  write: (path, contents) ->
    str = OSX.NSString.stringWithString contents
    str.writeToFile_atomically path, true
