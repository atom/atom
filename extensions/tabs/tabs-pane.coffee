$ = require 'jquery'
_ = require 'underscore'

Pane = require 'pane'

module.exports =
class TabsPane extends Pane
  position: 'top'

  html: $ require 'tabs/tabs.html'

  constructor: ->
    # Style html
    @html.parents('.pane').css height: 'inherit'
    css = $('<style id="tabs-style"></style>').html require 'tabs/tabs.css'
    $('head').append css

    # click tab
    tabPane = this
    $('#tabs ul li').live 'mousedown', ->
      tabPane.switchToTab this
      false

  nextTab: ->
    @switchToTab $('#tabs ul .active').next()

  prevTab: ->
    @switchToTab $('#tabs ul .active').prev()

  switchToTab: (tab) ->
    tab = $("#tabs ul li").get(tab - 1) if _.isNumber tab
    return if tab.length is 0
    return if $(tab).is ".active"

    path = $(tab).data 'path'
    $("#tabs ul .active").removeClass("active")
    $(tab).addClass 'active'
    window.open path

  addTab: (path) ->
    existing = $("#tabs [data-path='#{path}']")
    return @switchToTab existing if existing.length

    name = _.last (path or 'untitled').split '/'

    $("#tabs ul .active").removeClass()
    $("#tabs ul").append """
      <li data-path='#{path}'><a href='#'>#{name}</a></li>
    """
    $("#tabs ul li:last").addClass 'active'

  closeActiveTab: ->
    tabsLength = $('#tabs ul li').length
    activePath = $('#tabs ul .active').data 'path'

    if tabsLength is 1
      @removeTab activePath
      $('#main-container').children().css 'display', 'none !important'
    else if tabsLength > 0
      @removeTab activePath
      @prevTab()
    else
      window.close()

  removeTab: (path) ->
    tab = $("#tabs li[data-path='#{path}']")
    if tab.hasClass("active")
      nextTab = tab.next()
      nextTab = tab.prev() if nextTab.length == 0
      @switchToTab nextTab if nextTab.length != 0

    tab.remove()
