$ = require 'jquery'
_ = require 'underscore'

File = require 'fs'
Pane = require 'pane'

module.exports =
class ProjectPane extends Pane
  position: 'left'

  project: null

  html: $ require "project/project.html"

  constructor: (@window, @project) ->
    super @window

    @reload()

    $('#project li').live 'click', (event) =>
      return true if event.__projectClicked__
      
      $('#project .active').removeClass 'active'
      el = $(event.currentTarget)
      path = decodeURIComponent el.attr 'path'
      if File.isDirectory path
        openedPaths = @project.get 'openedPaths', []
        if el.hasClass 'open'
          openedPaths = _.without openedPaths, path
          el.removeClass 'open'
          el.children("ul").remove()
        else
          openedPaths.push path unless _.include openedPaths, path
          el.addClass 'open'
          list = @createList path
          el.append list

        @project.set 'openedPaths', openedPaths
      else
        el.addClass 'active'
        @window.open path
      
      # HACK I need the event to propogate beyond the project pane,
      # but I need the project pane to ignore it. Need somehting
      # cleaner here.
      event.__projectClicked__ = true
      
      true

  reload: ->
    @html.children('#project .cwd').text _.last @window.path.split '/'
    fileList = @createList @window.path
    fileList.addClass('files')
    @html.children('#project .files').replaceWith(fileList)

  createList: (root) ->
    paths = File.list root

    list = $('<ul>')
    for path in paths
      filename = path.replace(root, "").substring 1
      type = if File.isDirectory path then 'dir' else 'file'
      encodedPath = encodeURIComponent path
      listItem = $("<li class='#{type}' path='#{encodedPath}'>#{filename}</li>")
      openedPaths = @project.get 'openedPaths', []
      if _.include(openedPaths, path) and type == 'dir'
        listItem.append @createList path
        listItem.addClass "open"
      list.append listItem

    list
