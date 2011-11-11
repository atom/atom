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

      if el.hasClass 'dir'
        if el.hasClass 'open'
          @tree.hideDir path
          el.removeClass 'open'
          el.children("ul").remove()
        else
          @tree.showDir path
          el.addClass 'open'
          list = @createList @tree.findPath(path).paths
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
    @html.children('#tree .cwd').text _.last window.url.split '/'
    fileList = @createList @tree.paths
    fileList.addClass 'files'
    @html.children('#tree .files').replaceWith fileList

  createList: (root) ->
    shownDirs = @tree.shownDirs()
    list = $('<ul>')
    for {label, path, paths} in root
      type = if paths then 'dir' else 'file'
      encodedPath = encodeURIComponent path
      listItem = $("<li class='#{type}' data-path='#{encodedPath}'>#{label}</li>")
      if path in shownDirs and type is 'dir'
        listItem.append @createList paths
        listItem.addClass "open"
      list.append listItem

    list
