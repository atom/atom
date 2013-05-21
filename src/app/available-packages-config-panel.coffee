PackageConfigView = require 'package-config-view'
ConfigPanel = require 'config-panel'
packages = require 'packages'

###
# Internal #
###

module.exports =
class AvailablePackagesConfigPanel extends ConfigPanel
  @content: ->
    @div class: 'available-packages'

  initialize: ->
    packages.getAvailable (error, packages) =>
      if error?
        console.error(error.stack ? error)
      else
        for pack in packages
          @append(new PackageConfigView(pack, @operationQueue))
        @trigger('available-packages-loaded', [packages])
