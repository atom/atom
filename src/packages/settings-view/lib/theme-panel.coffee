{View, $$} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'

###
# Internal #
###

window.jQuery = $
require 'jqueryui-browser/ui/jquery.ui.core'
require 'jqueryui-browser/ui/jquery.ui.widget'
require 'jqueryui-browser/ui/jquery.ui.mouse'
require 'jqueryui-browser/ui/jquery.ui.sortable'
require 'jqueryui-browser/ui/jquery.ui.draggable'
delete window.jQuery

module.exports =
class ThemeConfigPanel extends View
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
    for name in atom.themes.getAvailableNames()
      @availableThemes.append(@buildThemeLi(name, draggable: true))

    @observeConfig "core.themes", (enabledThemes) =>
      @enabledThemes.empty()
      for name in enabledThemes ? []
        @enabledThemes.append(@buildThemeLi(name))

    @enabledThemes.sortable
      receive: (e, ui) => @enabledThemeReceived($(ui.helper))
      update: => @enabledThemesUpdated()

    @on "click", "#enabled-themes .disable-theme", (e) =>
      $(e.target).closest('li').remove()
      @enabledThemesUpdated()

  buildThemeLi: (name, {draggable} = {}) ->
    li = $$ ->
      @li class: 'list-group-item', name: name, =>
        @div class: 'disable-theme pull-right'
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
    name = helper.attr('name')
    @enabledThemes.find("[name='#{name}']:not('.ui-draggable')").remove()
    @enabledThemes.find(".ui-draggable").removeClass('ui-draggable')

  enabledThemesUpdated: ->
    config.set('core.themes', @getEnabledThemeNames())

  getEnabledThemeNames: ->
    $(li).attr('name') for li in @enabledThemes.children().toArray()
