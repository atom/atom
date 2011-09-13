$ = require 'jquery'
_ = require 'underscore'

{activeWindow} = require 'app'
File = require 'fs'
Pane = require 'pane'

module.exports =
class Project extends Pane
  showing: false

  position: 'left'

  html:
    $ require "project/project.html"

  keymap:
    'Command-Ctrl-N': 'toggle'

  initialize: ->
    @reload(File.workingDirectory())

    activeWindow.document.ace.on 'open', ({filename}) =>
      @reload filename if File.isDirectory filename

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

  reload: (dir) ->
    @dir = dir
    @html.children('#project .cwd').text _.last @dir.split '/'
    @html.children('#project .files').empty()
    @html.children('#project .files').append @createList @dir

  createList: (dir) ->
    files = File.list dir
    listItems = _.map files, (path) ->
      filename = path.replace(dir, "").substring 1
      type = if File.isDirectory(path) then 'dir' else 'file'
      path = encodeURIComponent path
      "<li class='#{type}' path='#{path}'>#{filename}</li>"

    listItems.join '\n'
