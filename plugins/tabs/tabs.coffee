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
    'Command-Ctrl-T': 'toggle'

  initialize: ->
    @editor = activeWindow.document

    @editor.ace.on 'open', ({filename}) =>
      # Only care about files, not directories
      return if not /\.\w+$/.test filename
      @addTab filename

    tab = this
    # click tab
    $(document).delegate '#tabs ul a', 'click', ->
      tab.switchToTab this
      false

  addTab: (path) ->
    existing = $("#tabs [data-path='#{path}']")
    if existing.length
      return @switchToTab existing

    name = _.last path.split '/'
    $('#tabs ul .active').removeClass()
    $('#tabs ul li:last').after """
      <li><a data-path='#{path}' href='#'>#{name}</a></li>
    """
    $('#tabs ul li:last').addClass 'active'

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
    @editor.switchToSession $(tab).data 'path'

  toggle: ->
    if $('#tabs').length
      @hideTabs()
    else
      @showTabs()
