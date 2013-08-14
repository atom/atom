$ = require 'jquery'

Theme = require 'theme'
ThemeManager = require 'theme-manager'

describe "ThemeManager", ->
  describe "when the core.themes config value changes", ->
    it "add/removes stylesheets to reflect the new config value", ->
      themeManager = new ThemeManager()
      themeManager.on 'reload', reloadHandler = jasmine.createSpy()
      spyOn(themeManager, 'getUserStylesheetPath').andCallFake -> null
      themeManager.load()

      config.set('core.themes', [])
      expect($('style.userTheme').length).toBe 0
      expect(reloadHandler).toHaveBeenCalled()

      config.set('core.themes', ['atom-dark-syntax'])
      expect($('style.userTheme').length).toBe 1
      expect($('style.userTheme:eq(0)').attr('id')).toMatch /atom-dark-syntax.less$/

      config.set('core.themes', ['atom-light-syntax', 'atom-dark-syntax'])
      expect($('style.userTheme').length).toBe 2
      expect($('style.userTheme:eq(0)').attr('id')).toMatch /atom-light-syntax.less$/
      expect($('style.userTheme:eq(1)').attr('id')).toMatch /atom-dark-syntax.less$/

      config.set('core.themes', [])
      expect($('style.userTheme').length).toBe 0

      # atom-dark-ui has an directory path, the syntax ones dont.
      config.set('core.themes', ['atom-light-syntax', 'atom-dark-ui', 'atom-dark-syntax'])
      importPaths = themeManager.getImportPaths()
      expect(importPaths.length).toBe 1
      expect(importPaths[0]).toContain 'atom-dark-ui'

  describe "when a theme fails to load", ->
    it "logs a warning", ->
      themeManager = new ThemeManager()
      spyOn(console, 'warn')
      themeManager.loadTheme('a-theme-that-will-not-be-found')
      expect(console.warn).toHaveBeenCalled()
