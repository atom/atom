ConfigPanel = require 'config-panel'
{$$} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'

###
# Internal #
###

module.exports =
class PackageConfigPanel extends ConfigPanel
  @content: ->
    @div =>
      @legend "Installed Packages"

      @table id: 'packages', class: "table table-striped", =>
        @thead =>
          @tr =>
            @th "Package Name"
            @th class: 'package-enabled', "Enable"

        @tbody outlet: 'packageTableBody', =>
          for name in atom.getAvailablePackageNames().sort()
            @tr name: name, =>
              @td name
              @td class: 'package-enabled', => @input type: 'checkbox'

  initialize: ->
    @on 'change', '#packages input[type=checkbox]', (e) ->
      checkbox = $(e.target)
      name = checkbox.closest('tr').attr('name')
      if checkbox.attr('checked')
        _.remove(config.get('core.disabledPackages'), name)
      else
        config.get('core.disabledPackages').push(name)
      config.update()

    @observeConfig 'core.disabledPackages', (disabledPackages) =>
      @packageTableBody.find("input[type='checkbox']").attr('checked', true)
      for name in disabledPackages
        @packageTableBody.find("tr[name='#{name}'] input[type='checkbox']").attr('checked', false)
