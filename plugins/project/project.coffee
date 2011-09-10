$ = require 'jquery'
_ = require 'underscore'

{activeWindow} = require 'app'
File = require 'fs'
Pane = require 'pane'

module.exports =
class Project extends Pane
  showing: false

  position: 'left'
  html: require "project/project.html"

  keymap:
    'Command-Ctrl-N': 'toggle'

  initialize: ->
    @dir = File.workingDirectory()

    activeWindow.document.ace.on 'open', ({filename}) =>
      @reload() if File.isDirectory filename

    $('#project li').live 'click', (event) =>
      $('#project .active').removeClass 'active'
      el = $(event.currentTarget)
      path = decodeURIComponent el.attr 'path'
      if File.isDirectory path
        if el.hasClass 'open'
          el.removeClass 'open'
          el.children("ul").remove()
        else
          el.addClass 'open'
          list = @createList path
          el.append "<ul>#{list}</ul>"
      else
        el.addClass 'active'
        activeWindow.open path

      false # Don't bubble!

  toggle: ->
    if @showing
      $('#project').parent().remove()
    else
      activeWindow.addPane this
      @reload()

    @showing = not @showing

  reload: ->
    @dir = dir = File.workingDirectory()
    $('#project .cwd').text _.last dir.split '/'
    $('#project li').remove()
    $('#project .files').append @createList dir

  createList: (dir) ->
    files = File.list dir
    listItems = _.map files, (path) ->
      filename = path.replace(dir, "").substring 1
      type = if File.isDirectory(path) then 'dir' else 'file'
      path = encodeURIComponent path
      "<li class='#{type}' path='#{path}'>#{filename}</li>"

    listItems.join '\n'
