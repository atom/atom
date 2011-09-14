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

    @editor.ace.on 'open', ({filename}) =>
      if File.isDirectory filename
        @reload filename
      else
        openedPaths = @get 'openedPaths', []
        if not _.include openedPaths, filename
          openedPaths.push filename
          @set 'openedPaths', openedPaths

    @editor.ace.on 'close', ({filename}) =>
      if File.isFile filename
        openedPaths = _.without @get('openedPaths', []), filename
        @set 'openedPaths', openedPaths

    @editor.ace.on 'loaded', =>
      # Reopen files (remove ones that no longer exist)
      openedPaths = @get 'openedPaths', []
      for path in openedPaths
        if File.isFile path
          @editor.open path
        else if not File.exists path
         openedPaths = _.without(openedPaths, path)
      @set "openedPaths", openedPaths


    $('#project li').live 'click', (event) =>
      $('#project .active').removeClass 'active'
      el = $(event.currentTarget)
      path = decodeURIComponent el.attr 'path'
      if File.isDirectory path
        openedPaths = @get('openedPaths', [])
        if el.hasClass 'open'
          openedPaths = _.without(openedPaths, path)
          el.removeClass 'open'
          el.children("ul").remove()
        else
          openedPaths.push path unless _.include openedPaths, path
          el.addClass 'open'
          list = @createList path
          el.append list

        @set 'openedPaths', openedPaths
      else
        el.addClass 'active'
        activeWindow.open path

      false # Don't bubble!

  reload: (dir) ->
    @dir = dir
    @html.children('#project .cwd').text _.last @dir.split '/'
    fileList = @createList @dir
    fileList.addClass('files')
    @html.children('#project .files').replaceWith(fileList)

  createList: (dir) ->
    paths = File.list dir

    openedPaths = @get('openedPaths', [])
    list = $('<ul>')
    for path in paths
      filename = path.replace(dir, "").substring 1
      type = if File.isDirectory path then 'dir' else 'file'
      encodedPath = encodeURIComponent path
      listItem = $("<li class='#{type}' path='#{encodedPath}'>#{filename}</li>")
      if _.include(openedPaths, path) and type == 'dir'
        listItem.append @createList path
        listItem.addClass "open"
      list.append listItem

    list

  # HATE
  # This needs to be replaced with a more generalized method like
  # Atomicity.store or better yet, add it to Pane so each pane has it's
  # own namespaced storage
  set: (key, value) ->
    try
      object = JSON.parse localStorage[@dir]
    catch error
      console.log error
      object = {}

    if value == undefined then delete object[key] else object[key] = value
    localStorage[@dir] = JSON.stringify object

  get: (key, defaultValue=null) ->
    try
      JSON.parse(localStorage[@dir])[key] or defaultValue
    catch error
      console.log error
      defaultValue
