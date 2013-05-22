path = require 'path'
_ = require 'underscore'
Package = require 'package'
ConfigPanel = require 'config-panel'
PackageConfigView = require 'package-config-view'
packageManager = require 'package-manager'

### Internal ###

module.exports =
class InstalledPackagesConfigPanel extends ConfigPanel
  @content: ->
    @div class: 'installed-packages', =>
      @div outlet: 'loadingArea', class: 'alert alert-info loading-area', =>
        @span 'Loading installed packages\u2026'

  initialize: ->
    packages = _.sortBy(atom.getAvailablePackageMetadata(), 'name')
    packageManager.renderMarkdownInMetadata packages, =>
      @loadingArea.hide()
      @append(new PackageConfigView(pack)) for pack in packages
      @trigger 'installed-packages-loaded', [packages]
