# {$} = require 'jQuery'
# {Chrome} = require 'lib/osx'

# awesome hover effect
if false
  $('#tabs ul li:not(".active") a').mousemove (e) ->
    originalBG = $(this).css("background-color")
    x  = e.pageX - @offsetLeft
    y  = e.pageY - @offsetTop
    xy = x + " " + y

    bgWebKit = "-webkit-gradient(radial, #{xy}, 0, #{xy}, 100, from(rgba(255,255,255,0.8)), to(rgba(255,255,255,0.0))), #{originalBG}"

    $(this).css background: bgWebKit

  $('#tabs ul li:not(".active") a').mouseleave (e) ->
    $(this).removeAttr 'style'

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