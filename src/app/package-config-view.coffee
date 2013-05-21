{View} = require 'space-pen'

module.exports =
class PackageConfigView extends View
  @content: ->
    @div class: 'panel', =>
      @div outlet: 'heading', class: 'panel-heading', =>
        @span outlet: 'name'
        @button outlet: 'action', class: 'btn btn-small btn-primary pull-right'
      @div outlet: 'description'
      @div outlet: 'versions', class: 'panel-footer'

  initialize: (@pack, @queue) ->
    @versions.text("Version: #{@pack.version}")
    @name.text(@pack.name)
    if @pack.descriptionHtml
      @description.html(pack.descriptionHtml)
    else if @pack.description
      @description.text(@pack.description)
    else
      @description.text('No further description available.')

    @updateInstallState()

  updateInstallState: ->
    @installed = atom.packageExists(@pack.name)
    if @installed
      @action.text('Uninstall')
    else
      @action.text('Install')
