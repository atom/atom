$ = require 'jquery'
_ = require 'underscore'

Pane = require 'pane'
File = require 'fs'
{activeWindow} = require 'app'

module.exports =
class Tabs extends Pane
  position: 'top'
  html: require 'tabs/tabs.html'

  # The Editor pane we're managing.
  editor: null

  keymap:
    'Command-W': 'closeActiveTab'
    'Command-Shift-[': 'prevTab'
    'Command-Shift-]': 'nextTab'
    'Command-1': -> @switchToTab 1
    'Command-2': -> @switchToTab 2
    'Command-3': -> @switchToTab 3
    'Command-4': -> @switchToTab 4
    'Command-5': -> @switchToTab 5
    'Command-6': -> @switchToTab 6
    'Command-7': -> @switchToTab 7
    'Command-8': -> @switchToTab 8
    'Command-9': -> @switchToTab 9

  initialize: ->
    @editor = activeWindow.document

    @editor.ace.on 'open', ({filename}) =>
      # Only care about files, not directories
      return if File.isDirectory(filename)
      @addTab filename
      
    @editor.ace.on 'close', ({filename}) =>
      @removeTab filename

    tab = this
    # click tab
    $(document).delegate '#tabs ul li', 'click', ->
      tab.switchToTab this
      false

  addTab: (path) ->
    existing = $("#tabs [data-path='#{path}']")
    if existing.length
      return @switchToTab existing

    name = _.last path.split '/'
    $('#tabs ul .active').removeClass()
    $('#tabs ul').append """
      <li data-path='#{path}'><a href='#'>#{name}</a></li>
    """
    $('#tabs ul li:last').addClass 'active'

  removeTab: (path) ->
    tab = $("#tabs li[data-path='#{path}']")
    if tab.hasClass("active")
      nextTab = tab.next()
      nextTab = tab.prev() if nextTab.length == 0
      @switchToTab nextTab if nextTab.length != 0
    
    tab.remove()

  closeActiveTab: ->
    activeTab = $('#tabs ul .active')
    @editor.close(activeTab.data 'path')

  hideTabs: ->
    $('#tabs').parents('.pane').remove()
    $('#tabs-style').remove()

  nextTab: ->
    @switchToTab $('#tabs ul .active').next()

  prevTab: ->
    @switchToTab $('#tabs ul .active').prev()

  showTabs: ->
    activeWindow.addPane this
    $('#tabs').parents('.pane').css height: 'inherit'
    css = $('<style id="tabs-style"></style>').html require 'tabs/tabs.css'
    $('head').append css

  switchToTab: (tab) ->
    tab = $('#tabs ul li').get(tab - 1) if _.isNumber tab
    return if tab.length is 0
    $('#tabs ul .active').removeClass()
    $(tab).addClass 'active'
    @editor.switchToSession $(tab).data 'path'

  toggle: ->
    if $('#tabs').length
      @hideTabs()
    else
      @showTabs()
