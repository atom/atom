ConfigPanel = require 'config-panel'
{$$} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'

window.jQuery = $
require 'jqueryui-browser/ui/jquery.ui.core'
require 'jqueryui-browser/ui/jquery.ui.widget'
require 'jqueryui-browser/ui/jquery.ui.mouse'
require 'jqueryui-browser/ui/jquery.ui.sortable'
require 'jqueryui-browser/ui/jquery.ui.draggable'
delete window.jQuery

module.exports =
class ThemeConfigPanel extends ConfigPanel
  @content: ->
    @div id: 'themes-config', =>
      @legend "Themes"
      @div id: 'theme-picker', =>
        @div class: 'panel', =>
          @div class: 'panel-heading', "Enabled Themes"
          @ol id: 'enabled-themes', class: 'list-group list-group-flush', outlet: 'enabledThemes'
        @div class: 'panel', =>
          @div class: 'panel-heading', "Available Themes"
          @ol id: 'available-themes', class: 'list-group list-group-flush', outlet: 'availableThemes'

  constructor: ->
    super
    for name in atom.getAvailableThemeNames()
      @availableThemes.append(@buildThemeLi(name, draggable: true))

    for name in config.get("core.themes") ? []
      @enabledThemes.append(@buildThemeLi(name))

    @enabledThemes.sortable
      receive: (e, ui) => @enabledThemeReceived($(ui.helper))
      update: => @enabledThemesUpdated()

  buildThemeLi: (name, {draggable} = {}) ->
    li = $$ ->
      @li class: 'list-group-item', name: name, =>
        @div class: 'octicons close-icon pull-right'
        @text name
    if draggable
      li.draggable
        connectToSortable: '#enabled-themes'
        appendTo: '#themes-config'
        helper: (e) ->
          target = $(e.target)
          target.clone().width(target.width())
    else
      li

  enabledThemeReceived: (helper) ->
    console.log "RECEIVE", helper
    name = helper.attr('name')
    @enabledThemes.find("[name='#{name}']:not('.ui-draggable')").remove()
    @enabledThemes.find(".ui-draggable").removeClass('ui-draggable')

  enabledThemesUpdated: ->
    console.log "enabledThemesUpdated"
    console.log @getEnabledThemeNames()
    config.set('core.themes', @getEnabledThemeNames())

  getEnabledThemeNames: ->
    $(li).attr('name') for li in @enabledThemes.children().toArray()
