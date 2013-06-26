ConfigPanel = require './config-panel'
InstalledPackagesConfigPanel = require './installed-packages-config-panel'
AvailablePackagesConfigPanel = require './available-packages-config-panel'
_ = require 'underscore'
EventEmitter = require 'event-emitter'
Editor = require 'editor'

### Internal ###
class PackageEventEmitter
_.extend PackageEventEmitter.prototype, EventEmitter

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

      @subview 'packageFilter', new Editor(mini: true, attributes: {id: 'package-filter'})

  initialize: ->
    @packageEventEmitter = new PackageEventEmitter()
    @installed = new InstalledPackagesConfigPanel(@packageEventEmitter)
    @available = new AvailablePackagesConfigPanel(@packageEventEmitter)
    @append(@installed, @available)

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

    @packageEventEmitter.on 'installed-packages-loaded package-installed package-uninstalled', =>
      @installedCount.text(@installed.getPackageCount())

    @packageEventEmitter.on 'available-packages-loaded', =>
      @availableCount.text(@available.getPackageCount())

    @packageFilter.getBuffer().on 'contents-modified', =>
      @available.filterPackages(@packageFilter.getText())
      @installed.filterPackages(@packageFilter.getText())
