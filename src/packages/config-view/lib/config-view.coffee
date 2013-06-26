{$$} = require 'space-pen'
ScrollView = require 'scroll-view'
$ = require 'jquery'
_ = require 'underscore'
Pane = require 'pane'
GeneralConfigPanel = require './general-config-panel'
ThemeConfigPanel = require './theme-config-panel'
PackagePanel = require './package-panel'

###
# Internal #
###

module.exports =
class ConfigView extends ScrollView
  registerDeserializer(this)

  @activate: (state) ->
    rootView.command 'config-view:toggle', ->
      configView = new ConfigView()
      activePane = rootView.getActivePane()
      if activePane
        activePane.showItem(configView)
      else
        activePane = new Pane(configView)
        rootView.panes.append(activePane)

      activePane.focus()

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

    @addPanel('General', new GeneralConfigPanel)
    @addPanel('Themes', new ThemeConfigPanel)
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
    "atom://config"

  isEqual: (other) ->
    other instanceof ConfigView
