_ = require 'underscore'

File = require 'fs'
Extension = require 'extension'
ProjectPane = require 'project/projectpane'

module.exports =
class Project extends Extension
  keymap: ->
    'Command-Ctrl-N': -> @pane.toggle()

  storageNamespace: ->
    @.constructor.name + @window.path

  constructor: (args...) ->
    super args...

    @pane = new ProjectPane @window, @
    @pane.toggle()

    @window.on 'open', ({filename}) =>
      if File.isDirectory filename
        @pane.reload filename # I don't think this can ever happen.
      else
        openedPaths = @get 'openedPaths', []
        if not _.include openedPaths, filename
          openedPaths.push filename
          @set 'openedPaths', openedPaths

    @window.on 'close', ({filename}) =>
      if File.isFile filename
        openedPaths = @get 'openedPaths', []
        openedPaths = _.without openedPaths, filename
        @set 'openedPaths', openedPaths

  load: ->
    # Reopen files (remove ones that no longer exist)
    openedPaths = @get 'openedPaths', []
    for path in openedPaths
      if File.isFile path
        @window.open path
      else if not File.exists path
        openedPaths = _.without openedPaths, path
        @set 'openedPaths', openedPaths

