path = require 'path'

{$, $$, WorkspaceView} = require 'atom'
fs = require 'fs-plus'
temp = require 'temp'

ThemeManager = require '../src/theme-manager'
Package = require '../src/package'

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
      waitsForPromise ->
        themeManager.activateThemes()

      runs ->
        names = atom.config.get('core.themes')
        expect(names.length).toBeGreaterThan(0)
        themes = themeManager.getActiveThemes()
        expect(themes).toHaveLength(names.length)

  describe "getImportPaths()", ->
    it "returns the theme directories before the themes are loaded", ->
      atom.config.set('core.themes', ['theme-with-index-less', 'atom-dark-ui', 'atom-light-ui'])

      paths = themeManager.getImportPaths()

      # syntax theme is not a dir at this time, so only two.
      expect(paths.length).toBe 2
      expect(paths[0]).toContain 'atom-light-ui'
      expect(paths[1]).toContain 'atom-dark-ui'

    it "ignores themes that cannot be resolved to a directory", ->
      atom.config.set('core.themes', ['definitely-not-a-theme'])
      expect(-> themeManager.getImportPaths()).not.toThrow()

  describe "when the core.themes config value changes", ->
    it "add/removes stylesheets to reflect the new config value", ->
      themeManager.on 'reloaded', reloadHandler = jasmine.createSpy()
      spyOn(themeManager, 'getUserStylesheetPath').andCallFake -> null

      waitsForPromise ->
        themeManager.activateThemes()

      runs ->
        reloadHandler.reset()
        atom.config.set('core.themes', [])

      waitsFor ->
        reloadHandler.callCount == 1

      runs ->
        reloadHandler.reset()
        expect($('style.theme')).toHaveLength 0
        atom.config.set('core.themes', ['atom-dark-syntax'])

      waitsFor ->
        reloadHandler.callCount == 1

      runs ->
        reloadHandler.reset()
        expect($('style.theme')).toHaveLength 1
        expect($('style.theme:eq(0)').attr('id')).toMatch /atom-dark-syntax/
        atom.config.set('core.themes', ['atom-light-syntax', 'atom-dark-syntax'])

      waitsFor ->
        reloadHandler.callCount == 1

      runs ->
        reloadHandler.reset()
        expect($('style.theme')).toHaveLength 2
        expect($('style.theme:eq(0)').attr('id')).toMatch /atom-dark-syntax/
        expect($('style.theme:eq(1)').attr('id')).toMatch /atom-light-syntax/
        atom.config.set('core.themes', [])

      waitsFor ->
        reloadHandler.callCount == 1

      runs ->
        reloadHandler.reset()
        expect($('style.theme')).toHaveLength 0
        # atom-dark-ui has an directory path, the syntax one doesn't
        atom.config.set('core.themes', ['theme-with-index-less', 'atom-dark-ui'])

      waitsFor ->
        reloadHandler.callCount == 1

      runs ->
        expect($('style.theme')).toHaveLength 2
        importPaths = themeManager.getImportPaths()
        expect(importPaths.length).toBe 1
        expect(importPaths[0]).toContain 'atom-dark-ui'

  describe "when a theme fails to load", ->
    it "logs a warning", ->
      spyOn(console, 'warn')
      expect(-> atom.packages.activatePackage('a-theme-that-will-not-be-found')).toThrow()

  describe "requireStylesheet(path)", ->
    it "synchronously loads css at the given path and installs a style tag for it in the head", ->
      cssPath = atom.project.resolve('css.css')
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
      lessPath = atom.project.resolve('sample.less')
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
      expect($('head style[id*="css.css"]').attr('id')).toBe themeManager.stringToId(atom.project.resolve('css.css'))
      themeManager.requireStylesheet path.join(__dirname, 'fixtures', 'sample')
      expect($('head style[id*="sample.less"]').attr('id')).toBe themeManager.stringToId(atom.project.resolve('sample.less'))

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
      atom.workspaceView = new WorkspaceView
      atom.workspaceView.append $$ -> @div class: 'editor'
      atom.workspaceView.attachToDom()

      waitsForPromise ->
        themeManager.activateThemes()

    it "loads the correct values from the theme's ui-variables file", ->
      themeManager.on 'reloaded', reloadHandler = jasmine.createSpy()
      atom.config.set('core.themes', ['theme-with-ui-variables'])

      waitsFor ->
        reloadHandler.callCount > 0

      runs ->
        # an override loaded in the base css
        expect(atom.workspaceView.css("background-color")).toBe "rgb(0, 0, 255)"

        # from within the theme itself
        expect($(".editor").css("padding-top")).toBe "150px"
        expect($(".editor").css("padding-right")).toBe "150px"
        expect($(".editor").css("padding-bottom")).toBe "150px"

  describe "when the user stylesheet changes", ->
    it "reloads it", ->
      userStylesheetPath = path.join(temp.mkdirSync("atom"), 'styles.less')
      fs.writeFileSync(userStylesheetPath, 'body {border-style: dotted !important;}')

      spyOn(themeManager, 'getUserStylesheetPath').andReturn userStylesheetPath

      waitsForPromise ->
        themeManager.activateThemes()

      runs ->
        expect($(document.body).css('border-style')).toBe 'dotted'
        spyOn(themeManager, 'loadUserStylesheet').andCallThrough()
        fs.writeFileSync(userStylesheetPath, 'body {border-style: dashed}')

      waitsFor ->
        themeManager.loadUserStylesheet.callCount is 1

      runs ->
        expect($(document.body).css('border-style')).toBe 'dashed'
        fs.removeSync(userStylesheetPath)

      waitsFor ->
        themeManager.loadUserStylesheet.callCount is 2

      runs ->
        expect($(document.body).css('border-style')).toBe 'none'

  describe "when a non-existent theme is present in the config", ->
    it "logs a warning but does not throw an exception (regression)", ->
      waitsForPromise ->
        themeManager.activateThemes()

      runs ->
        spyOn(console, 'warn')
        expect(-> atom.config.set('core.themes', ['atom-light-ui', 'theme-really-does-not-exist'])).not.toThrow()
        expect(console.warn.callCount).toBe 1
        expect(console.warn.argsForCall[0][0].length).toBeGreaterThan 0
