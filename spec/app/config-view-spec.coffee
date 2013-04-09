ConfigView = require 'config-view'
{$$} = require 'space-pen'

describe "ConfigView", ->
  configView = null

  beforeEach ->
    configView = new ConfigView

  describe ".addPanel(name, view)", ->
    fit "adds a menu entry to the left and a panel that can be activated by clicking it", ->
      configView.addPanel('Panel 1', $$ -> @div id: 'panel-1')
      configView.addPanel('Panel 2', $$ -> @div id: 'panel-2')

      expect(configView.panelMenu.find('li:contains(Panel 1)')).toExist()
      expect(configView.panelMenu.find('li:contains(Panel 1)')).toHaveClass('active')
      expect(configView.panelMenu.find('li:contains(Panel 2)')).toExist()

      configView.attachToDom()
      expect(configView.panels.find('#panel-1')).toBeVisible()
      expect(configView.panels.find('#panel-2')).toBeHidden()
      configView.panelMenu.find('li:contains(Panel 2)').click()
      expect(configView.panels.find('#panel-2')).toBeVisible()
      expect(configView.panels.find('#panel-1')).toBeHidden()
