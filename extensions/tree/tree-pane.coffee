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
    @render()

    $('#tree li').live 'click', (event) =>
      $('#tree .active').removeClass 'active'

      el = $(event.currentTarget)
      url = decodeURIComponent el.data 'url'

      if el.hasClass 'dir'
        if el.hasClass 'open'
          el.removeClass 'open'
          el.find('ul').remove()
        else
          el.addClass 'open'
          list = @createList @tree.urls url
          el.append list
      else
        el.addClass 'active'
        window.open url

      false

  render: ->
    @html.children('#tree .cwd').text _.last window.url.split '/'
    fileList = @createList @tree.urls()
    fileList.addClass 'files'
    @html.children('#tree .files').replaceWith fileList

  createList: (urls) ->
    list = $('<ul>')
    for {name, url, type} in urls
      encodedURL = encodeURIComponent url
      listItem = $("<li class='#{type}' data-url='#{encodedURL}'>#{name}</li>")
      list.append listItem

    list
