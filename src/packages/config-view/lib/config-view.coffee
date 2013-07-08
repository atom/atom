{$$} = require 'space-pen'
ScrollView = require 'scroll-view'
$ = require 'jquery'
_ = require 'underscore'
Pane = require 'pane'
SettingsPanel = require './settings-panel'
ThemePanel = require './theme-panel'
PackagePanel = require './package-panel'
Project = require 'project'

configUri = "atom://config"

###
# Internal #
###

module.exports =
class ConfigView extends ScrollView
  registerDeserializer(this)

  @activate: (state) ->
    Project.registerOpener (filePath) ->
      new ConfigView() if filePath is configUri

    rootView.command 'config-view:toggle', ->
      rootView.open(configUri)

  @deserialize: ({activePanelName}={}) ->
    new ConfigView(activePanelName)

  @content: ->
    @div id: 'config-view', tabindex: -1, =>
      @div id: 'config-menu', =>
        @ul id: 'panels-menu', class: 'nav nav-pills nav-stacked', outlet: 'panelMenu'
        @button "open .atom", id: 'open-dot-atom', class: 'btn btn-default btn-small'
      @div id: 'panels', outlet: 'panels'

  activePanelName: null

  initialize: (activePanelName) ->
    super
    @panelsByName = {}
    document.title = "Atom Configuration"
    @on 'click', '#panels-menu li a', (e) =>
      @showPanel($(e.target).closest('li').attr('name'))

    @on 'click', '#open-dot-atom', ->
      atom.open(config.configDirPath)

    @addPanel('Settings', new SettingsPanel)
    @addPanel('Themes', new ThemePanel)
    @addPanel('Packages', new PackagePanel)
    @showPanel(activePanelName) if activePanelName

  serialize: ->
    deserializer: 'ConfigView'
    activePanelName: @activePanelName

  addPanel: (name, panel) ->
    panelItem = $$ -> @li name: name, => @a name
    @panelMenu.append(panelItem)
    panel.hide()
    @panelsByName[name] = panel
    @panels.append(panel)
    @showPanel(name) if @getPanelCount() is 1 or @panelToShow is name

  getPanelCount: ->
    _.values(@panelsByName).length

  showPanel: (name) ->
    if @panelsByName[name]
      @panels.children().hide()
      @panelMenu.children('.active').removeClass('active')
      @panelsByName[name].show()
      for editorElement in @panelsByName[name].find(".editor")
        $(editorElement).view().redraw()
      @panelMenu.children("[name='#{name}']").addClass('active')
      @activePanelName = name
      @panelToShow = null
    else
      @panelToShow = name

  getTitle: ->
    "Atom Config"

  getUri: ->
    configUri

  isEqual: (other) ->
    other instanceof ConfigView
