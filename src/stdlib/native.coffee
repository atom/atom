_ = require 'underscore'

module.exports =
class Native
  alert: (message, detailedMessage, buttons) ->
    alert = OSX.NSAlert.alloc.init
    alert.setMessageText message
    alert.setInformativeText detailedMessage
    callbacks = {}
    for label, callback of buttons
      button = alert.addButtonWithTitle label
      callbacks[button.tag] = callback

    buttonTag = alert.runModal
    return callbacks[buttonTag]()

  # path - Optional. The String path to the file to base it on.
  newWindow: (path) ->
    controller = OSX.NSApp.createController path
    controller.window
    controller.window.makeKeyAndOrderFront null

  # Returns null or a file path.
  openPanel: ->
    panel = OSX.NSOpenPanel.openPanel
    panel.setCanChooseDirectories true
    if panel.runModal isnt OSX.NSFileHandlingPanelOKButton
      return null
    filename = panel.filenames.lastObject
    localStorage.lastOpenedPath = filename
    filename.valueOf()

  # Returns null or a file path.
  savePanel: ->
    panel = OSX.NSSavePanel.savePanel
    if panel.runModal isnt OSX.NSFileHandlingPanelOKButton
      return null
    panel.filenames.lastObject.valueOf()

  writeToPasteboard: (text) ->
    pb = OSX.NSPasteboard.generalPasteboard
    pb.declareTypes_owner [OSX.NSStringPboardType], null
    pb.setString_forType text, OSX.NSStringPboardType

  readFromPasteboard: (text) ->
    pb = OSX.NSPasteboard.generalPasteboard
    results = pb.readObjectsForClasses_options [OSX.NSString], null
    results?[0]?.toString()

  resetMainMenu: (menu) ->
    # OSX.NSApp.resetMainMenu

  addMenuItem: (itemPath, keyPattern) ->
    # itemPathComponents = itemPath.split /\s*>\s*/
    # submenu = @buildSubmenuPath(OSX.NSApp.mainMenu, itemPathComponents[0..-2])
    # title = _.last(itemPathComponents)
    # unless submenu.itemWithTitle(title)
    #   item = OSX.AtomMenuItem.alloc.initWithTitle_itemPath(title, itemPath).autorelease
    #   item.setKeyEquivalentModifierMask 0 # Because in Cocoa defaults it to NSCommandKeyMask

    #   if keyPattern
    #     bindingSet = new (require('binding-set'))("*", {})
    #     keys = bindingSet.parseKeyPattern keyPattern

    #     modifierMask = (keys.metaKey and OSX.NSCommandKeyMask ) |
    #                    (keys.shiftKey and OSX.NSShiftKeyMask) |
    #                    (keys.altKey and OSX.NSAlternateKeyMask) |
    #                    (keys.ctrlKey and OSX.NSControlKeyMask)

    #     item.setKeyEquivalent keys.key
    #     item.setKeyEquivalentModifierMask modifierMask
    #   submenu.addItem(item)

  buildSubmenuPath: (menu, path) ->
    # return menu if path.length == 0

    # first = path[0]
    # unless item = menu.itemWithTitle(first)
    #   item = OSX.AtomMenuItem.alloc.initWithTitle_action_keyEquivalent(first, null, "").autorelease
    #   menu.addItem(item)
    # unless submenu = item.submenu
    #   submenu = OSX.NSMenu.alloc.initWithTitle(first)
    #   item.submenu = submenu

    # @buildSubmenuPath(submenu, path[1..-1])

