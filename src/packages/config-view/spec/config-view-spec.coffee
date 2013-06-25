ConfigView = require '../lib/config-view'
{$$} = require 'space-pen'

describe "ConfigView", ->
  configView = null

  beforeEach ->
    configView = new ConfigView

  describe "serialization", ->
    it "remembers which panel was visible", ->
      configView.showPanel('Editor')
      newConfigView = deserialize(configView.serialize())
      configView.remove()
      newConfigView.attachToDom()
      expect(newConfigView.activePanelName).toBe 'Editor'

    it "shows the previously active panel if it is added after deserialization", ->
      configView.addPanel('Panel 1', $$ -> @div id: 'panel-1')
      configView.showPanel('Panel 1')
      newConfigView = deserialize(configView.serialize())
      configView.remove()
      newConfigView.attachToDom()
      newConfigView.addPanel('Panel 1', $$ -> @div id: 'panel-1')
      expect(newConfigView.activePanelName).toBe 'Panel 1'

  describe ".addPanel(name, view)", ->
    it "adds a menu entry to the left and a panel that can be activated by clicking it", ->
      configView.addPanel('Panel 1', $$ -> @div id: 'panel-1')
      configView.addPanel('Panel 2', $$ -> @div id: 'panel-2')

      expect(configView.panelMenu.find('li a:contains(Panel 1)')).toExist()
      expect(configView.panelMenu.find('li a:contains(Panel 2)')).toExist()
      expect(configView.panelMenu.children(':first')).toHaveClass 'active'

      configView.attachToDom()
      configView.panelMenu.find('li a:contains(Panel 1)').click()
      expect(configView.panelMenu.children('.active').length).toBe 1
      expect(configView.panelMenu.find('li:contains(Panel 1)')).toHaveClass('active')
      expect(configView.panels.find('#panel-1')).toBeVisible()
      expect(configView.panels.find('#panel-2')).toBeHidden()
      configView.panelMenu.find('li a:contains(Panel 2)').click()
      expect(configView.panelMenu.children('.active').length).toBe 1
      expect(configView.panelMenu.find('li:contains(Panel 2)')).toHaveClass('active')
      expect(configView.panels.find('#panel-1')).toBeHidden()
      expect(configView.panels.find('#panel-2')).toBeVisible()
