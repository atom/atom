_ = require 'vendor/underscore'
$ = require 'vendor/jquery'

{Chrome, File, Dir, Process} = require 'lib/osx'

exports.show = ->
  root = OSX.NSBundle.mainBundle.resourcePath + '/HTML/'
  tabs = OSX.NSString.stringWithContentsOfFile "#{root}/tabs.html"
  edit = OSX.NSString.stringWithContentsOfFile "#{root}/editor.html"

  Chrome.addPane 'main', tabs.replace '<%= editor %>', edit

  # events
  $('#tabs ul li:not(.add) a').live 'click', ->
    $('#tabs ul .active').removeClass()
    $(this).parents('li').addClass 'active'

    idx = $('#tabs ul a').index this
    $('.content iframe').hide().eq(idx).show().focus()

    false

  $('#tabs .add a').click ->
    $('#tabs ul .active').removeClass()
    $('#tabs ul .add').before '<li><a href="#">untitled</a></li>'

    $('.content iframe').hide()
    $('.content').append '<iframe src="editor.html" width="100%" height="100%"></iframe>'

    $('#tabs ul .add').prev().addClass 'active'

    false
