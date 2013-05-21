ConfigPanel = require 'config-panel'
InstalledPackagesConfigPanel = require 'installed-packages-config-panel'
AvailablePackagesConfigPanel = require 'available-packages-config-panel'

###
# Internal #
###

module.exports =
class PackageConfigPanel extends ConfigPanel
  @content: ->
    @div class: 'package-panel', =>
      @legend 'Packages'
      @ul class: 'nav nav-tabs', =>
        @li class: 'active', outlet: 'installedLink', =>
          @a 'Installed', =>
            @span class: 'badge pull-right', outlet: 'installedCount'
        @li outlet: 'availableLink', =>
          @a 'Available', =>
            @span class: 'badge pull-right', outlet: 'availableCount'
      @subview 'installed', new InstalledPackagesConfigPanel()
      @subview 'available', new AvailablePackagesConfigPanel()

  initialize: ->
    @available.hide()

    @installedLink.on 'click', =>
      @availableLink.removeClass('active')
      @available.hide()
      @installedLink.addClass('active')
      @installed.show()

    @availableLink.on 'click', =>
      @installedLink.removeClass('active')
      @installed.hide()
      @availableLink.addClass('active')
      @available.show()

    @installedCount.text(atom.getAvailablePackageNames().length)
    @available.on 'available-packages-loaded', (event, packages) =>
      console.log 'here', packages
      @availableCount.text(packages.length)
