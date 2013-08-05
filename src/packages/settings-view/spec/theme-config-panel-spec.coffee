$ = require 'jquery'
ThemePanel = require '../lib/theme-panel'

describe "ThemePanel", ->
  panel = null

  beforeEach ->
    config.set('core.themes', ['atom-dark-ui', 'atom-dark-syntax'])
    panel = new ThemePanel

  describe "when an enabled theme is reloced in the themes list", ->
    it "updates the 'core.themes' config key to reflect the new order", ->
      li = panel.enabledThemes.children(':first').detach()
      panel.enabledThemes.append(li)
      panel.enabledThemes.sortable('option', 'update')()
      expect(config.get('core.themes')).toEqual ['atom-dark-syntax', 'atom-dark-ui']

  describe "when a theme is dragged into the enabled themes list", ->
    it "updates the 'core.themes' config key to reflect the themes in the enabled list", ->
      dragHelper = panel.availableThemes.find("li[name='atom-light-ui']").clone()
      panel.enabledThemes.prepend(dragHelper)
      panel.enabledThemes.sortable('option', 'receive')(null, helper: dragHelper[0])
      panel.enabledThemes.sortable('option', 'update')()
      expect(config.get('core.themes')).toEqual ['atom-light-ui', 'atom-dark-ui', 'atom-dark-syntax']

    describe "when the theme is already present in the enabled list", ->
      it "removes the previous instance of the theme, updating the order based on the location of drag", ->
        dragHelper = panel.availableThemes.find("li[name='atom-dark-ui']").clone()
        panel.enabledThemes.append(dragHelper)
        panel.enabledThemes.sortable('option', 'receive')(null, helper: dragHelper[0])
        panel.enabledThemes.sortable('option', 'update')()
        expect(config.get('core.themes')).toEqual ['atom-dark-syntax', 'atom-dark-ui']

        dragHelper = panel.availableThemes.find("li[name='atom-dark-ui']").clone()
        panel.enabledThemes.prepend(dragHelper)
        panel.enabledThemes.sortable('option', 'receive')(null, helper: dragHelper[0])
        panel.enabledThemes.sortable('option', 'update')()
        expect(config.get('core.themes')).toEqual ['atom-dark-ui', 'atom-dark-syntax']

  describe "when the disable icon is clicked on a theme li", ->
    it "removes the theme from the list and the 'core.themes' array", ->
      panel.enabledThemes.find('li:first .disable-theme').click()
      expect(panel.getEnabledThemeNames()).toEqual ['atom-dark-syntax']
      expect(config.get('core.themes')).toEqual ['atom-dark-syntax']

  describe "when the 'core.config' key is updated", ->
    it "refreshes the enabled themes list", ->
      config.set('core.themes', ['atom-light-ui', 'atom-light-syntax'])
      expect(panel.getEnabledThemeNames()).toEqual ['atom-light-ui', 'atom-light-syntax']
