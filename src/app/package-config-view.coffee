semver = require 'semver'
packageManager = require 'package-manager'
{$$, View} = require 'space-pen'
requireWithGlobals 'bootstrap/js/bootstrap-dropdown', jQuery: require 'jquery'

###
# Internal #
###

module.exports =
class PackageConfigView extends View
  @content: ->
    @div class: 'panel', =>
      @div outlet: 'heading', class: 'panel-heading', =>
        @span outlet: 'name'
        @div class: 'btn-group pull-right', =>
          @button outlet: 'defaultAction', class: 'btn btn-small btn-primary'
          @button outlet: 'dropdownButton', class: 'btn btn-small btn-primary dropdown-toggle', 'data-toggle': 'dropdown', =>
            @span class: 'caret'
          @ul outlet: 'dropdown', class: 'dropdown-menu', =>
            @li outlet: 'homepage', => @a 'Visit homepage'
            @li outlet: 'issues', => @a 'Report issue'
      @div outlet: 'description'
      @div outlet: 'versions'
      @ul class: 'list-group list-group-flush', =>
        @li outlet: 'readmeArea', class: 'list-group-item', =>
          @a 'Show README', outlet: 'readmeLink'
          @div class: 'readme', outlet: 'readme'

  installed: false
  updateAvailable: false

  initialize: (@pack, @queue) ->
    @name.text(@pack.name)

    installedVersion = atom.getLoadedPackage(@pack.name)?.getVersion()
    if installedVersion and @pack.version isnt installedVersion
      @versions.text("Version: #{@pack.version} (#{installedVersion} installed)")
    else
      @versions.text("Version: #{@pack.version}")

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

  updateInstallState: ->
    @defaultAction.enable()
    @installed = atom.isPackageLoaded(@pack.name)
    @updateAvailable = @installed and semver.gt(@pack.version, atom.getLoadedPackage(@pack.name).getVersion())
    if @installed
      if @updateAvailable
        @defaultAction.text('Upgrade')
      else
        @defaultAction.text('Uninstall')
    else
      @defaultAction.text('Install')
