$ = require 'jquery'
_ = require 'underscore'
{$$} = require 'space-pen'
ConfigPanel = require './config-panel'
AvailablePackagesConfigPanel = require './available-packages-config-panel'
EventEmitter = require 'event-emitter'
Editor = require 'editor'
PackageView = require './package-view'
packageManager = require './package-manager'
stringScore = require 'stringscore'


### Internal ###
class PackageEventEmitter
_.extend PackageEventEmitter.prototype, EventEmitter

module.exports =
class PackagePanel extends ConfigPanel
  @content: ->
    @div class: 'package-panel', =>
      @legend 'Packages'
      @ul class: 'nav nav-tabs', =>
        @li class: 'active', outlet: 'installedLink', =>
          @a 'Installed', =>
            @span class: 'badge pull-right', outlet: 'installedCount'
        @li outlet: 'availableLink', =>
          @a 'Available', =>
            @span class: 'badge pull-right', outlet: 'availableCount'

      @subview 'packageFilter', new Editor(mini: true, attributes: {id: 'package-filter'})
      @div outlet: 'installedViews'
      @div outlet: 'availableViews'

  initialize: ->
    @packageEventEmitter = new PackageEventEmitter()

    @availableViews.hide()
    @loadInstalledViews()
    @loadAvailableViews()

    @installedLink.on 'click', =>
      @availableLink.removeClass('active')
      @availableViews.hide()
      @installedLink.addClass('active')
      @installedViews.show()

    @availableLink.on 'click', =>
      @installedLink.removeClass('active')
      @installedViews.hide()
      @availableLink.addClass('active')
      @availableViews.show()

    @packageEventEmitter.on 'package-installed', (error, pack) =>
      @addPackage(pack) unless error?
      @updateInstalledCount()

    @packageEventEmitter.on 'package-uninstalled', (error, pack) =>
      @removePackage(pack) unless error?
      @updateInstalledCount()

    @packageFilter.getBuffer().on 'contents-modified', =>
      @filterPackages(@packageFilter.getText())

  loadInstalledViews: ->
    @installedViews.empty()
    @installedViews.append @createLoadingView('Loading installed packages\u2026')

    packages = _.sortBy(atom.getAvailablePackageMetadata(), 'name')
    packageManager.renderMarkdownInMetadata packages, =>
      @installedViews.empty()
      for pack in packages
        view = new PackageView(pack, @packageEventEmitter)
        @installedViews.append(view)

      @updateInstalledCount()

  loadAvailableViews: ->
    @availableViews.empty()
    @availableViews.append @createLoadingView('Loading installed packages\u2026')

    packageManager.getAvailable (error, @packages=[]) =>
      @availableViews.empty()
      if error?
        errorView = @createErrorView('Error fetching available packages.')
        errorView.on 'click', => @loadAvailableViews()
        @availableViews.append errorView
        console.error(error.stack ? error)
      else
        for pack in @packages
          view = new PackageView(pack, @packageEventEmitter)
          @availableViews.append(view)

      @updateAvailableCount()

  createLoadingView: (text) ->
    $$ ->
      @div class: 'alert alert-info loading-area', text

  createErrorView: (text) ->
    $$ ->
      @div class: 'alert alert-error', =>
        @span text
        @button class: 'btn btn-mini btn-retry', 'Retry'

  updateInstalledCount: ->
    @installedCount.text(@installedViews.children().length)

  updateAvailableCount: ->
    @availableCount.text(@availableViews.children().length)

  removePackage: ({name}) ->
    @installedViews.children("[name=#{name}]").remove()

  addPackage: (pack) ->
    packageNames = [pack.name]
    @installedViews.children().each (index, el) -> packageNames.push(el.getAttribute('name'))
    packageNames.sort()
    insertAfterIndex = packageNames.indexOf(pack.name) - 1

    view = new PackageView(pack, @packageEventEmitter)
    if insertAfterIndex < 0
      @installedViews.prepend(view)
    else
      @installedViews.children(":eq(#{insertAfterIndex})").after(view)

  filterPackages: (filterString) ->
    for children in [@installedViews.children(), @availableViews.children()]
      for packageView in children
        if /^\s*$/.test(filterString) or stringScore(packageView.getAttribute('name'), filterString)
          $(packageView).show()
        else
          $(packageView).hide()
