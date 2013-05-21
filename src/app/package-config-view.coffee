{$$, View} = require 'space-pen'
requireWithGlobals 'bootstrap/js/bootstrap-dropdown', jQuery: require 'jquery'

module.exports =
class PackageConfigView extends View
  @content: ->
    @div class: 'panel', =>
      @div outlet: 'heading', class: 'panel-heading', =>
        @span outlet: 'name'
        @div class: 'btn-group pull-right', =>
          @button outlet: 'action', class: 'btn btn-small btn-primary'
          @button class: 'btn btn-small btn-primary dropdown-toggle', 'data-toggle': 'dropdown', =>
            @span class: 'caret'
          @ul class: 'dropdown-menu', outlet: 'dropdown'
      @div outlet: 'description'
      @div outlet: 'versions'
      @ul class: 'list-group list-group-flush', =>
        @li outlet: 'readmeArea', class: 'list-group-item', =>
          @a 'Show README', outlet: 'readmeLink'
          @div class: 'readme', outlet: 'readme'

  initialize: (@pack, @queue) ->
    @versions.text("Version: #{@pack.version}")
    @name.text(@pack.name)

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
      @dropdown.append $$ ->
        @li =>
          @a "Visit homepage", href: homepage

    if issues = @pack.bugs?.url
      @dropdown.append $$ ->
        @li =>
          @a "Report issue", href: issues

    @dropdown.on 'click', => @dropdown.hide()

    @updateInstallState()

  updateInstallState: ->
    @installed = atom.packageExists(@pack.name)
    if @installed
      @action.text('Uninstall')
    else
      @action.text('Install')
