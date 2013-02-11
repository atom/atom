Package = require 'package'
fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'

module.exports =
class AtomPackage extends Package
  metadata: null
  packageMain: null

  load: ({activateImmediately}={}) ->
    try
      @loadMetadata()
      @loadKeymaps()
      @loadStylesheets()
      if @metadata.activationEvents and not activateImmediately
        @subscribeToActivationEvents()
      else
        @activatePackageMain()
    catch e
      console.warn "Failed to load package named '#{@name}'", e.stack
    this

  disableEventHandlersOnBubblePath: (event) ->
    bubblePathEventHandlers = []
    disabledHandler = ->
    element = $(event.target)
    while element.length
      if eventHandlers = element.data('events')?[event.type]
        for eventHandler in eventHandlers
          eventHandler.disabledHandler = eventHandler.handler
          eventHandler.handler = disabledHandler
          bubblePathEventHandlers.push(eventHandler)
      element = element.parent()
    bubblePathEventHandlers

  restoreEventHandlersOnBubblePath: (eventHandlers) ->
    for eventHandler in eventHandlers
      eventHandler.handler = eventHandler.disabledHandler
      delete eventHandler.disabledHandler

  unsubscribeFromActivationEvents: (activateHandler) ->
    if _.isArray(@metadata.activationEvents)
      rootView.off(event, activateHandler) for event in @metadata.activationEvents
    else
      rootView.off(event, selector, activateHandler) for event, selector of @metadata.activationEvents

  subscribeToActivationEvents: () ->
    activateHandler = (event) =>
      bubblePathEventHandlers = @disableEventHandlersOnBubblePath(event)
      @activatePackageMain()
      $(event.target).trigger(event)
      @restoreEventHandlersOnBubblePath(bubblePathEventHandlers)
      @unsubscribeFromActivationEvents(activateHandler)

    if _.isArray(@metadata.activationEvents)
      rootView.command(event, activateHandler) for event in @metadata.activationEvents
    else
      rootView.command(event, selector, activateHandler) for event, selector of @metadata.activationEvents

  activatePackageMain: ->
    mainPath = @path
    mainPath = fs.join(mainPath, @metadata.main) if @metadata.main
    mainPath = require.resolve(mainPath)
    if fs.isFile(mainPath)
      @packageMain = require(mainPath)
      config.setDefaults(@name, @packageMain.configDefaults)
      atom.activateAtomPackage(this)

  loadMetadata: ->
    if metadataPath = fs.resolveExtension(fs.join(@path, 'package'), ['cson', 'json'])
      @metadata = fs.readObject(metadataPath)
    @metadata ?= {}

  loadKeymaps: ->
    keymapsDirPath = fs.join(@path, 'keymaps')

    if @metadata.keymaps
      for path in @metadata.keymaps
        keymapPath = fs.resolve(keymapsDirPath, path, ['cson', 'json', ''])
        keymap.load(keymapPath)
    else
      keymap.loadDirectory(keymapsDirPath)

  loadStylesheets: ->
    stylesheetDirPath = fs.join(@path, 'stylesheets')
    for stylesheetPath in fs.list(stylesheetDirPath)
      requireStylesheet(stylesheetPath)