$ = require 'jquery'
_ = require 'underscore'
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

      @div outlet: 'loadingArea', class: 'alert alert-info loading-area', =>
        @span 'Loading installed packages\u2026'

      @div outlet: 'installedViews'


  initialize: ->
    @packageEventEmitter = new PackageEventEmitter()

    @createInstalledViews()

    @available = new AvailablePackagesConfigPanel(@packageEventEmitter)
    @append(@available)

    @available.hide()

    @installedLink.on 'click', =>
      @availableLink.removeClass('active')
      @available.hide()
      @installedLink.addClass('active')
      @installedViews.show()

    @availableLink.on 'click', =>
      @installedLink.removeClass('active')
      @installedViews.hide()
      @availableLink.addClass('active')
      @available.show()

    @packageEventEmitter.on 'available-packages-loaded', =>
      @availableCount.text(@available.getPackageCount())

    @packageFilter.getBuffer().on 'contents-modified', =>
      @available.filterPackages(@packageFilter.getText())
      @filterPackages(@packageFilter.getText())

    @packageEventEmitter.on 'package-installed', (error, pack) =>
      @addPackage(pack) unless error?
      @updateInstalledCount()

    @packageEventEmitter.on 'package-uninstalled', (error, pack) =>
      @removePackage(pack) unless error?
      @updateInstalledCount()

  createInstalledViews: ->
    @loadingArea.show()
    packages = _.sortBy(atom.getAvailablePackageMetadata(), 'name')
    packageManager.renderMarkdownInMetadata packages, =>
      @loadingArea.hide()
      for pack in packages
        view = new PackageView(pack, @packageEventEmitter)
        @installedViews.append(view)

      @updateInstalledCount()

  updateInstalledCount: ->
    @installedCount.text(@installedViews.children().length)

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
    for packageView in @installedViews.children()
      if /^\s*$/.test(filterString) or stringScore(packageView.getAttribute('name'), filterString)
        $(packageView).show()
      else
        $(packageView).hide()
