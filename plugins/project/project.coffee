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
    activeWindow.document.ace.on 'open', =>
      @reload() if @dir? and File.workingDirectory() isnt @dir

    $('#project .cwd').live 'click', (event) =>
      activeWindow.open @dir.replace _.last(@dir.split '/'), ''

    $('#project li').live 'click', (event) =>
      $('#project .active').removeClass 'active'
      el = $(event.currentTarget)
      el.addClass 'active'
      path = decodeURIComponent el.attr 'path'
      activeWindow.open path

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

    files = File.list dir
    listItems = _.map files, (path) ->
      filename = path.replace(dir, "").substring 1
      type = if File.isDirectory(path) then 'dir' else 'file'
      path = encodeURIComponent path
      "<li class='#{type}' path='#{path}'>#{filename}</li>"

    $('#project .files').append listItems.join '\n'
