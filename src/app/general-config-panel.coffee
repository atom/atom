ConfigPanel = require 'config-panel'
{$$} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class GeneralConfigPanel extends ConfigPanel
  @content: ->
    @div id: 'general-config-panel', class: 'config-panel', =>
      @div class: 'row', =>
        @label for: 'core.hideGitIgnoredFiles', "Hide files in .gitignore:"
        @input id: 'core.hideGitIgnoredFiles', type: 'checkbox'

      @div class: 'row', =>
        @label for: 'core.autosave', "Autosave on unfocus:"
        @input id: 'core.autosave', type: 'checkbox'

      @div class: 'section', =>
        @div class: 'list-wrapper pull-left', =>
          @div class: 'list-header', "Enabled Themes (Drag from right)"
          @ol id: 'enabled-theme-list', outlet: 'enabledThemeList'

        @div class: 'list-wrapper pull-left', =>
          @div class: 'list-header', "Available Themes"
          @ol id: 'available-theme-list', outlet: 'availableThemeList'

  populateThemeLists: ->
    for name in atom.getAvailableThemeNames()
      @availableThemeList.append(@buildThemeLi(name, draggable: true))

    for name in config.get("core.themes") ? []
      @enabledThemeList.append(@buildThemeLi(name))

    @enabledThemeList.sortable()

  buildThemeLi: (name, {draggable} = {}) ->
    li = $$ ->
      @li name: name, =>
        @div class: 'octicons close-icon pull-right'
        @text name
    if draggable
      li.draggable
        connectToSortable: '#enabled-theme-list'
        appendTo: '#general-config-panel'
        helper: 'clone'
    li
