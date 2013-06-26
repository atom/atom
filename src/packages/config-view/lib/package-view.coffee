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

  installed: false
  disabled: false
  bundled: false
  updateAvailable: false

  initialize: (@pack, @packageEventEmitter) ->
    @updatePackageState()

    @attr('name', @pack.name)
    @name.text(@pack.name)
    if version = semver.valid(@pack.version)
      @version.text(version)
    else
      @version.hide()

    if @pack.descriptionHtml
      @description.html(@pack.descriptionHtml)
    else if @pack.description
      @description.text(@pack.description)
    else
      @description.text('No further description available.')

    @readme.hide()
    if @pack.readmeHtml
      @readme.html(pack.readmeHtml)
    else if @pack.readme
      @readme.text(@pack.readme)
    else
      @readmeArea.hide()

    @readmeLink.on 'click', =>
      if @readme.isVisible()
        @readme.hide()
        @readmeLink.text('Show README')
      else
        @readme.show()
        @readmeLink.text('Hide README')

    homepage = @pack.homepage
    unless homepage
      if _.isString(@pack.repository)
        repoUrl = @pack.repository
      else
        repoUrl = @pack.repository?.url
      if repoUrl
        repoUrl = repoUrl.replace(/.git$/, '')
        homepage = repoUrl if require('url').parse(repoUrl).host is 'github.com'
    if homepage
      @homepage.find('a').attr('href', homepage)
    else
      @homepage.hide()

    if issues = @pack.bugs?.url
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
          packageManager.install @pack, (error) =>
            @packageEventEmitter.trigger('package-upgraded', error, @pack)
        else
          @defaultAction.text('Uninstalling\u2026')
          packageManager.uninstall @pack, (error) =>
            @packageEventEmitter.trigger('package-uninstalled', error, @pack)
      else
        @defaultAction.text('Installing\u2026')
        packageManager.install @pack, (error) =>
          @packageEventEmitter.trigger('package-installed', error, @pack)

    @updateDefaultAction()

    @enableToggle.find('a').on 'click', => @togglePackageEnablement()

    @observeConfig 'core.disabledPackages', =>
      @updatePackageState()
      @updateDefaultAction()
      @updateEnabledState()

    @packageEventEmitter.on 'package-installed package-uninstalled package-upgraded', (error, pack) =>
      if pack?.name is @pack.name
        @defaultAction.enable()
        @updatePackageState()
        @updateDefaultAction()

  togglePackageEnablement: ->
    if @disabled
      config.removeAtKeyPath('core.disabledPackages', @pack.name)
    else
      config.pushAtKeyPath('core.disabledPackages', @pack.name)

  updatePackageState: ->
    @disabled = atom.isPackageDisabled(@pack.name)
    @updateAvailable = false
    @bundled = false
    loadedPackage = atom.getLoadedPackage(@pack.name)
    packagePath = loadedPackage?.path ? atom.resolvePackagePath(@pack.name)
    @installed = packagePath?
    if @installed
      for packageDirPath in config.bundledPackageDirPaths
        if packagePath.indexOf("#{packageDirPath}/") is 0
          @bundled = true
          break

      version = loadedPackage?.metadata.version
      unless version
        try
          version = Package.loadMetadata(@pack.name).version
      @updateAvailable = semver.gt(@pack.version, version)

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
