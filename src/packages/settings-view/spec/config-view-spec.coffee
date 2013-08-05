SettingsView = require '../lib/settings-view'
{$$} = require 'space-pen'

describe "SettingsView", ->
  settingsView = null

  beforeEach ->
    settingsView = new SettingsView

  describe "serialization", ->
    it "remembers which panel was visible", ->
      settingsView.showPanel('Packages')
      newSettingsView = deserialize(settingsView.serialize())
      settingsView.remove()
      newSettingsView.attachToDom()
      expect(newSettingsView.activePanelName).toBe 'Packages'

    it "shows the previously active panel if it is added after deserialization", ->
      settingsView.addPanel('Panel 1', $$ -> @div id: 'panel-1')
      settingsView.showPanel('Panel 1')
      newSettingsView = deserialize(settingsView.serialize())
      settingsView.remove()
      newSettingsView.attachToDom()
      newSettingsView.addPanel('Panel 1', $$ -> @div id: 'panel-1')
      expect(newSettingsView.activePanelName).toBe 'Panel 1'

  describe ".addPanel(name, view)", ->
    it "adds a menu entry to the left and a panel that can be activated by clicking it", ->
      settingsView.addPanel('Panel 1', $$ -> @div id: 'panel-1')
      settingsView.addPanel('Panel 2', $$ -> @div id: 'panel-2')

      expect(settingsView.panelMenu.find('li a:contains(Panel 1)')).toExist()
      expect(settingsView.panelMenu.find('li a:contains(Panel 2)')).toExist()
      expect(settingsView.panelMenu.children(':first')).toHaveClass 'active'

      settingsView.attachToDom()
      settingsView.panelMenu.find('li a:contains(Panel 1)').click()
      expect(settingsView.panelMenu.children('.active').length).toBe 1
      expect(settingsView.panelMenu.find('li:contains(Panel 1)')).toHaveClass('active')
      expect(settingsView.panels.find('#panel-1')).toBeVisible()
      expect(settingsView.panels.find('#panel-2')).toBeHidden()
      settingsView.panelMenu.find('li a:contains(Panel 2)').click()
      expect(settingsView.panelMenu.children('.active').length).toBe 1
      expect(settingsView.panelMenu.find('li:contains(Panel 2)')).toHaveClass('active')
      expect(settingsView.panels.find('#panel-1')).toBeHidden()
      expect(settingsView.panels.find('#panel-2')).toBeVisible()
