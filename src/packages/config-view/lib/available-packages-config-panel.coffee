{View} = require 'space-pen'
$ = require 'jquery'
PackageConfigView = require './package-config-view'
packageManager = require './package-manager'
stringScore = require 'stringscore'

### Internal ###
module.exports =
class AvailablePackagesConfigPanel extends View
  @content: ->
    @div class: 'available-packages', =>
      @div outlet: 'loadingArea', class: 'alert alert-info loading-area', =>
        @span 'Loading available packages\u2026'
      @div outlet: 'errorArea', class: 'alert alert-error', =>
        @span 'Error fetching available packages.'
        @button outlet: 'retry', class: 'btn btn-mini btn-retry', 'Retry'
      @div outlet: 'packagesArea'

  initialize: (@packageEventEmitter) ->
    @retry.on 'click', => @refresh()
    @refresh()

  refresh: ->
    @loadingArea.show()
    @errorArea.hide()

    packageManager.getAvailable (error, @packages=[]) =>
      @loadingArea.hide()
      if error?
        @errorArea.show()
        console.error(error.stack ? error)
      else
        @packagesArea.empty()
        for pack in @packages
          @packagesArea.append(new PackageConfigView(pack, @packageEventEmitter))
      @packageEventEmitter.trigger('available-packages-loaded', @packages)

  filterPackages: (filterString) ->
    packageViews = @packagesArea.children()
    for packageView in packageViews
      if /^\s*$/.test(filterString) or stringScore(packageView.getAttribute('name'), filterString)
        $(packageView).show()
      else
        $(packageView).hide()

  getPackageCount: -> @packages.length
