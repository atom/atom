$ = require 'jquery'
_ = require 'underscore'

{Chrome, Dir, File, Process} = require 'osx'
{bindKey} = require 'editor'

exports.init = ->
  @html = File.read(Chrome.appRoot() + "/plugins/project/project.html")

  bindKey 'toggleProjectDrawer', 'Command-Ctrl-N', (env) =>
    @toggle()

exports.toggle = ->
  if @showing
    $('#project').parent().remove()
  else
    Chrome.addPane 'left', @html
    @reload()

  @showing = not @showing

exports.reload = ->
  dir = OSX.NSFileManager.defaultManager.currentDirectoryPath
  $('#project .cwd').text(dir)

  files = Dir.list(dir)
  listItems = _.map files, (file) ->
    file = file.replace(dir, "")
    "<li>#{file}</li>"

  $('#project .files').append(listItems.join('\n'))
