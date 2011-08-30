$ = require 'jquery'
_ = require 'underscore'

{Chrome, File, Dir, Process} = require 'osx'
{bindKey} = require 'editor'


# click tab
$(document).delegate '#tabs ul li:not(.add) a', 'click', ->
  switchToTab this
  false

# click 'add' tab
$(document).delegate '#tabs .add a', 'click', ->
  addTab()
  false

# toggle
bindKey 'toggleTabs', 'Command-Ctrl-T', (env) ->
  if $('#tabs').length
    hideTabs()
  else
    showTabs()


showTabs = ->
  Chrome.addPane 'top', require('tabs/tabs.html')
  $('#tabs').parents('.pane').css height: 'inherit'
  css = $('<style id="tabs-style"></style>').html require 'tabs/tabs.css'
  $('head').append css

hideTabs = ->
  $('#tabs').parents('.pane').remove()
  $('#tabs-style').remove()

addTab = ->
  $('#tabs ul .add').before '<li><a href="#">untitled</a></li>'
  $('#tabs ul .active').removeClass()
  $('#tabs ul .add').prev().addClass 'active'

switchToTab = (tab) ->
  $('#tabs ul .active').removeClass()
  $(tab).parents('li').addClass 'active'


exports.show = exports.showTabs = showTabs
exports.hideTabs = hideTabs
exports.addTab = addTab
exports.switchToTab = switchToTab