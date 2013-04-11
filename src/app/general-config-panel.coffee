ConfigPanel = require 'config-panel'
{$$} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class GeneralConfigPanel extends ConfigPanel
  @content: ->
    @div class: 'config-panel', =>
      @div class: 'row', =>
        @label for: 'core.hideGitIgnoredFiles', "Hide files in .gitignore:"
        @input id: 'core.hideGitIgnoredFiles', type: 'checkbox'

      @div class: 'row', =>
        @label for: 'core.autosave', "Autosave on unfocus:"
        @input id: 'core.autosave', type: 'checkbox'

      @div class: 'row', =>
        @div "Packages"
        @ol id: 'package-list', outlet: 'packageList'

      @div class: 'row', =>
        @div "Themes"
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
      @availableThemeList.append $$ ->
        @li name: name, name
