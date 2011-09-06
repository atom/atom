$ = require 'jquery'
_ = require 'underscore'

Pane = require 'pane'
{activeWindow} = require 'app'

module.exports =
class Tabs extends Pane
  position: 'top'
  html: require 'tabs/tabs.html'

  keymap:
    'Command-Ctrl-T': 'toggle'

  initialize: ->
    tab = this
    # click tab
    $(document).delegate '#tabs ul a', 'click', ->
      tab.switchToTab this
      false

  addTab: ->
    $('#tabs ul .add').before '<li><a href="#">untitled</a></li>'
    $('#tabs ul .active').removeClass()
    $('#tabs ul .add').prev().addClass 'active'

  hideTabs: ->
    $('#tabs').parents('.pane').remove()
    $('#tabs-style').remove()

  showTabs: ->
    activeWindow.addPane this
    $('#tabs').parents('.pane').css height: 'inherit'
    css = $('<style id="tabs-style"></style>').html require 'tabs/tabs.css'
    $('head').append css

  switchToTab: (tab) ->
    $('#tabs ul .active').removeClass()
    $(tab).parents('li').addClass 'active'

  toggle: ->
    if $('#tabs').length
      @hideTabs()
    else
      @showTabs()
