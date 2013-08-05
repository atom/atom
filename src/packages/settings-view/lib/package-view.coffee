Package = require 'package'
semver = require 'semver'
packageManager = require './package-manager'
_ = require 'underscore'
{$$, View} = require 'space-pen'
requireWithGlobals 'bootstrap/js/bootstrap-dropdown', jQuery: require 'jquery'

### Internal ###
module.exports =
class PackageView extends View
  @content: ->
    @div class: 'panel', =>
      @div outlet: 'heading', class: 'panel-heading', =>
        @span outlet: 'name'
        @span outlet: 'version', class: 'label'
        @span outlet: 'update', class: 'label label-info', 'Update Available'
        @span outlet: 'disabedLabel', class: 'label label-warning', 'Disabled'
        @div class: 'btn-group pull-right', =>
          @button outlet: 'defaultAction', class: 'btn btn-small btn-primary'
          @button outlet: 'dropdownButton', class: 'btn btn-small btn-primary dropdown-toggle', 'data-toggle': 'dropdown', =>
            @span class: 'caret'
          @ul outlet: 'dropdown', class: 'dropdown-menu', =>
            @li outlet: 'enableToggle', => @a 'Disable'
            @li outlet: 'homepage', => @a 'Visit homepage'
            @li outlet: 'issues', => @a 'Report issue'
      @div outlet: 'description'
      @ul class: 'list-group list-group-flush', =>
        @li outlet: 'readmeArea', class: 'list-group-item', =>
          @a 'Show README', outlet: 'readmeLink'
          @div class: 'readme', outlet: 'readme'

  pack: null
  metadata: null
  installed: false
  disabled: false
  bundled: false
  updateAvailable: false

  initialize: (pack, @packageEventEmitter) ->
    if pack instanceof Package
      @pack = pack
      @metadata = @pack.metadata
    else
      @metadata = pack

    @updatePackageState()

    @attr('name', @metadata.name)
    @name.text(@metadata.name)
    if version = semver.valid(@metadata.version)
      @version.text(version)
    else
      @version.hide()

    if @metadata.descriptionHtml
      @description.html(@metadata.descriptionHtml)
    else if @metadata.description
      @description.text(@metadata.description)
    else
      @description.text('No further description available.')

    @readme.hide()
    if @metadata.readmeHtml
      @readme.html(@metadata.readmeHtml)
    else if @metadata.readme
      @readme.text(@metadata.readme)
    else
      @readmeArea.hide()

    @readmeLink.on 'click', =>
      if @readme.isVisible()
        @readme.hide()
        @readmeLink.text('Show README')
      else
        @readme.show()
        @readmeLink.text('Hide README')

    homepage = @metadata.homepage
    unless homepage
      if _.isString(@metadata.repository)
        repoUrl = @metadata.repository
      else
        repoUrl = @metadata.repository?.url
      if repoUrl
        repoUrl = repoUrl.replace(/.git$/, '')
        homepage = repoUrl if require('url').parse(repoUrl).host is 'github.com'
    if homepage
      @homepage.find('a').attr('href', homepage)
    else
      @homepage.hide()

    if issues = @metadata.bugs?.url
      @issues.find('a').attr('href', issues)
    else
      @issues.hide()

    @defaultAction.on 'click', =>
      if @installed and @bundled
        @togglePackageEnablement()
        return


      @defaultAction.disable()
      if @installed
        if @updateAvailable
          @defaultAction.text('Upgrading\u2026')
          packageManager.install @metadata, (error) =>
            @packageEventEmitter.trigger('package-upgraded', error, @metadata)
        else
          @defaultAction.text('Uninstalling\u2026')
          packageManager.uninstall @metadata, (error) =>
            @packageEventEmitter.trigger('package-uninstalled', error, @metadata)
      else
        @defaultAction.text('Installing\u2026')
        packageManager.install @metadata, (error) =>
          @packageEventEmitter.trigger('package-installed', error, @metadata)

    @updateDefaultAction()

    @enableToggle.find('a').on 'click', => @togglePackageEnablement()

    @observeConfig 'core.disabledPackages', =>
      @updatePackageState()
      @updateDefaultAction()
      @updateEnabledState()

    @packageEventEmitter.on 'package-installed package-uninstalled package-upgraded', (error, metadata) =>
      if metadata?.name is @metadata.name
        @defaultAction.enable()
        @updatePackageState()
        @updateDefaultAction()

  togglePackageEnablement: ->
    if @disabled
      config.removeAtKeyPath('core.disabledPackages', @metadata.name)
    else
      config.pushAtKeyPath('core.disabledPackages', @metadata.name)

  updatePackageState: ->
    @disabled = atom.isPackageDisabled(@metadata.name)
    @updateAvailable = false
    @bundled = false
    loadedPackage = atom.getLoadedPackage(@metadata.name)
    packagePath = loadedPackage?.path ? atom.resolvePackagePath(@metadata.name)
    @installed = packagePath?
    if @installed
      for packageDirPath in config.bundledPackageDirPaths
        if packagePath.indexOf("#{packageDirPath}/") is 0
          @bundled = true
          break

      version = loadedPackage?.metadata.version
      unless version
        try
          version = Package.loadMetadata(@metadata.name).version
      @updateAvailable = semver.gt(@metadata.version, version)

    if @updateAvailable
      @update.show()
    else
      @update.hide()

  updateEnabledState: ->
    enableLink = @enableToggle.find('a')
    if @disabled
      enableLink.text('Enable')
      @disabedLabel.show()
    else
      enableLink.text('Disable')
      @disabedLabel.hide()

    @enableToggle.hide() unless @installed

  updateDefaultAction: ->
    if @installed
      if @bundled
        if @disabled
          @defaultAction.text('Enable')
        else
          @defaultAction.text('Disable')
      else
        if @updateAvailable
          @defaultAction.text('Upgrade')
        else
          @defaultAction.text('Uninstall')
    else
      @defaultAction.text('Install')
