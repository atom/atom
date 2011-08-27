$ = require 'jquery'

$ ->
  dir = OSX.NSFileManager.defaultManager.currentDirectoryPath
  $('#cwd').text(dir)

  files = Dir.list(dir)
  files = _.map files, (file) ->
    listItems = _.map files, (file) ->
    file = file.replace(dir, "")
    "<li>#{file}</li>"

  $('#files').append(listItems.join('\n'))
