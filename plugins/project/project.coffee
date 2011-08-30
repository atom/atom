$ = require 'jquery'
_ = require 'underscore'
{Chrome, File, Dir} = require 'osx'
Editor = require 'editor'

{Chrome, Dir, File, Process} = require 'osx'
{bindKey} = require 'editor'

exports.init = ->
  @html = File.read Chrome.appRoot() + "/plugins/project/project.html"

  bindKey 'toggleProjectDrawer', 'Command-Ctrl-N', (env) =>
    @toggle()

  $('#project .file').live 'click', (event) =>
    el = $(event.currentTarget)
    path =  decodeURIComponent el.attr 'path'
    Editor.open path

exports.toggle = ->
  if @showing
    $('#project').parent().remove()
  else
    Chrome.addPane 'left', @html
    @reload()

  @showing = not @showing

exports.reload = ->
  dir = OSX.NSFileManager.defaultManager.currentDirectoryPath
  $('#project .cwd').text dir

  files = Dir.list dir
  listItems = _.map files, (path) ->
    filename = path.replace(dir, "").substring 1
    type = if Dir.isDir(path) then 'dir' else 'file'
    "<li class='#{type}' path='#{encodeURIComponent path}'>#{filename}</li>"

  $('#project .files').append listItems.join '\n'
