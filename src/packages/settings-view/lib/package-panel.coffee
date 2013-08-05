$ = require 'jquery'
_ = require 'underscore'
{View, $$} = require 'space-pen'
EventEmitter = require 'event-emitter'
Editor = require 'editor'
PackageView = require './package-view'
packageManager = require './package-manager'
stringScore = require 'stringscore'


### Internal ###
class PackageEventEmitter
_.extend PackageEventEmitter.prototype, EventEmitter

module.exports =
class PackagePanel extends View
  @content: ->
    @div class: 'package-panel', =>
      @legend 'Packages'
      @ul class: 'nav nav-tabs', =>
        @li class: 'active', =>
          @a 'Installed', =>
            @span class: 'badge pull-right', outlet: 'installedCount'
        @li =>
          @a 'Available', =>
            @span class: 'badge pull-right', outlet: 'availableCount'

      @subview 'packageFilter', new Editor(mini: true, attributes: {id: 'package-filter'})
      @div outlet: 'installedPackages'
      @div outlet: 'availablePackages'

  initialize: ->
    @packageEventEmitter = new PackageEventEmitter()

    @availablePackages.hide()
    @loadInstalledViews()
    @loadAvailableViews()

    @find('.nav-tabs li').on 'click', (event) =>
      return if $(event.currentTarget).hasClass('active')
      @find('.nav-tabs li').toggleClass('active')
      @availablePackages.toggle()
      @installedPackages.toggle()

    @packageEventEmitter.on 'package-installed', (error, pack) =>
      @addInstalledPackage(pack) unless error?

    @packageEventEmitter.on 'package-uninstalled', (error, pack) =>
      @removeInstalledPackage(pack) unless error?

    @packageFilter.getBuffer().on 'contents-modified', =>
      @filterPackages(@packageFilter.getText())

  loadInstalledViews: ->
    @installedPackages.empty()
    @installedPackages.append @createLoadingView('Loading installed packages\u2026')

    packages = _.sortBy(atom.getAvailablePackageMetadata(), 'name')
    packageManager.renderMarkdownInMetadata packages, =>
      @installedPackages.empty()
      for pack in packages
        view = new PackageView(pack, @packageEventEmitter)
        @installedPackages.append(view)

      @updateInstalledCount()

  loadAvailableViews: ->
    @availablePackages.empty()
    @availablePackages.append @createLoadingView('Loading available packages\u2026')

    packageManager.getAvailable (error, @packages=[]) =>
      @availablePackages.empty()
      if error?
        errorView = @createErrorView('Error fetching available packages.')
        errorView.on 'click', => @loadAvailableViews()
        @availablePackages.append errorView
        console.error(error.stack ? error)
      else
        for pack in @packages
          view = new PackageView(pack, @packageEventEmitter)
          @availablePackages.append(view)

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
    @installedCount.text(@installedPackages.children().length)

  updateAvailableCount: ->
    @availableCount.text(@availablePackages.children().length)

  removeInstalledPackage: ({name}) ->
    @installedPackages.children("[name=#{name}]").remove()
    @updateInstalledCount()

  addInstalledPackage: (pack) ->
    packageNames = [pack.name]
    @installedPackages.children().each (index, el) -> packageNames.push(el.getAttribute('name'))
    packageNames.sort()
    insertAfterIndex = packageNames.indexOf(pack.name) - 1

    view = new PackageView(pack, @packageEventEmitter)
    if insertAfterIndex < 0
      @installedPackages.prepend(view)
    else
      @installedPackages.children(":eq(#{insertAfterIndex})").after(view)

    @updateInstalledCount()

  filterPackages: (filterString) ->
    for children in [@installedPackages.children(), @availablePackages.children()]
      for packageView in children
        name = packageView.getAttribute('name')
        continue unless name
        if /^\s*$/.test(filterString) or stringScore(name, filterString)
          $(packageView).show()
        else
          $(packageView).hide()
