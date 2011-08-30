# This is the CoffeeScript API that wraps all of Cocoa.

$ = require 'jquery'
_ = require 'underscore'

# Handles the UI chrome
Chrome =
  addPane: (position, html) ->
    verticalDiv = $('#app-vertical')
    horizontalDiv = $('#app-horizontal')

    el = document.createElement("div")
    el.setAttribute('class', "pane " + position)
    el.innerHTML = html

    switch position
      when 'top', 'main'
        verticalDiv.prepend(el)
      when 'left'
        horizontalDiv.prepend(el)
      when 'bottom'
        verticalDiv.append(el)
      when 'right'
        horizontalDiv.append(el)
      else
        throw "I DON'T KNOW HOW TO DEAL WITH #{position}"

  # path - Optional. The String path to the file to base it on.
  inspector: (webView) ->
    webView ?= WindowController.webView
    @_inspector ?= OSX.WebInspector.alloc.initWithWebView webView

  createWindow: (path) ->
    c = OSX.AtomWindowController.alloc.initWithWindowNibName "AtomWindow"
    c.window
    c.window.makeKeyAndOrderFront null

  # Set the active window's dirty status.
  setDirty: (bool) ->
    Chrome.activeWindow().setDocumentEdited bool

  # Returns a boolean
  dirty: ->
    Chrome.activeWindow().isDocumentEdited()

  # Returns the active NSWindow object
  activeWindow: ->
    OSX.NSApplication.sharedApplication.keyWindow

  # Returns null or a file path.
  openPanel: ->
    panel = OSX.NSOpenPanel.openPanel
    panel.setCanChooseDirectories(true)
    if panel.runModal isnt OSX.NSFileHandlingPanelOKButton
      return null
    panel.filenames.lastObject

  # Returns null or a file path.
  savePanel: ->
    panel = OSX.NSSavePanel.savePanel
    if panel.runModal isnt OSX.NSFileHandlingPanelOKButton
      return null
    panel.filenames.lastObject

  writeToPasteboard: (text) ->
    pb = OSX.NSPasteboard.generalPasteboard
    pb.declareTypes_owner [OSX.NSStringPboardType], null
    pb.setString_forType text, OSX.NSStringPboardType

  openURL: (url) ->
    window.location = url
    Chrome.title _.last url.replace(/\/$/,'').split '/'

  title: (text) ->
    WindowController.window.title = text

  appRoot: ->
    OSX.NSBundle.mainBundle.resourcePath

# Handles the file system
File =
  read: (path) ->
    OSX.NSString.stringWithContentsOfFile(File.expand path).toString()
  write: (path, contents) ->
    str = OSX.NSString.stringWithString contents
    str.writeToFile_atomically File.expand(path), true
  expand: (path) ->
    if /~/.test path
      OSX.NSString.stringWithString(path).stringByExpandingTildeInPath
    else if path.indexOf('./') is 0
      "#{Chrome.appRoot}/#{path}"
    else
      path
  isFile: (path) ->
    isDir = new outArgument
    exists = OSX.NSFileManager.defaultManager.fileExistsAtPath_isDirectory(path, isDir)
    exists and not isDir.valueOf()

Dir =
  list: (path, recursive) ->
    path = File.expand path
    fm = OSX.NSFileManager.defaultManager
    if recursive
      paths = fm.subpathsAtPath path
    else
      paths = fm.contentsOfDirectoryAtPath_error path, null
    _.map paths, (entry) -> "#{path}/#{entry}"
  isDir: (path) ->
    isDir = new outArgument
    exists = OSX.NSFileManager.defaultManager.fileExistsAtPath_isDirectory(path, isDir)
    exists and isDir.valueOf()

Process =
  cwd: (path) ->
    if dir?
      OSX.NSFileManager.defaultManager.changeCurrentDirectoryPath(path)
    else
      OSX.NSFileManager.defaultManager.currentDirectoryPath()

  env: ->
    OSX.NSProcess.processInfo.environment()

exports.Chrome = Chrome
exports.File = File
exports.Dir = Dir
exports.Process = Process
