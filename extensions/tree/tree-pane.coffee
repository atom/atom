$ = require 'jquery'
_ = require 'underscore'

fs = require 'fs'

Pane = require 'pane'

module.exports =
class TreePane extends Pane
  position: 'left'

  tree: null

  html: $ require "tree/tree.html"

  constructor: (@tree) ->
    @reload()

    $('#tree li').live 'click', (event) =>
      return true if event.__treeClicked__

      $('#tree .active').removeClass 'active'

      el = $(event.currentTarget)
      path = decodeURIComponent el.data 'path'

      if fs.isDirectory path
        window.x = @tree
        if el.hasClass 'open'
          @tree.hideDir path
          el.removeClass 'open'
          el.children("ul").remove()
        else
          @tree.showDir path
          el.addClass 'open'
          list = @createList path
          el.append list
      else
        el.addClass 'active'
        window.open path

      # HACK I need the event to propogate beyond the tree pane,
      # but I need the tree pane to ignore it. Need somehting
      # cleaner here.
      event.__treeClicked__ = true

      true

  reload: ->
    @html.children('#tree .cwd').text _.last window.path.split '/'
    fileList = @createList window.path
    fileList.addClass 'files'
    @html.children('#tree .files').replaceWith fileList

  createList: (root) ->
    paths = fs.list root
    shownDirs = @tree.shownDirs()

    list = $('<ul>')
    for path in paths
      continue if @tree.ignorePattern.test path
      filename = path.replace(root, "").substring 1
      type = if fs.isDirectory path then 'dir' else 'file'
      encodedPath = encodeURIComponent path
      listItem = $("<li class='#{type}' data-path='#{encodedPath}'>#{filename}</li>")

      if path in shownDirs and fs.isDirectory path
        listItem.append @createList path
        listItem.addClass "open"
      list.append listItem

    list
