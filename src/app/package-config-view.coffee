semver = require 'semver'
packageManager = require 'package-manager'
{$$, View} = require 'space-pen'
requireWithGlobals 'bootstrap/js/bootstrap-dropdown', jQuery: require 'jquery'

### Internal ###

module.exports =
class PackageConfigView extends View
  @content: ->
    @div class: 'panel', =>
      @div outlet: 'heading', class: 'panel-heading', =>
        @span outlet: 'name'
        @span outlet: 'version', class: 'label'
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
  updateAvailable: false

  initialize: (@pack, @queue) ->
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
      repoUrl = (@pack.repository?.url ? '').replace(/.git$/, '')
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
      @defaultAction.disable()
      if @installed
        if @updateAvailable
          @defaultAction.text('Upgrading\u2026')
          packageManager.install @pack, => @updateInstallState()
        else
          @defaultAction.text('Uninstalling\u2026')
          packageManager.uninstall @pack, => @updateInstallState()
      else
        @defaultAction.text('Installing\u2026')
        packageManager.install @pack, => @updateInstallState()

    @updateInstallState()

    @enableToggle.find('a').on 'click', =>
      if atom.isPackageDisabled(@pack.name)
        config.removeAtKeyPath('core.disabledPackages', @pack.name)
      else
        config.pushAtKeyPath('core.disabledPackages', @pack.name)

    @observeConfig 'core.disabledPackages', => @updateEnabledState()

  updateEnabledState: ->
    enableLink = @enableToggle.find('a')
    if atom.isPackageDisabled(@pack.name)
      enableLink.text('Enable')
      @addClass('panel-warning')
    else
      enableLink.text('Disable')
      @removeClass('panel-warning')

    @enableToggle.hide() unless atom.isPackageLoaded(@pack.name)

  updateInstallState: ->
    @defaultAction.enable()
    @installed = atom.isPackageLoaded(@pack.name)
    @updateAvailable = @installed and semver.gt(@pack.version, atom.getLoadedPackage(@pack.name).metadata.version)
    if @installed
      if @updateAvailable
        @defaultAction.text('Upgrade')
      else
        @defaultAction.text('Uninstall')
    else
      @defaultAction.text('Install')
