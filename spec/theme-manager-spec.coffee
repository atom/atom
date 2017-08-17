path = require 'path'
fs = require 'fs-plus'
temp = require('temp').track()

describe "atom.themes", ->
  beforeEach ->
    spyOn(atom, 'inSpecMode').andReturn(false)
    spyOn(console, 'warn')

  afterEach ->
    atom.themes.deactivateThemes()
    try
      temp.cleanupSync()

  describe "theme getters and setters", ->
    beforeEach ->
      jasmine.snapshotDeprecations()
      atom.packages.loadPackages()

    afterEach ->
      jasmine.restoreDeprecationsSnapshot()

    describe 'getLoadedThemes', ->
      it 'gets all the loaded themes', ->
        themes = atom.themes.getLoadedThemes()
        expect(themes.length).toBeGreaterThan(2)

    describe "getActiveThemes", ->
      it 'gets all the active themes', ->
        waitsForPromise -> atom.themes.activateThemes()

        runs ->
          names = atom.config.get('core.themes')
          expect(names.length).toBeGreaterThan(0)
          themes = atom.themes.getActiveThemes()
          expect(themes).toHaveLength(names.length)

  describe "when the core.themes config value contains invalid entry", ->
    it "ignores theme", ->
      atom.config.set 'core.themes', [
        'atom-light-ui'
        null
        undefined
        ''
        false
        4
        {}
        []
        'atom-dark-ui'
      ]

      expect(atom.themes.getEnabledThemeNames()).toEqual ['atom-dark-ui', 'atom-light-ui']

  describe "::getImportPaths()", ->
    it "returns the theme directories before the themes are loaded", ->
      atom.config.set('core.themes', ['theme-with-index-less', 'atom-dark-ui', 'atom-light-ui'])

      paths = atom.themes.getImportPaths()

      # syntax theme is not a dir at this time, so only two.
      expect(paths.length).toBe 2
      expect(paths[0]).toContain 'atom-light-ui'
      expect(paths[1]).toContain 'atom-dark-ui'

    it "ignores themes that cannot be resolved to a directory", ->
      atom.config.set('core.themes', ['definitely-not-a-theme'])
      expect(-> atom.themes.getImportPaths()).not.toThrow()

  describe "when the core.themes config value changes", ->
    it "add/removes stylesheets to reflect the new config value", ->
      atom.themes.onDidChangeActiveThemes didChangeActiveThemesHandler = jasmine.createSpy()
      spyOn(atom.styles, 'getUserStyleSheetPath').andCallFake -> null

      waitsForPromise ->
        atom.themes.activateThemes()

      runs ->
        didChangeActiveThemesHandler.reset()
        atom.config.set('core.themes', [])

      waitsFor 'a', ->
        didChangeActiveThemesHandler.callCount is 1

      runs ->
        didChangeActiveThemesHandler.reset()
        expect(document.querySelectorAll('style.theme')).toHaveLength 0
        atom.config.set('core.themes', ['atom-dark-ui'])

      waitsFor 'b', ->
        didChangeActiveThemesHandler.callCount is 1

      runs ->
        didChangeActiveThemesHandler.reset()
        expect(document.querySelectorAll('style[priority="1"]')).toHaveLength 2
        expect(document.querySelector('style[priority="1"]').getAttribute('source-path')).toMatch /atom-dark-ui/
        atom.config.set('core.themes', ['atom-light-ui', 'atom-dark-ui'])

      waitsFor 'c', ->
        didChangeActiveThemesHandler.callCount is 1

      runs ->
        didChangeActiveThemesHandler.reset()
        expect(document.querySelectorAll('style[priority="1"]')).toHaveLength 2
        expect(document.querySelectorAll('style[priority="1"]')[0].getAttribute('source-path')).toMatch /atom-dark-ui/
        expect(document.querySelectorAll('style[priority="1"]')[1].getAttribute('source-path')).toMatch /atom-light-ui/
        atom.config.set('core.themes', [])

      waitsFor ->
        didChangeActiveThemesHandler.callCount is 1

      runs ->
        didChangeActiveThemesHandler.reset()
        expect(document.querySelectorAll('style[priority="1"]')).toHaveLength 2
        # atom-dark-ui has an directory path, the syntax one doesn't
        atom.config.set('core.themes', ['theme-with-index-less', 'atom-dark-ui'])

      waitsFor ->
        didChangeActiveThemesHandler.callCount is 1

      runs ->
        expect(document.querySelectorAll('style[priority="1"]')).toHaveLength 2
        importPaths = atom.themes.getImportPaths()
        expect(importPaths.length).toBe 1
        expect(importPaths[0]).toContain 'atom-dark-ui'

    it 'adds theme-* classes to the workspace for each active theme', ->
      atom.config.set('core.themes', ['atom-dark-ui', 'atom-dark-syntax'])
      workspaceElement = atom.workspace.getElement()
      atom.themes.onDidChangeActiveThemes didChangeActiveThemesHandler = jasmine.createSpy()

      waitsForPromise ->
        atom.themes.activateThemes()

      runs ->
        expect(workspaceElement).toHaveClass 'theme-atom-dark-ui'

        atom.themes.onDidChangeActiveThemes didChangeActiveThemesHandler = jasmine.createSpy()
        atom.config.set('core.themes', ['theme-with-ui-variables', 'theme-with-syntax-variables'])

      waitsFor ->
        didChangeActiveThemesHandler.callCount > 0

      runs ->
        # `theme-` twice as it prefixes the name with `theme-`
        expect(workspaceElement).toHaveClass 'theme-theme-with-ui-variables'
        expect(workspaceElement).toHaveClass 'theme-theme-with-syntax-variables'
        expect(workspaceElement).not.toHaveClass 'theme-atom-dark-ui'
        expect(workspaceElement).not.toHaveClass 'theme-atom-dark-syntax'

  describe "when a theme fails to load", ->
    it "logs a warning", ->
      console.warn.reset()
      atom.packages.activatePackage('a-theme-that-will-not-be-found').then((->), (->))
      expect(console.warn.callCount).toBe 1
      expect(console.warn.argsForCall[0][0]).toContain "Could not resolve 'a-theme-that-will-not-be-found'"

  describe "::requireStylesheet(path)", ->
    beforeEach ->
      jasmine.snapshotDeprecations()

    afterEach ->
      jasmine.restoreDeprecationsSnapshot()

    it "synchronously loads css at the given path and installs a style tag for it in the head", ->
      atom.styles.onDidAddStyleElement styleElementAddedHandler = jasmine.createSpy("styleElementAddedHandler")

      cssPath = atom.project.getDirectories()[0]?.resolve('css.css')
      lengthBefore = document.querySelectorAll('head style').length

      atom.themes.requireStylesheet(cssPath)
      expect(document.querySelectorAll('head style').length).toBe lengthBefore + 1

      expect(styleElementAddedHandler).toHaveBeenCalled()

      element = document.querySelector('head style[source-path*="css.css"]')
      expect(element.getAttribute('source-path')).toEqualPath cssPath
      expect(element.textContent).toBe fs.readFileSync(cssPath, 'utf8')

      # doesn't append twice
      styleElementAddedHandler.reset()
      atom.themes.requireStylesheet(cssPath)
      expect(document.querySelectorAll('head style').length).toBe lengthBefore + 1
      expect(styleElementAddedHandler).not.toHaveBeenCalled()

      for styleElement in document.querySelectorAll('head style[id*="css.css"]')
        styleElement.remove()

    it "synchronously loads and parses less files at the given path and installs a style tag for it in the head", ->
      lessPath = atom.project.getDirectories()[0]?.resolve('sample.less')
      lengthBefore = document.querySelectorAll('head style').length
      atom.themes.requireStylesheet(lessPath)
      expect(document.querySelectorAll('head style').length).toBe lengthBefore + 1

      element = document.querySelector('head style[source-path*="sample.less"]')
      expect(element.getAttribute('source-path')).toEqualPath lessPath
      expect(element.textContent.toLowerCase()).toBe """
      #header {
        color: #4d926f;
      }
      h2 {
        color: #4d926f;
      }

      """

      # doesn't append twice
      atom.themes.requireStylesheet(lessPath)
      expect(document.querySelectorAll('head style').length).toBe lengthBefore + 1
      for styleElement in document.querySelectorAll('head style[id*="sample.less"]')
        styleElement.remove()

    it "supports requiring css and less stylesheets without an explicit extension", ->
      atom.themes.requireStylesheet path.join(__dirname, 'fixtures', 'css')
      expect(document.querySelector('head style[source-path*="css.css"]').getAttribute('source-path')).toEqualPath atom.project.getDirectories()[0]?.resolve('css.css')
      atom.themes.requireStylesheet path.join(__dirname, 'fixtures', 'sample')
      expect(document.querySelector('head style[source-path*="sample.less"]').getAttribute('source-path')).toEqualPath atom.project.getDirectories()[0]?.resolve('sample.less')

      document.querySelector('head style[source-path*="css.css"]').remove()
      document.querySelector('head style[source-path*="sample.less"]').remove()

    it "returns a disposable allowing styles applied by the given path to be removed", ->
      cssPath = require.resolve('./fixtures/css.css')

      expect(getComputedStyle(document.body).fontWeight).not.toBe("bold")
      disposable = atom.themes.requireStylesheet(cssPath)
      expect(getComputedStyle(document.body).fontWeight).toBe("bold")

      atom.styles.onDidRemoveStyleElement styleElementRemovedHandler = jasmine.createSpy("styleElementRemovedHandler")

      disposable.dispose()

      expect(getComputedStyle(document.body).fontWeight).not.toBe("bold")

      expect(styleElementRemovedHandler).toHaveBeenCalled()


  describe "base style sheet loading", ->
    beforeEach ->
      workspaceElement = atom.workspace.getElement()
      jasmine.attachToDOM(atom.workspace.getElement())
      workspaceElement.appendChild document.createElement('atom-text-editor')

      waitsForPromise ->
        atom.themes.activateThemes()

    it "loads the correct values from the theme's ui-variables file", ->
      atom.themes.onDidChangeActiveThemes didChangeActiveThemesHandler = jasmine.createSpy()
      atom.config.set('core.themes', ['theme-with-ui-variables', 'theme-with-syntax-variables'])

      waitsFor ->
        didChangeActiveThemesHandler.callCount > 0

      runs ->
        # an override loaded in the base css
        expect(getComputedStyle(atom.workspace.getElement())["background-color"]).toBe "rgb(0, 0, 255)"

        # from within the theme itself
        expect(getComputedStyle(document.querySelector("atom-text-editor")).paddingTop).toBe "150px"
        expect(getComputedStyle(document.querySelector("atom-text-editor")).paddingRight).toBe "150px"
        expect(getComputedStyle(document.querySelector("atom-text-editor")).paddingBottom).toBe "150px"

    describe "when there is a theme with incomplete variables", ->
      it "loads the correct values from the fallback ui-variables", ->
        atom.themes.onDidChangeActiveThemes didChangeActiveThemesHandler = jasmine.createSpy()
        atom.config.set('core.themes', ['theme-with-incomplete-ui-variables', 'theme-with-syntax-variables'])

        waitsFor ->
          didChangeActiveThemesHandler.callCount > 0

        runs ->
          # an override loaded in the base css
          expect(getComputedStyle(atom.workspace.getElement())["background-color"]).toBe "rgb(0, 0, 255)"

          # from within the theme itself
          expect(getComputedStyle(document.querySelector("atom-text-editor")).backgroundColor).toBe "rgb(0, 152, 255)"

  describe "user stylesheet", ->
    userStylesheetPath = null
    beforeEach ->
      userStylesheetPath = path.join(temp.mkdirSync("atom"), 'styles.less')
      fs.writeFileSync(userStylesheetPath, 'body {border-style: dotted !important;}')
      spyOn(atom.styles, 'getUserStyleSheetPath').andReturn userStylesheetPath

    describe "when the user stylesheet changes", ->
      beforeEach ->
        jasmine.snapshotDeprecations()

      afterEach ->
        jasmine.restoreDeprecationsSnapshot()

      it "reloads it", ->
        [styleElementAddedHandler, styleElementRemovedHandler] = []

        waitsForPromise ->
          atom.themes.activateThemes()

        runs ->
          atom.styles.onDidRemoveStyleElement styleElementRemovedHandler = jasmine.createSpy("styleElementRemovedHandler")
          atom.styles.onDidAddStyleElement styleElementAddedHandler = jasmine.createSpy("styleElementAddedHandler")

          spyOn(atom.themes, 'loadUserStylesheet').andCallThrough()

          expect(getComputedStyle(document.body).borderStyle).toBe 'dotted'
          fs.writeFileSync(userStylesheetPath, 'body {border-style: dashed}')

        waitsFor ->
          atom.themes.loadUserStylesheet.callCount is 1

        runs ->
          expect(getComputedStyle(document.body).borderStyle).toBe 'dashed'

          expect(styleElementRemovedHandler).toHaveBeenCalled()
          expect(styleElementRemovedHandler.argsForCall[0][0].textContent).toContain 'dotted'

          expect(styleElementAddedHandler).toHaveBeenCalled()
          expect(styleElementAddedHandler.argsForCall[0][0].textContent).toContain 'dashed'

          styleElementRemovedHandler.reset()
          fs.removeSync(userStylesheetPath)

        waitsFor ->
          atom.themes.loadUserStylesheet.callCount is 2

        runs ->
          expect(styleElementRemovedHandler).toHaveBeenCalled()
          expect(styleElementRemovedHandler.argsForCall[0][0].textContent).toContain 'dashed'
          expect(getComputedStyle(document.body).borderStyle).toBe 'none'

    describe "when there is an error reading the stylesheet", ->
      addErrorHandler = null
      beforeEach ->
        atom.themes.loadUserStylesheet()
        spyOn(atom.themes.lessCache, 'cssForFile').andCallFake ->
          throw new Error('EACCES permission denied "styles.less"')
        atom.notifications.onDidAddNotification addErrorHandler = jasmine.createSpy()

      it "creates an error notification and does not add the stylesheet", ->
        atom.themes.loadUserStylesheet()
        expect(addErrorHandler).toHaveBeenCalled()
        note = addErrorHandler.mostRecentCall.args[0]
        expect(note.getType()).toBe 'error'
        expect(note.getMessage()).toContain 'Error loading'
        expect(atom.styles.styleElementsBySourcePath[atom.styles.getUserStyleSheetPath()]).toBeUndefined()

    describe "when there is an error watching the user stylesheet", ->
      addErrorHandler = null
      beforeEach ->
        {File} = require 'pathwatcher'
        spyOn(File::, 'on').andCallFake (event) ->
          if event.indexOf('contents-changed') > -1
            throw new Error('Unable to watch path')
        spyOn(atom.themes, 'loadStylesheet').andReturn ''
        atom.notifications.onDidAddNotification addErrorHandler = jasmine.createSpy()

      it "creates an error notification", ->
        atom.themes.loadUserStylesheet()
        expect(addErrorHandler).toHaveBeenCalled()
        note = addErrorHandler.mostRecentCall.args[0]
        expect(note.getType()).toBe 'error'
        expect(note.getMessage()).toContain 'Unable to watch path'

    it "adds a notification when a theme's stylesheet is invalid", ->
      addErrorHandler = jasmine.createSpy()
      atom.notifications.onDidAddNotification(addErrorHandler)
      expect(-> atom.packages.activatePackage('theme-with-invalid-styles').then((->), (->))).not.toThrow()
      expect(addErrorHandler.callCount).toBe 2
      expect(addErrorHandler.argsForCall[1][0].message).toContain("Failed to activate the theme-with-invalid-styles theme")

  describe "when a non-existent theme is present in the config", ->
    beforeEach ->
      console.warn.reset()
      atom.config.set('core.themes', ['non-existent-dark-ui', 'non-existent-dark-syntax'])

      waitsForPromise ->
        atom.themes.activateThemes()

    it 'uses the default dark UI and syntax themes and logs a warning', ->
      activeThemeNames = atom.themes.getActiveThemeNames()
      expect(console.warn.callCount).toBe 2
      expect(activeThemeNames.length).toBe(2)
      expect(activeThemeNames).toContain('atom-dark-ui')
      expect(activeThemeNames).toContain('atom-dark-syntax')

  describe "when in safe mode", ->
    describe 'when the enabled UI and syntax themes are bundled with Atom', ->
      beforeEach ->
        atom.config.set('core.themes', ['atom-light-ui', 'atom-dark-syntax'])

        waitsForPromise ->
          atom.themes.activateThemes()

      it 'uses the enabled themes', ->
        activeThemeNames = atom.themes.getActiveThemeNames()
        expect(activeThemeNames.length).toBe(2)
        expect(activeThemeNames).toContain('atom-light-ui')
        expect(activeThemeNames).toContain('atom-dark-syntax')

    describe 'when the enabled UI and syntax themes are not bundled with Atom', ->
      beforeEach ->
        atom.config.set('core.themes', ['installed-dark-ui', 'installed-dark-syntax'])

        waitsForPromise ->
          atom.themes.activateThemes()

      it 'uses the default dark UI and syntax themes', ->
        activeThemeNames = atom.themes.getActiveThemeNames()
        expect(activeThemeNames.length).toBe(2)
        expect(activeThemeNames).toContain('atom-dark-ui')
        expect(activeThemeNames).toContain('atom-dark-syntax')

    describe 'when the enabled UI theme is not bundled with Atom', ->
      beforeEach ->
        atom.config.set('core.themes', ['installed-dark-ui', 'atom-light-syntax'])

        waitsForPromise ->
          atom.themes.activateThemes()

      it 'uses the default dark UI theme', ->
        activeThemeNames = atom.themes.getActiveThemeNames()
        expect(activeThemeNames.length).toBe(2)
        expect(activeThemeNames).toContain('atom-dark-ui')
        expect(activeThemeNames).toContain('atom-light-syntax')

    describe 'when the enabled syntax theme is not bundled with Atom', ->
      beforeEach ->
        atom.config.set('core.themes', ['atom-light-ui', 'installed-dark-syntax'])

        waitsForPromise ->
          atom.themes.activateThemes()

      it 'uses the default dark syntax theme', ->
        activeThemeNames = atom.themes.getActiveThemeNames()
        expect(activeThemeNames.length).toBe(2)
        expect(activeThemeNames).toContain('atom-light-ui')
        expect(activeThemeNames).toContain('atom-dark-syntax')
