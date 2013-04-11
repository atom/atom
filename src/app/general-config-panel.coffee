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
        @div class: 'list-wrapper', =>
          @div class: 'list-header', "Enabled Packages"
          @ol id: 'package-list', outlet: 'packageList'

      @div class: 'section', =>
        @div class: 'list-wrapper pull-left', =>
          @div class: 'list-header', "Enabled Themes"
          @ol id: 'enabled-theme-list', outlet: 'enabledThemeList'

        @div class: 'list-wrapper pull-left', =>
          @div class: 'list-header', "Available Themes"
          @ol id: 'available-theme-list', outlet: 'availableThemeList'

  initialize: ->
    @populatePackageList()
    @populateThemeLists()
    @packageList.on 'change', 'input[type=checkbox]', (e) ->
      checkbox = $(e.target)
      name = checkbox.closest('li').attr('name')
      if checkbox.attr('checked')
        _.remove(config.get('core.disabledPackages'), name)
      else
        config.get('core.disabledPackages').push(name)
      config.update()

  populatePackageList: ->
    for name in atom.getAvailablePackageNames()
      @packageList.append $$ ->
        @li name: name, =>
          @input type: 'checkbox'
          @span name

    @observeConfig 'core.disabledPackages', (disabledPackages) =>
      @updatePackageListCheckboxes(disabledPackages)

  updatePackageListCheckboxes: (disabledPackages=[]) ->
    @packageList.find("input[type='checkbox']").attr('checked', true)
    for name in disabledPackages
      @packageList.find("li[name='#{name}'] input[type='checkbox']").attr('checked', false)

  populateThemeLists: ->
    for name in atom.getAvailableThemeNames()
      @availableThemeList.append(
        $$(-> @li name: name, name).draggable(
          connectToSortable: '#enabled-theme-list'
          appendTo: '#general-config-panel'
          helper: 'clone'
        )
      )

    for name in config.get("core.themes")
      @enabledThemeList.append $$ ->
        @li name: name, name

    @enabledThemeList.sortable()
