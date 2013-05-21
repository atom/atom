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
          @a 'Installed'
        @li outlet: 'availableLink', =>
          @a 'Available'
      @subview 'installed', new InstalledPackagesConfigPanel()
      @subview 'available', new AvailablePackagesConfigPanel()

  initialize: ->
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
