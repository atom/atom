path = require 'path'
_ = require 'underscore'
Package = require 'package'
ConfigPanel = require 'config-panel'
PackageConfigView = require 'package-config-view'

### Internal ###

module.exports =
class InstalledPackagesConfigPanel extends ConfigPanel
  @content: ->
    @div class: 'installed-packages'

  initialize: ->
    for packagePath in atom.getAvailablePackagePaths().sort()
      name = path.basename(packagePath)
      metadata = atom.getLoadedPackage(name)?.metadata
      unless metadata
        try
          metadata = Package.loadMetadata()
        catch e
          metadata = {name}
      @append(new PackageConfigView(metadata))
