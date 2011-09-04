$ = require 'jquery'
_ = require 'underscore'

{activeWindow} = require 'app'
{bindKey} = require 'keybinder'


# click tab
$(document).delegate '#tabs ul li:not(.add) a', 'click', ->
  tabs.switchToTab this
  false

# click 'add' tab
$(document).delegate '#tabs .add a', 'click', ->
  tabs.addTab()
  false

# toggle
bindKey 'toggleTabs', 'Command-Ctrl-T', ->
  if $('#tabs').length
    tabs.hideTabs()
  else
    tabs.showTabs()


module.exports = tabs =
  showTabs: ->
    activeWindow.addPane 'top', require 'tabs/tabs.html'
    $('#tabs').parents('.pane').css height: 'inherit'
    css = $('<style id="tabs-style"></style>').html require 'tabs/tabs.css'
    $('head').append css

  hideTabs: ->
    $('#tabs').parents('.pane').remove()
    $('#tabs-style').remove()

  addTab: ->
    $('#tabs ul .add').before '<li><a href="#">untitled</a></li>'
    $('#tabs ul .active').removeClass()
    $('#tabs ul .add').prev().addClass 'active'

  switchToTab: (tab) ->
    $('#tabs ul .active').removeClass()
    $(tab).parents('li').addClass 'active'