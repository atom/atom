_ = require 'underscore'
ConfigPanel = require 'config-panel'
PackageConfigView = require 'package-config-view'

### Internal ###

module.exports =
class InstalledPackagesConfigPanel extends ConfigPanel
  @content: ->
    @div class: 'installed-packages'

  initialize: ->
    for pack in _.sortBy(atom.getLoadedPackages(), 'name')
      @append(new PackageConfigView(pack.metadata))
