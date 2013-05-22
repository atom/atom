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
    for metadata in _.sortBy(atom.getAvailablePackageMetadata(), 'name')
      @append(new PackageConfigView(metadata))
