{$} = require '../src/space-pen-extensions'
path = require 'path'
Package = require '../src/package'
ThemePackage = require '../src/theme-package'

describe "Package", ->
  describe "when the package contains incompatible native modules", ->
    beforeEach ->
      spyOn(atom, 'inDevMode').andReturn(false)
      items = {}
      spyOn(global.localStorage, 'setItem').andCallFake (key, item) -> items[key] = item; undefined
      spyOn(global.localStorage, 'getItem').andCallFake (key) -> items[key] ? null
      spyOn(global.localStorage, 'removeItem').andCallFake (key) -> delete items[key]; undefined

    it "does not activate it", ->
      packagePath = atom.project.getDirectories()[0]?.resolve('packages/package-with-incompatible-native-module')
      pack = new Package(packagePath)
      expect(pack.isCompatible()).toBe false
      expect(pack.incompatibleModules[0].name).toBe 'native-module'
      expect(pack.incompatibleModules[0].path).toBe path.join(packagePath, 'node_modules', 'native-module')

    it "caches the incompatible native modules in local storage", ->
      packagePath = atom.project.getDirectories()[0]?.resolve('packages/package-with-incompatible-native-module')

      expect(new Package(packagePath).isCompatible()).toBe false
      expect(global.localStorage.getItem.callCount).toBe 1
      expect(global.localStorage.setItem.callCount).toBe 1

      expect(new Package(packagePath).isCompatible()).toBe false
      expect(global.localStorage.getItem.callCount).toBe 2
      expect(global.localStorage.setItem.callCount).toBe 1

  describe "::rebuild()", ->
    beforeEach ->
      spyOn(atom, 'inDevMode').andReturn(false)
      items = {}
      spyOn(global.localStorage, 'setItem').andCallFake (key, item) -> items[key] = item; undefined
      spyOn(global.localStorage, 'getItem').andCallFake (key) -> items[key] ? null
      spyOn(global.localStorage, 'removeItem').andCallFake (key) -> delete items[key]; undefined

    it "returns a promise resolving to the results of `apm rebuild`", ->
      packagePath = atom.project.getDirectories()[0]?.resolve('packages/package-with-index')
      pack = new Package(packagePath)
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
      pack = new Package(packagePath)

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
      pack2 = new Package(packagePath)
      expect(pack2.getBuildFailureOutput()).toBe 'It is broken'
      expect(pack2.isCompatible()).toBe false

      # Clears the build failure after a successful build
      pack.rebuild()
      rebuildCallbacks[1]({code: 0, stdout: 'It worked'})

      expect(pack.getBuildFailureOutput()).toBeNull()
      expect(pack2.getBuildFailureOutput()).toBeNull()

    it "sets cached incompatible modules to an empty array when the rebuild completes (there may be a build error, but rebuilding *deletes* native modules)", ->
      packagePath = atom.project.getDirectories()[0]?.resolve('packages/package-with-incompatible-native-module')
      pack = new Package(packagePath)

      expect(pack.getIncompatibleNativeModules().length).toBeGreaterThan(0)

      rebuildCallbacks = []
      spyOn(pack, 'runRebuildProcess').andCallFake ((callback) -> rebuildCallbacks.push(callback))

      pack.rebuild()
      expect(pack.getIncompatibleNativeModules().length).toBeGreaterThan(0)
      rebuildCallbacks[0]({code: 0, stdout: 'It worked'})
      expect(pack.getIncompatibleNativeModules().length).toBe(0)

  describe "theme", ->
    theme = null

    beforeEach ->
      $("#jasmine-content").append $("<atom-text-editor></atom-text-editor>")

    afterEach ->
      theme.deactivate() if theme?

    describe "when the theme contains a single style file", ->
      it "loads and applies css", ->
        expect($("atom-text-editor").css("padding-bottom")).not.toBe "1234px"
        themePath = atom.project.getDirectories()[0]?.resolve('packages/theme-with-index-css')
        theme = new ThemePackage(themePath)
        theme.activate()
        expect($("atom-text-editor").css("padding-top")).toBe "1234px"

      it "parses, loads and applies less", ->
        expect($("atom-text-editor").css("padding-bottom")).not.toBe "1234px"
        themePath = atom.project.getDirectories()[0]?.resolve('packages/theme-with-index-less')
        theme = new ThemePackage(themePath)
        theme.activate()
        expect($("atom-text-editor").css("padding-top")).toBe "4321px"

    describe "when the theme contains a package.json file", ->
      it "loads and applies stylesheets from package.json in the correct order", ->
        expect($("atom-text-editor").css("padding-top")).not.toBe("101px")
        expect($("atom-text-editor").css("padding-right")).not.toBe("102px")
        expect($("atom-text-editor").css("padding-bottom")).not.toBe("103px")

        themePath = atom.project.getDirectories()[0]?.resolve('packages/theme-with-package-file')
        theme = new ThemePackage(themePath)
        theme.activate()
        expect($("atom-text-editor").css("padding-top")).toBe("101px")
        expect($("atom-text-editor").css("padding-right")).toBe("102px")
        expect($("atom-text-editor").css("padding-bottom")).toBe("103px")

    describe "when the theme does not contain a package.json file and is a directory", ->
      it "loads all stylesheet files in the directory", ->
        expect($("atom-text-editor").css("padding-top")).not.toBe "10px"
        expect($("atom-text-editor").css("padding-right")).not.toBe "20px"
        expect($("atom-text-editor").css("padding-bottom")).not.toBe "30px"

        themePath = atom.project.getDirectories()[0]?.resolve('packages/theme-without-package-file')
        theme = new ThemePackage(themePath)
        theme.activate()
        expect($("atom-text-editor").css("padding-top")).toBe "10px"
        expect($("atom-text-editor").css("padding-right")).toBe "20px"
        expect($("atom-text-editor").css("padding-bottom")).toBe "30px"

    describe "reloading a theme", ->
      beforeEach ->
        themePath = atom.project.getDirectories()[0]?.resolve('packages/theme-with-package-file')
        theme = new ThemePackage(themePath)
        theme.activate()

      it "reloads without readding to the stylesheets list", ->
        expect(theme.getStylesheetPaths().length).toBe 3
        theme.reloadStylesheets()
        expect(theme.getStylesheetPaths().length).toBe 3

    describe "events", ->
      beforeEach ->
        themePath = atom.project.getDirectories()[0]?.resolve('packages/theme-with-package-file')
        theme = new ThemePackage(themePath)
        theme.activate()

      it "deactivated event fires on .deactivate()", ->
        theme.onDidDeactivate spy = jasmine.createSpy()
        theme.deactivate()
        expect(spy).toHaveBeenCalled()

  describe ".loadMetadata()", ->
    [packagePath, pack, metadata] = []

    beforeEach ->
      packagePath = atom.project.getDirectories()[0]?.resolve('packages/package-with-different-directory-name')
      metadata = Package.loadMetadata(packagePath, true)

    it "uses the package name defined in package.json", ->
      expect(metadata.name).toBe 'package-with-a-totally-different-name'
