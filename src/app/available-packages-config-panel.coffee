PackageConfigView = require 'package-config-view'
ConfigPanel = require 'config-panel'
packageManager = require 'package-manager'

### Internal ###

module.exports =
class AvailablePackagesConfigPanel extends ConfigPanel
  @content: ->
    @div class: 'available-packages', =>
      @div outlet: 'loadingArea', class: 'alert alert-info loading-area', =>
        @span 'Loading available packages\u2026'

  initialize: ->
    packageManager.getAvailable (error, packages) =>
      @loadingArea.hide()
      if error?
        console.error(error.stack ? error)
      else
        for pack in packages
          @append(new PackageConfigView(pack))
        @trigger('available-packages-loaded', [packages])
