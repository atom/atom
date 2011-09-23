$ = require 'jquery'

File = require 'fs'
Chrome = require 'chrome'

{bindKey} = require 'keybinder'

module.exports =
class Window
  controller: null
  document: null
  nswindow: null
  panes: []

  keymap: ->
    'Command-N'       : @new
    'Command-O'       : @open
    'Command-Shift-O' : @openURL
    'Command-Ctrl-K'  : @showConsole
    'Command-Ctrl-M'  : @reload

  constructor: (options={}) ->
    for option, value of options
      @[option] = value

    for shortcut, method of @keymap()
      bindKey @, shortcut, method

    @nswindow = @controller?.window
    @loadPlugins()
    @document.ace._emit "loaded"

  loadPlugins: ->
    Editor = require 'editor'
    @document = new Editor @

    @open @path if @path?

    @plugins = []
    App  = require 'app'
    for pluginPath in File.list(App.root + "/plugins") 
      if File.isDirectory pluginPath
        try
          plugin = require pluginPath
          @plugins.push new plugin(@)
        catch error
          console.warn "Plugin Failed: #{File.base pluginPath}"
          console.warn error

    # After all the plugins are created, load them.
    for plugin in @plugins
      try
        plugin.load()
      catch error
        console.warn "Plugin Loading Failed: #{plugin.constructor.name}"
        console.warn error

  close: ->
    @controller.close()

  reload: ->
    Chrome.newWindow()
    @close()

  isDirty: ->
    @nswindow.isDocumentEdited()

  # Set the active window's dirty status.
  setDirty: (bool) ->
    @nswindow.setDocumentEdited bool

  inspector: ->
    @_inspector ?= WindowController.webView.inspector

  new: ->
    Chrome.newWindow()

  open: (path) ->
    @document?.open path

  openURL: (url) ->
    if url = prompt "Enter URL:"
      Chrome = require 'app'
      Chrome.openURL url

  showConsole: ->
    @inspector().showConsole(1)

  title: ->
    @nswindow.title

  setTitle: (title) ->
    @nswindow.title = title
