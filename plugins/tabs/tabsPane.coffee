$ = require 'jquery'
_ = require 'underscore'

Pane = require 'pane'
File = require 'fs'

module.exports =
class TabsPane extends Pane
  position: 'top'

  html: $ require 'tabs/tabs.html'

  constructor: (@window, @tabs) ->
    super @window

    # Style html
    @html.parents('.pane').css height: 'inherit'
    css = $('<style id="tabs-style"></style>').html require 'tabs/tabs.css'
    $('head').append css

    # click tab
    tabPane = this
    $('#tabs ul li').live 'click', ->
      tabPane.switchToTab this
      false

  switchToTab: (tab) ->
    tab = $("#tabs ul li").get(tab - 1) if _.isNumber tab
    return if tab.length is 0

    $("#tabs ul .active").removeClass("active")
    $(tab).addClass 'active'
    @window.open $(tab).data 'path'

  addTab: (path) ->
    existing = $("#tabs [data-path='#{path}']")
    if existing.length
      return @switchToTab existing

    name = _.last path.split '/'
    $("#tabs ul .active").removeClass()
    $("#tabs ul").append """
      <li data-path='#{path}'><a href='#'>#{name}</a></li>
    """
    $("#tabs ul li:last").addClass 'active'

  removeTab: (path) ->
    tab = $("#tabs li[data-path='#{path}']")
    if tab.hasClass("active")
      nextTab = tab.next()
      nextTab = tab.prev() if nextTab.length == 0
      @switchToTab nextTab if nextTab.length != 0

    tab.remove()
