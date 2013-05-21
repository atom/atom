semver = require 'semver'
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
          @button outlet: 'action', class: 'btn btn-small btn-primary'
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

  initialize: (@pack, @queue) ->
    @name.text(@pack.name)

    installedVersion = atom.getLoadedPackage(@pack.name)?.getVersion()
    if installedVersion
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

    @dropdown.on 'click', => @dropdown.hide()

    @updateInstallState()

  updateInstallState: ->
    installedPackage = atom.getLoadedPackage(@pack.name)
    if installedPackage
      if semver.gt(@pack.version, installedPackage.getVersion())
        @action.text('Upgrade')
      else
        @action.text('Uninstall')
    else
      @action.text('Install')
