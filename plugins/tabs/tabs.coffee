$ = require 'jquery'
_ = require 'underscore'

Pane = require 'pane'
{activeWindow} = require 'app'

module.exports =
class Tabs extends Pane
  position: 'top'
  html: require 'tabs/tabs.html'

  # The Editor pane we're managing.
  editor: null

  keymap:
    'Command-W': 'closeActiveTab'

  initialize: ->
    @editor = activeWindow.document

    @editor.ace.on 'open', ({filename}) =>
      # Only care about files, not directories
      return if not /\.\w+$/.test filename
      @addTab filename

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
    $('#tabs ul li:last').after """
      <li data-path='#{path}'><a href='#'>#{name}</a></li>
    """
    $('#tabs ul li:last').addClass 'active'

  closeActiveTab: ->
    activeTab = $('#tabs ul .active')
    nextTab = activeTab.next()
    nextTab = activeTab.prev() if nextTab.length == 0

    if nextTab.length != 0
      @editor.deleteSession activeTab.data 'path'
      activeTab.remove()
      @switchToTab nextTab

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
    $(tab).addClass 'active'
    @editor.switchToSession $(tab).data 'path'

  toggle: ->
    if $('#tabs').length
      @hideTabs()
    else
      @showTabs()
