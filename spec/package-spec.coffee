path = require 'path'
Package = require '../src/package'
ThemePackage = require '../src/theme-package'
{mockLocalStorage} = require './spec-helper'

describe "Package", ->
  build = (constructor, path) ->
    new constructor(
      path: path, packageManager: atom.packages, config: atom.config,
      styleManager: atom.styles, notificationManager: atom.notifications,
      keymapManager: atom.keymaps, commandRegistry: atom.command,
      grammarRegistry: atom.grammars, themeManager: atom.themes,
      menuManager: atom.menu, contextMenuManager: atom.contextMenu,
      deserializerManager: atom.deserializers, viewRegistry: atom.views,
      devMode: false
    )

  buildPackage = (packagePath) -> build(Package, packagePath)

  buildThemePackage = (themePath) -> build(ThemePackage, themePath)

  describe "when the package contains incompatible native modules", ->
    beforeEach ->
      mockLocalStorage()

    it "does not activate it", ->
      packagePath = atom.project.getDirectories()[0].resolve('packages/package-with-incompatible-native-module')
      pack = buildPackage(packagePath)
      expect(pack.isCompatible()).toBe false
      expect(pack.incompatibleModules[0].name).toBe 'native-module'
      expect(pack.incompatibleModules[0].path).toBe path.join(packagePath, 'node_modules', 'native-module')

    it "utilizes _atomModuleCache if present to determine the package's native dependencies", ->
      packagePath = atom.project.getDirectories()[0].resolve('packages/package-with-ignored-incompatible-native-module')
      pack = buildPackage(packagePath)
      expect(pack.getNativeModuleDependencyPaths().length).toBe(1) # doesn't see the incompatible module
      expect(pack.isCompatible()).toBe true

      packagePath = atom.project.getDirectories()[0]?.resolve('packages/package-with-cached-incompatible-native-module')
      pack = buildPackage(packagePath)
      expect(pack.isCompatible()).toBe false

    it "caches the incompatible native modules in local storage", ->
      packagePath = atom.project.getDirectories()[0].resolve('packages/package-with-incompatible-native-module')
      expect(buildPackage(packagePath).isCompatible()).toBe false
      expect(global.localStorage.getItem.callCount).toBe 1
      expect(global.localStorage.setItem.callCount).toBe 1

      expect(buildPackage(packagePath).isCompatible()).toBe false
      expect(global.localStorage.getItem.callCount).toBe 2
      expect(global.localStorage.setItem.callCount).toBe 1

    it "logs an error to the console describing the problem", ->
      packagePath = atom.project.getDirectories()[0].resolve('packages/package-with-incompatible-native-module')

      spyOn(console, 'warn')
      spyOn(atom.notifications, 'addFatalError')

      buildPackage(packagePath).activateNow()

      expect(atom.notifications.addFatalError).not.toHaveBeenCalled()
      expect(console.warn.callCount).toBe(1)
      expect(console.warn.mostRecentCall.args[0]).toContain('it requires one or more incompatible native modules (native-module)')

  describe "::rebuild()", ->
    beforeEach ->
      mockLocalStorage()

    it "returns a promise resolving to the results of `apm rebuild`", ->
      packagePath = atom.project.getDirectories()[0]?.resolve('packages/package-with-index')
      pack = buildPackage(packagePath)
      rebuildCallbacks = []
      spyOn(pack, 'runRebuildProcess').andCallFake ((callback) -> rebuildCallbacks.push(callback))

      promise = pack.rebuild()
      rebuildCallbacks[0]({code: 0, stdout: 'stdout output', stderr: 'stderr output'})

      waitsFor (done) ->
        promise.then (result) ->
          expect(result).toEqual {code: 0, stdout: 'stdout output', stderr: 'stderr output'}
          done()

    it "persists build failures in local storage", ->
      packagePath = atom.project.getDirectories()[0]?.resolve('packages/package-with-index')
      pack = buildPackage(packagePath)

      expect(pack.isCompatible()).toBe true
      expect(pack.getBuildFailureOutput()).toBeNull()

      rebuildCallbacks = []
      spyOn(pack, 'runRebuildProcess').andCallFake ((callback) -> rebuildCallbacks.push(callback))

      pack.rebuild()
      rebuildCallbacks[0]({code: 13, stderr: 'It is broken'})

      expect(pack.getBuildFailureOutput()).toBe 'It is broken'
      expect(pack.getIncompatibleNativeModules()).toEqual []
      expect(pack.isCompatible()).toBe false

      # A different package instance has the same failure output (simulates reload)
      pack2 = buildPackage(packagePath)
      expect(pack2.getBuildFailureOutput()).toBe 'It is broken'
      expect(pack2.isCompatible()).toBe false

      # Clears the build failure after a successful build
      pack.rebuild()
      rebuildCallbacks[1]({code: 0, stdout: 'It worked'})

      expect(pack.getBuildFailureOutput()).toBeNull()
      expect(pack2.getBuildFailureOutput()).toBeNull()

    it "sets cached incompatible modules to an empty array when the rebuild completes (there may be a build error, but rebuilding *deletes* native modules)", ->
      packagePath = atom.project.getDirectories()[0]?.resolve('packages/package-with-incompatible-native-module')
      pack = buildPackage(packagePath)

      expect(pack.getIncompatibleNativeModules().length).toBeGreaterThan(0)

      rebuildCallbacks = []
      spyOn(pack, 'runRebuildProcess').andCallFake ((callback) -> rebuildCallbacks.push(callback))

      pack.rebuild()
      expect(pack.getIncompatibleNativeModules().length).toBeGreaterThan(0)
      rebuildCallbacks[0]({code: 0, stdout: 'It worked'})
      expect(pack.getIncompatibleNativeModules().length).toBe(0)

  describe "theme", ->
    [editorElement, theme] = []

    beforeEach ->
      editorElement = document.createElement('atom-text-editor')
      jasmine.attachToDOM(editorElement)

    afterEach ->
      theme.deactivate() if theme?

    describe "when the theme contains a single style file", ->
      it "loads and applies css", ->
        expect(getComputedStyle(editorElement).paddingBottom).not.toBe "1234px"
        themePath = atom.project.getDirectories()[0]?.resolve('packages/theme-with-index-css')
        theme = buildThemePackage(themePath)
        theme.activate()
        expect(getComputedStyle(editorElement).paddingTop).toBe "1234px"

      it "parses, loads and applies less", ->
        expect(getComputedStyle(editorElement).paddingBottom).not.toBe "1234px"
        themePath = atom.project.getDirectories()[0]?.resolve('packages/theme-with-index-less')
        theme = buildThemePackage(themePath)
        theme.activate()
        expect(getComputedStyle(editorElement).paddingTop).toBe "4321px"

    describe "when the theme contains a package.json file", ->
      it "loads and applies stylesheets from package.json in the correct order", ->
        expect(getComputedStyle(editorElement).paddingTop).not.toBe("101px")
        expect(getComputedStyle(editorElement).paddingRight).not.toBe("102px")
        expect(getComputedStyle(editorElement).paddingBottom).not.toBe("103px")

        themePath = atom.project.getDirectories()[0]?.resolve('packages/theme-with-package-file')
        theme = buildThemePackage(themePath)
        theme.activate()
        expect(getComputedStyle(editorElement).paddingTop).toBe("101px")
        expect(getComputedStyle(editorElement).paddingRight).toBe("102px")
        expect(getComputedStyle(editorElement).paddingBottom).toBe("103px")

    describe "when the theme does not contain a package.json file and is a directory", ->
      it "loads all stylesheet files in the directory", ->
        expect(getComputedStyle(editorElement).paddingTop).not.toBe "10px"
        expect(getComputedStyle(editorElement).paddingRight).not.toBe "20px"
        expect(getComputedStyle(editorElement).paddingBottom).not.toBe "30px"

        themePath = atom.project.getDirectories()[0]?.resolve('packages/theme-without-package-file')
        theme = buildThemePackage(themePath)
        theme.activate()
        expect(getComputedStyle(editorElement).paddingTop).toBe "10px"
        expect(getComputedStyle(editorElement).paddingRight).toBe "20px"
        expect(getComputedStyle(editorElement).paddingBottom).toBe "30px"

    describe "reloading a theme", ->
      beforeEach ->
        themePath = atom.project.getDirectories()[0]?.resolve('packages/theme-with-package-file')
        theme = buildThemePackage(themePath)
        theme.activate()

      it "reloads without readding to the stylesheets list", ->
        expect(theme.getStylesheetPaths().length).toBe 3
        theme.reloadStylesheets()
        expect(theme.getStylesheetPaths().length).toBe 3

    describe "events", ->
      beforeEach ->
        themePath = atom.project.getDirectories()[0]?.resolve('packages/theme-with-package-file')
        theme = buildThemePackage(themePath)
        theme.activate()

      it "deactivated event fires on .deactivate()", ->
        theme.onDidDeactivate spy = jasmine.createSpy()
        theme.deactivate()
        expect(spy).toHaveBeenCalled()

  describe ".loadMetadata()", ->
    [packagePath, metadata] = []

    beforeEach ->
      packagePath = atom.project.getDirectories()[0]?.resolve('packages/package-with-different-directory-name')
      metadata = atom.packages.loadPackageMetadata(packagePath, true)

    it "uses the package name defined in package.json", ->
      expect(metadata.name).toBe 'package-with-a-totally-different-name'

  describe "the initialize() hook", ->
    it "gets called when the package is activated", ->
      packagePath = atom.project.getDirectories()[0].resolve('packages/package-with-deserializers')
      pack = buildPackage(packagePath)
      pack.requireMainModule()
      mainModule = pack.mainModule
      spyOn(mainModule, 'initialize')
      expect(mainModule.initialize).not.toHaveBeenCalled()
      pack.activate()
      expect(mainModule.initialize).toHaveBeenCalled()
      expect(mainModule.initialize.callCount).toBe(1)

    it "gets called when a deserializer is used", ->
      packagePath = atom.project.getDirectories()[0].resolve('packages/package-with-deserializers')
      pack = buildPackage(packagePath)
      pack.requireMainModule()
      mainModule = pack.mainModule
      spyOn(mainModule, 'initialize')
      pack.load()
      expect(mainModule.initialize).not.toHaveBeenCalled()
      atom.deserializers.deserialize({deserializer: 'Deserializer1', a: 'b'})
      expect(mainModule.initialize).toHaveBeenCalled()
