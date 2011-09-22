Plugin = require 'plugin'
ProjectPane = require 'project/projectpane'

module.exports =
class Project extends Plugin
  keymap: ->
    'Command-Ctrl-N': -> @pane.toggle()

  storageNamespace: ->
    @.constructor.name + @dir

  constructor: (args...) ->
    super(args...)
    @pane = new ProjectPane @window, @

    # NO! Do not use editor to handle events!
    editor = @window.document
    editor.ace.on 'open', ({filename}) =>
      if File.isDirectory filename
        @pane.reload filename
      else
        openedPaths = @get 'openedPaths', []
        if not _.include openedPaths, filename
          openedPaths.push filename
          @set 'openedPaths', openedPaths

    editor.ace.on 'close', ({filename}) =>
      if File.isFile filename
        openedPaths = @get 'openedPaths', []
        openedPaths = _.without openedPaths, filename
        @set 'openedPaths', openedPaths

    editor.ace.on 'loaded', =>
      # Reopen files (remove ones that no longer exist)
      openedPaths = @get 'openedPaths', []
      for path in openedPaths
        if File.isFile path
          @window.open path
        else if not File.exists path
          openedPaths = _.without openedPaths, path
          @set 'openedPaths', openedPaths

