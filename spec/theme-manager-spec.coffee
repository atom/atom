path = require 'path'
{$, $$, fs, RootView} = require 'atom'

ThemeManager = require '../src/theme-manager'
AtomPackage = require '../src/atom-package'

describe "ThemeManager", ->
  themeManager = null
  resourcePath = atom.getLoadSettings().resourcePath
  configDirPath = atom.getConfigDirPath()

  beforeEach ->
    themeManager = new ThemeManager({packageManager: atom.packages, resourcePath, configDirPath})

  afterEach ->
    themeManager.deactivateThemes()

  describe "theme getters and setters", ->
    beforeEach ->
      atom.packages.loadPackages(sync: true)

    it 'getLoadedThemes get all the loaded themes', ->
      themes = themeManager.getLoadedThemes()
      expect(themes.length).toBeGreaterThan(2)

    it 'getActiveThemes get all the active themes', ->
      themeManager.activateThemes()
      names = atom.config.get('core.themes')
      expect(names.length).toBeGreaterThan(0)
      themes = themeManager.getActiveThemes()
      expect(themes).toHaveLength(names.length)

  describe "getImportPaths()", ->
    it "returns the theme directories before the themes are loaded", ->
      atom.config.set('core.themes', ['atom-dark-syntax', 'atom-dark-ui', 'atom-light-ui'])

      paths = themeManager.getImportPaths()

      # syntax theme is not a dir at this time, so only two.
      expect(paths.length).toBe 2
      expect(paths[0]).toContain 'atom-dark-ui'
      expect(paths[1]).toContain 'atom-light-ui'

    it "ignores themes that cannot be resolved to a directory", ->
      atom.config.set('core.themes', ['definitely-not-a-theme'])
      expect(-> themeManager.getImportPaths()).not.toThrow()

  describe "when the core.themes config value changes", ->
    it "add/removes stylesheets to reflect the new config value", ->
      themeManager.on 'reloaded', reloadHandler = jasmine.createSpy()
      spyOn(themeManager, 'getUserStylesheetPath').andCallFake -> null
      themeManager.activateThemes()

      atom.config.set('core.themes', [])
      expect($('style.theme').length).toBe 0
      expect(reloadHandler).toHaveBeenCalled()

      atom.config.set('core.themes', ['atom-dark-syntax'])
      expect($('style.theme').length).toBe 1
      expect($('style.theme:eq(0)').attr('id')).toMatch /atom-dark-syntax/

      atom.config.set('core.themes', ['atom-light-syntax', 'atom-dark-syntax'])
      expect($('style.theme').length).toBe 2
      expect($('style.theme:eq(0)').attr('id')).toMatch /atom-dark-syntax/
      expect($('style.theme:eq(1)').attr('id')).toMatch /atom-light-syntax/

      atom.config.set('core.themes', [])
      expect($('style.theme').length).toBe 0

      # atom-dark-ui has an directory path, the syntax ones dont.
      atom.config.set('core.themes', ['atom-light-syntax', 'atom-dark-ui', 'atom-dark-syntax'])
      importPaths = themeManager.getImportPaths()
      expect(importPaths.length).toBe 1
      expect(importPaths[0]).toContain 'atom-dark-ui'

  describe "when a theme fails to load", ->
    it "logs a warning", ->
      spyOn(console, 'warn')
      expect(-> atom.packages.activatePackage('a-theme-that-will-not-be-found')).toThrow()

  describe "requireStylesheet(path)", ->
    it "synchronously loads css at the given path and installs a style tag for it in the head", ->
      cssPath = project.resolve('css.css')
      lengthBefore = $('head style').length

      themeManager.requireStylesheet(cssPath)
      expect($('head style').length).toBe lengthBefore + 1

      element = $('head style[id*="css.css"]')
      expect(element.attr('id')).toBe themeManager.stringToId(cssPath)
      expect(element.text()).toBe fs.readFileSync(cssPath, 'utf8')

      # doesn't append twice
      themeManager.requireStylesheet(cssPath)
      expect($('head style').length).toBe lengthBefore + 1

      $('head style[id*="css.css"]').remove()

    it "synchronously loads and parses less files at the given path and installs a style tag for it in the head", ->
      lessPath = project.resolve('sample.less')
      lengthBefore = $('head style').length
      themeManager.requireStylesheet(lessPath)
      expect($('head style').length).toBe lengthBefore + 1

      element = $('head style[id*="sample.less"]')
      expect(element.attr('id')).toBe themeManager.stringToId(lessPath)
      expect(element.text()).toBe """
      #header {
        color: #4d926f;
      }
      h2 {
        color: #4d926f;
      }

      """

      # doesn't append twice
      themeManager.requireStylesheet(lessPath)
      expect($('head style').length).toBe lengthBefore + 1
      $('head style[id*="sample.less"]').remove()

    it "supports requiring css and less stylesheets without an explicit extension", ->
      themeManager.requireStylesheet path.join(__dirname, 'fixtures', 'css')
      expect($('head style[id*="css.css"]').attr('id')).toBe themeManager.stringToId(project.resolve('css.css'))
      themeManager.requireStylesheet path.join(__dirname, 'fixtures', 'sample')
      expect($('head style[id*="sample.less"]').attr('id')).toBe themeManager.stringToId(project.resolve('sample.less'))

      $('head style[id*="css.css"]').remove()
      $('head style[id*="sample.less"]').remove()

  describe ".removeStylesheet(path)", ->
    it "removes styling applied by given stylesheet path", ->
      cssPath = require.resolve('./fixtures/css.css')

      expect($(document.body).css('font-weight')).not.toBe("bold")
      themeManager.requireStylesheet(cssPath)
      expect($(document.body).css('font-weight')).toBe("bold")
      themeManager.removeStylesheet(cssPath)
      expect($(document.body).css('font-weight')).not.toBe("bold")

  describe "base stylesheet loading", ->
    beforeEach ->
      window.rootView = new RootView
      rootView.append $$ -> @div class: 'editor'
      rootView.attachToDom()
      themeManager.activateThemes()

    it "loads the correct values from the theme's ui-variables file", ->
      atom.config.set('core.themes', ['theme-with-ui-variables'])

      # an override loaded in the base css
      expect(rootView.css("background-color")).toBe "rgb(0, 0, 255)"

      # from within the theme itself
      expect($(".editor").css("padding-top")).toBe "150px"
      expect($(".editor").css("padding-right")).toBe "150px"
      expect($(".editor").css("padding-bottom")).toBe "150px"
