$ = require 'jquery'
_ = require 'underscore'

{activeWindow} = require 'app'
File = require 'fs'
Pane = require 'pane'

module.exports =
class Project extends Pane
  showing: false

  position: 'left'

  html: $ require "project/project.html"

  keymap:
    'Command-Ctrl-N': 'toggle'

  persistantProperties:
    'openedPaths' : []

  initialize: ->
    @reload(File.workingDirectory())
    @editor = activeWindow.document

    window.x = @

    @editor.ace.on 'open', ({filename}) =>
      if File.isDirectory filename
        @reload filename
      else
        if not _.include @openedPaths, filename
          @openedPaths.push filename
          @openedPaths = @openedPaths # How icky, need to do this to store it

    @editor.ace.on 'close', ({filename}) =>
      if File.isFile filename
        @openedPaths = _.without @openedPaths, filename

    @editor.ace.on 'loaded', =>
      # Reopen files (remove ones that no longer exist)
      for path in @openedPaths
        if File.isFile path
          @editor.open path
        else if not File.exists path
          @openedPaths = _.without @openedPaths, path

    $('#project li').live 'click', (event) =>
      $('#project .active').removeClass 'active'
      el = $(event.currentTarget)
      path = decodeURIComponent el.attr 'path'
      if File.isDirectory path
        if el.hasClass 'open'
          @openedPaths = _.without @openedPaths, path
          el.removeClass 'open'
          el.children("ul").remove()
        else
          @openedPaths.push path unless _.include @openedPaths, path
          @openedPaths = @openedPaths # How icky, need to do this to store it
          el.addClass 'open'
          list = @createList path
          el.append list
      else
        el.addClass 'active'
        activeWindow.open path

      false # Don't bubble!

  persistentanceNamespace: -> 
    @.constructor.name + @dir

  reload: (dir) ->
    @dir = dir
    @html.children('#project .cwd').text _.last @dir.split '/'
    fileList = @createList @dir
    fileList.addClass('files')
    @html.children('#project .files').replaceWith(fileList)

  createList: (dir) ->
    paths = File.list dir

    list = $('<ul>')
    for path in paths
      filename = path.replace(dir, "").substring 1
      type = if File.isDirectory path then 'dir' else 'file'
      encodedPath = encodeURIComponent path
      listItem = $("<li class='#{type}' path='#{encodedPath}'>#{filename}</li>")
      if _.include(@openedPaths, path) and type == 'dir'
        listItem.append @createList path
        listItem.addClass "open"
      list.append listItem

    list
