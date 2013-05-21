{View, $$} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'
GeneralConfigPanel = require 'general-config-panel'
EditorConfigPanel = require 'editor-config-panel'
ThemeConfigPanel = require 'theme-config-panel'
PackageConfigPanel = require 'package-config-panel'
AvailablePackagesConfigPanel = require 'available-packages-config-panel'

###
# Internal #
###

module.exports =
class ConfigView extends View
  registerDeserializer(this)

  @deserialize: ({activePanelName}) ->
    view = new ConfigView()
    view.showPanel(activePanelName)
    view

  @content: ->
    @div id: 'config-view', =>
      @div id: 'config-menu', =>
        @ul id: 'panels-menu', class: 'nav nav-pills nav-stacked', outlet: 'panelMenu'
        @button "open .atom", id: 'open-dot-atom', class: 'btn btn-default btn-small'
      @div id: 'panels', outlet: 'panels'

  initialize: ->
    @panelsByName = {}
    document.title = "Atom Configuration"
    @on 'click', '#panels-menu li a', (e) =>
      @showPanel($(e.target).closest('li').attr('name'))

    @on 'click', '#open-dot-atom', ->
      atom.open(config.configDirPath)

    @addPanel('General', new GeneralConfigPanel)
    @addPanel('Editor', new EditorConfigPanel)
    @addPanel('Themes', new ThemeConfigPanel)
    @addPanel('Installed Packages', new PackageConfigPanel)
    @addPanel('Available Packages', new AvailablePackagesConfigPanel)

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

  serialize: ->
    deserializer: @constructor.name
    activePanelName: @activePanelName
