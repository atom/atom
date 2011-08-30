$ = require 'jquery'
_ = require 'underscore'

{Chrome, Dir, File, Process} = require 'osx'

Editor  = require 'editor'
bindKey = Editor.bindKey

exports.init = ->
  @html = require "project/project.html"

  bindKey 'toggleProjectDrawer', 'Command-Ctrl-N', (env) =>
    @toggle()
  
  Editor.ace.on 'open', =>
    @reload() if @dir? and Process.cwd() isnt @dir

  $('#project .cwd').live 'click', (event) =>
    Editor.open @dir.replace _.last(@dir.split '/'), ''
    
  $('#project li').live 'click', (event) =>
    $('#project .active').removeClass 'active'
    el = $(event.currentTarget)
    el.addClass 'active'
    path = decodeURIComponent el.attr 'path'
    Editor.open path

exports.toggle = ->
  if @showing
    $('#project').parent().remove()
  else
    Chrome.addPane 'left', @html
    @reload()

  @showing = not @showing

exports.reload = ->
  @dir = dir = Process.cwd()
  $('#project .cwd').text _.last dir.split '/'
  
  $('#project li').remove()

  files = Dir.list dir
  listItems = _.map files, (path) ->
    filename = path.replace(dir, "").substring 1
    type = if Dir.isDir(path) then 'dir' else 'file'
    "<li class='#{type}' path='#{encodeURIComponent path}'>#{filename}</li>"

  $('#project .files').append listItems.join '\n'
