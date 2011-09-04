# This is the CoffeeScript API that wraps all of Cocoa.

$ = require 'jquery'
_ = require 'underscore'
jscocoa = require 'jscocoa'
Editor  = require 'editor'
File    = require 'fs'

# Handles the UI chrome
Chrome =
  addPane: (position, html) ->
    verticalDiv = $('#app-vertical')
    horizontalDiv = $('#app-horizontal')

    el = document.createElement "div"
    el.setAttribute 'class', "pane " + position
    el.innerHTML = html

    el.addEventListener 'DOMNodeInsertedIntoDocument', ->
      Editor.resize()
    , false

    el.addEventListener 'DOMNodeRemovedFromDocument', ->
      Editor.resize()
    , false

    switch position
      when 'top', 'main'
        verticalDiv.prepend el
      when 'left'
        horizontalDiv.prepend el
      when 'bottom'
        verticalDiv.append el
      when 'right'
        horizontalDiv.append el
      else
        throw "I DON'T KNOW HOW TO DEAL WITH #{position}"

  inspector:->
    @_inspector ?= WindowController.webView.inspector

  # path - Optional. The String path to the file to base it on.
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
    panel.setCanChooseDirectories true
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


exports.Chrome = Chrome