PackageConfigView = require 'package-config-view'
ConfigPanel = require 'config-panel'
packageManager = require 'package-manager'

### Internal ###

module.exports =
class AvailablePackagesConfigPanel extends ConfigPanel
  @content: ->
    @div class: 'available-packages'

  initialize: ->
    packageManager.getAvailable (error, packages) =>
      if error?
        console.error(error.stack ? error)
      else
        for pack in packages
          @append(new PackageConfigView(pack, @operationQueue))
        @trigger('available-packages-loaded', [packages])
