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

  initialize: ->
    @reload(File.workingDirectory())
    @editor = activeWindow.document

    activeWindow.project = this

    @editor.ace.on 'open', ({filename}) =>
      if File.isDirectory filename
        @reload filename
      else
        openedPaths = @storage('openedPaths') ? []
        if not _.include openedPaths, filename
          openedPaths.push filename
          @storage('openedPaths', openedPaths)

    @editor.ace.on 'close', ({filename}) =>
      if File.isFile filename
        openedPaths = @storage('openedPaths') ? []
        openedPaths = _.without openedPaths, filename
        @storage('openedPaths', openedPaths)

    @editor.ace.on 'loaded', =>
      # Reopen files (remove ones that no longer exist)
      openedPaths = @storage('openedPaths') ? []
      for path in openedPaths
        if File.isFile path
          @editor.open path
        else if not File.exists path
          openedPaths = _.without openedPaths, path
          @storage('openedPaths', openedPaths)

    $('#project li').live 'click', (event) =>
      $('#project .active').removeClass 'active'
      el = $(event.currentTarget)
      path = decodeURIComponent el.attr 'path'
      if File.isDirectory path
        openedPaths = @storage('openedPaths') ? []
        if el.hasClass 'open'
          openedPaths = _.without openedPaths, path
          el.removeClass 'open'
          el.children("ul").remove()
        else
          openedPaths.push path unless _.include openedPaths, path
          el.addClass 'open'
          list = @createList path
          el.append list

        @storage('openedPaths', openedPaths)
      else
        el.addClass 'active'
        activeWindow.open path

      false # Don't bubble!

  storageNamespace: ->
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
      openedPaths = @storage('openedPaths') ? []
      if _.include(openedPaths, path) and type == 'dir'
        listItem.append @createList path
        listItem.addClass "open"
      list.append listItem

    list

  paths: ->
    _paths = []
    for dir in File.list @dir
      continue if /\.git|Cocoa/.test dir
      _paths.push File.listDirectoryTree dir
    _.reject _.flatten(_paths), (dir) -> File.isDirectory dir

