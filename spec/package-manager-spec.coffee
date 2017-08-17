path = require 'path'
Package = require '../src/package'
temp = require('temp').track()
fs = require 'fs-plus'
{Disposable} = require 'atom'
{buildKeydownEvent} = require '../src/keymap-extensions'
{mockLocalStorage} = require './spec-helper'
ModuleCache = require '../src/module-cache'

describe "PackageManager", ->
  createTestElement = (className) ->
    element = document.createElement('div')
    element.className = className
    element

  beforeEach ->
    spyOn(ModuleCache, 'add')

  afterEach ->
    temp.cleanupSync()

  describe "::getApmPath()", ->
    it "returns the path to the apm command", ->
      apmPath = path.join(process.resourcesPath, "app", "apm", "bin", "apm")
      if process.platform is 'win32'
        apmPath += ".cmd"
      expect(atom.packages.getApmPath()).toBe apmPath

    describe "when the core.apmPath setting is set", ->
      beforeEach ->
        atom.config.set("core.apmPath", "/path/to/apm")

      it "returns the value of the core.apmPath config setting", ->
        expect(atom.packages.getApmPath()).toBe "/path/to/apm"

  describe "::loadPackages()", ->
    beforeEach ->
      spyOn(atom.packages, 'loadAvailablePackage')

    afterEach ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

    it "sets hasLoadedInitialPackages", ->
      expect(atom.packages.hasLoadedInitialPackages()).toBe false
      atom.packages.loadPackages()
      expect(atom.packages.hasLoadedInitialPackages()).toBe true

  describe "::loadPackage(name)", ->
    beforeEach ->
      atom.config.set("core.disabledPackages", [])

    it "returns the package", ->
      pack = atom.packages.loadPackage("package-with-index")
      expect(pack instanceof Package).toBe true
      expect(pack.metadata.name).toBe "package-with-index"

    it "returns the package if it has an invalid keymap", ->
      spyOn(atom, 'inSpecMode').andReturn(false)
      pack = atom.packages.loadPackage("package-with-broken-keymap")
      expect(pack instanceof Package).toBe true
      expect(pack.metadata.name).toBe "package-with-broken-keymap"

    it "returns the package if it has an invalid stylesheet", ->
      spyOn(atom, 'inSpecMode').andReturn(false)
      pack = atom.packages.loadPackage("package-with-invalid-styles")
      expect(pack instanceof Package).toBe true
      expect(pack.metadata.name).toBe "package-with-invalid-styles"
      expect(pack.stylesheets.length).toBe 0

      addErrorHandler = jasmine.createSpy()
      atom.notifications.onDidAddNotification(addErrorHandler)
      expect(-> pack.reloadStylesheets()).not.toThrow()
      expect(addErrorHandler.callCount).toBe 2
      expect(addErrorHandler.argsForCall[1][0].message).toContain("Failed to reload the package-with-invalid-styles package stylesheets")
      expect(addErrorHandler.argsForCall[1][0].options.packageName).toEqual "package-with-invalid-styles"

    it "returns null if the package has an invalid package.json", ->
      spyOn(atom, 'inSpecMode').andReturn(false)
      addErrorHandler = jasmine.createSpy()
      atom.notifications.onDidAddNotification(addErrorHandler)
      expect(atom.packages.loadPackage("package-with-broken-package-json")).toBeNull()
      expect(addErrorHandler.callCount).toBe 1
      expect(addErrorHandler.argsForCall[0][0].message).toContain("Failed to load the package-with-broken-package-json package")
      expect(addErrorHandler.argsForCall[0][0].options.packageName).toEqual "package-with-broken-package-json"

    it "returns null if the package name or path starts with a dot", ->
      expect(atom.packages.loadPackage("/Users/user/.atom/packages/.git")).toBeNull()

    it "normalizes short repository urls in package.json", ->
      {metadata} = atom.packages.loadPackage("package-with-short-url-package-json")
      expect(metadata.repository.type).toBe "git"
      expect(metadata.repository.url).toBe "https://github.com/example/repo"

      {metadata} = atom.packages.loadPackage("package-with-invalid-url-package-json")
      expect(metadata.repository.type).toBe "git"
      expect(metadata.repository.url).toBe "foo"

    it "trims git+ from the beginning and .git from the end of repository URLs, even if npm already normalized them ", ->
      {metadata} = atom.packages.loadPackage("package-with-prefixed-and-suffixed-repo-url")
      expect(metadata.repository.type).toBe "git"
      expect(metadata.repository.url).toBe "https://github.com/example/repo"

    it "returns null if the package is not found in any package directory", ->
      spyOn(console, 'warn')
      expect(atom.packages.loadPackage("this-package-cannot-be-found")).toBeNull()
      expect(console.warn.callCount).toBe(1)
      expect(console.warn.argsForCall[0][0]).toContain("Could not resolve")

    describe "when the package is deprecated", ->
      it "returns null", ->
        spyOn(console, 'warn')
        expect(atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'packages', 'wordcount'))).toBeNull()
        expect(atom.packages.isDeprecatedPackage('wordcount', '2.1.9')).toBe true
        expect(atom.packages.isDeprecatedPackage('wordcount', '2.2.0')).toBe true
        expect(atom.packages.isDeprecatedPackage('wordcount', '2.2.1')).toBe false
        expect(atom.packages.getDeprecatedPackageMetadata('wordcount').version).toBe '<=2.2.0'

    it "invokes ::onDidLoadPackage listeners with the loaded package", ->
      loadedPackage = null
      atom.packages.onDidLoadPackage (pack) -> loadedPackage = pack

      atom.packages.loadPackage("package-with-main")

      expect(loadedPackage.name).toBe "package-with-main"

    it "registers any deserializers specified in the package's package.json", ->
      pack = atom.packages.loadPackage("package-with-deserializers")

      state1 = {deserializer: 'Deserializer1', a: 'b'}
      expect(atom.deserializers.deserialize(state1)).toEqual {
        wasDeserializedBy: 'deserializeMethod1'
        state: state1
      }

      state2 = {deserializer: 'Deserializer2', c: 'd'}
      expect(atom.deserializers.deserialize(state2)).toEqual {
        wasDeserializedBy: 'deserializeMethod2'
        state: state2
      }

    it "early-activates any atom.directory-provider or atom.repository-provider services that the package provide", ->
      jasmine.useRealClock()

      providers = []
      atom.packages.serviceHub.consume 'atom.directory-provider', '^0.1.0', (provider) ->
        providers.push(provider)

      atom.packages.loadPackage('package-with-directory-provider')
      expect(providers.map((p) -> p.name)).toEqual(['directory provider from package-with-directory-provider'])

    describe "when there are view providers specified in the package's package.json", ->
      model1 = {worksWithViewProvider1: true}
      model2 = {worksWithViewProvider2: true}

      afterEach ->
        atom.packages.deactivatePackage('package-with-view-providers')
        atom.packages.unloadPackage('package-with-view-providers')

      it "does not load the view providers immediately", ->
        pack = atom.packages.loadPackage("package-with-view-providers")
        expect(pack.mainModule).toBeNull()

        expect(-> atom.views.getView(model1)).toThrow()
        expect(-> atom.views.getView(model2)).toThrow()

      it "registers the view providers when the package is activated", ->
        pack = atom.packages.loadPackage("package-with-view-providers")

        waitsForPromise ->
          atom.packages.activatePackage("package-with-view-providers").then ->
            element1 = atom.views.getView(model1)
            expect(element1 instanceof HTMLDivElement).toBe true
            expect(element1.dataset.createdBy).toBe 'view-provider-1'

            element2 = atom.views.getView(model2)
            expect(element2 instanceof HTMLDivElement).toBe true
            expect(element2.dataset.createdBy).toBe 'view-provider-2'

      it "registers the view providers when any of the package's deserializers are used", ->
        pack = atom.packages.loadPackage("package-with-view-providers")

        spyOn(atom.views, 'addViewProvider').andCallThrough()
        atom.deserializers.deserialize({
          deserializer: 'DeserializerFromPackageWithViewProviders',
          a: 'b'
        })
        expect(atom.views.addViewProvider.callCount).toBe 2

        atom.deserializers.deserialize({
          deserializer: 'DeserializerFromPackageWithViewProviders',
          a: 'b'
        })
        expect(atom.views.addViewProvider.callCount).toBe 2

        element1 = atom.views.getView(model1)
        expect(element1 instanceof HTMLDivElement).toBe true
        expect(element1.dataset.createdBy).toBe 'view-provider-1'

        element2 = atom.views.getView(model2)
        expect(element2 instanceof HTMLDivElement).toBe true
        expect(element2.dataset.createdBy).toBe 'view-provider-2'

    it "registers the config schema in the package's metadata, if present", ->
      pack = atom.packages.loadPackage("package-with-json-config-schema")
      expect(atom.config.getSchema('package-with-json-config-schema')).toEqual {
        type: 'object'
        properties: {
          a: {type: 'number', default: 5}
          b: {type: 'string', default: 'five'}
        }
      }

      expect(pack.mainModule).toBeNull()

      atom.packages.unloadPackage('package-with-json-config-schema')
      atom.config.clear()

      pack = atom.packages.loadPackage("package-with-json-config-schema")
      expect(atom.config.getSchema('package-with-json-config-schema')).toEqual {
        type: 'object'
        properties: {
          a: {type: 'number', default: 5}
          b: {type: 'string', default: 'five'}
        }
      }

    describe "when a package does not have deserializers, view providers or a config schema in its package.json", ->
      beforeEach ->
        mockLocalStorage()

      it "defers loading the package's main module if the package previously used no Atom APIs when its main module was required", ->
        pack1 = atom.packages.loadPackage('package-with-main')
        expect(pack1.mainModule).toBeDefined()

        atom.packages.unloadPackage('package-with-main')

        pack2 = atom.packages.loadPackage('package-with-main')
        expect(pack2.mainModule).toBeNull()

      it "does not defer loading the package's main module if the package previously used Atom APIs when its main module was required", ->
        pack1 = atom.packages.loadPackage('package-with-eval-time-api-calls')
        expect(pack1.mainModule).toBeDefined()

        atom.packages.unloadPackage('package-with-eval-time-api-calls')

        pack2 = atom.packages.loadPackage('package-with-eval-time-api-calls')
        expect(pack2.mainModule).not.toBeNull()

  describe "::loadAvailablePackage(availablePackage)", ->
    describe "if the package was preloaded", ->
      it "adds the package path to the module cache", ->
        availablePackage = atom.packages.getAvailablePackages().find (p) -> p.name is 'spell-check'
        availablePackage.isBundled = true
        expect(atom.packages.preloadedPackages[availablePackage.name]).toBeUndefined()
        expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(false)

        metadata = atom.packages.loadPackageMetadata(availablePackage)
        atom.packages.preloadPackage(
          availablePackage.name,
          {
            rootDirPath: path.relative(atom.packages.resourcePath, availablePackage.path),
            metadata
          }
        )
        atom.packages.loadAvailablePackage(availablePackage)
        expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(true)
        expect(ModuleCache.add).toHaveBeenCalledWith(availablePackage.path, metadata)

      it "deactivates it if it had been disabled", ->
        availablePackage = atom.packages.getAvailablePackages().find (p) -> p.name is 'spell-check'
        availablePackage.isBundled = true
        expect(atom.packages.preloadedPackages[availablePackage.name]).toBeUndefined()
        expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(false)

        metadata = atom.packages.loadPackageMetadata(availablePackage)
        preloadedPackage = atom.packages.preloadPackage(
          availablePackage.name,
          {
            rootDirPath: path.relative(atom.packages.resourcePath, availablePackage.path),
            metadata
          }
        )
        expect(preloadedPackage.keymapActivated).toBe(true)
        expect(preloadedPackage.settingsActivated).toBe(true)
        expect(preloadedPackage.menusActivated).toBe(true)

        atom.packages.loadAvailablePackage(availablePackage, new Set([availablePackage.name]))
        expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(false)
        expect(preloadedPackage.keymapActivated).toBe(false)
        expect(preloadedPackage.settingsActivated).toBe(false)
        expect(preloadedPackage.menusActivated).toBe(false)

      it "deactivates it and reloads the new one if trying to load the same package outside of the bundle", ->
        availablePackage = atom.packages.getAvailablePackages().find (p) -> p.name is 'spell-check'
        availablePackage.isBundled = true
        expect(atom.packages.preloadedPackages[availablePackage.name]).toBeUndefined()
        expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(false)

        metadata = atom.packages.loadPackageMetadata(availablePackage)
        preloadedPackage = atom.packages.preloadPackage(
          availablePackage.name,
          {
            rootDirPath: path.relative(atom.packages.resourcePath, availablePackage.path),
            metadata
          }
        )
        expect(preloadedPackage.keymapActivated).toBe(true)
        expect(preloadedPackage.settingsActivated).toBe(true)
        expect(preloadedPackage.menusActivated).toBe(true)

        availablePackage.isBundled = false
        atom.packages.loadAvailablePackage(availablePackage)
        expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(true)
        expect(preloadedPackage.keymapActivated).toBe(false)
        expect(preloadedPackage.settingsActivated).toBe(false)
        expect(preloadedPackage.menusActivated).toBe(false)

    describe "if the package was not preloaded", ->
      it "adds the package path to the module cache", ->
        availablePackage = atom.packages.getAvailablePackages().find (p) -> p.name is 'spell-check'
        availablePackage.isBundled = true
        metadata = atom.packages.loadPackageMetadata(availablePackage)
        atom.packages.loadAvailablePackage(availablePackage)
        expect(ModuleCache.add).toHaveBeenCalledWith(availablePackage.path, metadata)

  describe "preloading", ->
    it "requires the main module, loads the config schema and activates keymaps, menus and settings without reactivating them during package activation", ->
      availablePackage = atom.packages.getAvailablePackages().find (p) -> p.name is 'spell-check'
      availablePackage.isBundled = true
      metadata = atom.packages.loadPackageMetadata(availablePackage)
      expect(atom.packages.preloadedPackages[availablePackage.name]).toBeUndefined()
      expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(false)

      atom.packages.packagesCache = {}
      atom.packages.packagesCache[availablePackage.name] = {
        main: path.join(availablePackage.path, metadata.main),
        grammarPaths: []
      }
      preloadedPackage = atom.packages.preloadPackage(
        availablePackage.name,
        {
          rootDirPath: path.relative(atom.packages.resourcePath, availablePackage.path),
          metadata
        }
      )
      expect(preloadedPackage.keymapActivated).toBe(true)
      expect(preloadedPackage.settingsActivated).toBe(true)
      expect(preloadedPackage.menusActivated).toBe(true)
      expect(preloadedPackage.mainModule).toBeTruthy()
      expect(preloadedPackage.configSchemaRegisteredOnLoad).toBeTruthy()

      spyOn(atom.keymaps, 'add')
      spyOn(atom.menu, 'add')
      spyOn(atom.contextMenu, 'add')
      spyOn(atom.config, 'setSchema')

      atom.packages.loadAvailablePackage(availablePackage)
      expect(preloadedPackage.getMainModulePath()).toBe(path.join(availablePackage.path, metadata.main))

      atom.packages.activatePackage(availablePackage.name)
      expect(atom.keymaps.add).not.toHaveBeenCalled()
      expect(atom.menu.add).not.toHaveBeenCalled()
      expect(atom.contextMenu.add).not.toHaveBeenCalled()
      expect(atom.config.setSchema).not.toHaveBeenCalled()
      expect(preloadedPackage.keymapActivated).toBe(true)
      expect(preloadedPackage.settingsActivated).toBe(true)
      expect(preloadedPackage.menusActivated).toBe(true)
      expect(preloadedPackage.mainModule).toBeTruthy()
      expect(preloadedPackage.configSchemaRegisteredOnLoad).toBeTruthy()

    it "deactivates disabled keymaps during package activation", ->
      availablePackage = atom.packages.getAvailablePackages().find (p) -> p.name is 'spell-check'
      availablePackage.isBundled = true
      metadata = atom.packages.loadPackageMetadata(availablePackage)
      expect(atom.packages.preloadedPackages[availablePackage.name]).toBeUndefined()
      expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(false)

      atom.packages.packagesCache = {}
      atom.packages.packagesCache[availablePackage.name] = {
        main: path.join(availablePackage.path, metadata.main),
        grammarPaths: []
      }
      preloadedPackage = atom.packages.preloadPackage(
        availablePackage.name,
        {
          rootDirPath: path.relative(atom.packages.resourcePath, availablePackage.path),
          metadata
        }
      )
      expect(preloadedPackage.keymapActivated).toBe(true)
      expect(preloadedPackage.settingsActivated).toBe(true)
      expect(preloadedPackage.menusActivated).toBe(true)

      atom.packages.loadAvailablePackage(availablePackage)
      atom.config.set("core.packagesWithKeymapsDisabled", [availablePackage.name])
      atom.packages.activatePackage(availablePackage.name)

      expect(preloadedPackage.keymapActivated).toBe(false)
      expect(preloadedPackage.settingsActivated).toBe(true)
      expect(preloadedPackage.menusActivated).toBe(true)

  describe "::unloadPackage(name)", ->
    describe "when the package is active", ->
      it "throws an error", ->
        pack = null
        waitsForPromise ->
          atom.packages.activatePackage('package-with-main').then (p) -> pack = p

        runs ->
          expect(atom.packages.isPackageLoaded(pack.name)).toBeTruthy()
          expect(atom.packages.isPackageActive(pack.name)).toBeTruthy()
          expect( -> atom.packages.unloadPackage(pack.name)).toThrow()
          expect(atom.packages.isPackageLoaded(pack.name)).toBeTruthy()
          expect(atom.packages.isPackageActive(pack.name)).toBeTruthy()

    describe "when the package is not loaded", ->
      it "throws an error", ->
        expect(atom.packages.isPackageLoaded('unloaded')).toBeFalsy()
        expect( -> atom.packages.unloadPackage('unloaded')).toThrow()
        expect(atom.packages.isPackageLoaded('unloaded')).toBeFalsy()

    describe "when the package is loaded", ->
      it "no longers reports it as being loaded", ->
        pack = atom.packages.loadPackage('package-with-main')
        expect(atom.packages.isPackageLoaded(pack.name)).toBeTruthy()
        atom.packages.unloadPackage(pack.name)
        expect(atom.packages.isPackageLoaded(pack.name)).toBeFalsy()

    it "invokes ::onDidUnloadPackage listeners with the unloaded package", ->
      atom.packages.loadPackage('package-with-main')
      unloadedPackage = null
      atom.packages.onDidUnloadPackage (pack) -> unloadedPackage = pack
      atom.packages.unloadPackage('package-with-main')
      expect(unloadedPackage.name).toBe 'package-with-main'

  describe "::activatePackage(id)", ->
    describe "when called multiple times", ->
      it "it only calls activate on the package once", ->
        spyOn(Package.prototype, 'activateNow').andCallThrough()
        waitsForPromise ->
          atom.packages.activatePackage('package-with-index')
        waitsForPromise ->
          atom.packages.activatePackage('package-with-index')
        waitsForPromise ->
          atom.packages.activatePackage('package-with-index')

        runs ->
          expect(Package.prototype.activateNow.callCount).toBe 1

    describe "when the package has a main module", ->
      describe "when the metadata specifies a main module path˜", ->
        it "requires the module at the specified path", ->
          mainModule = require('./fixtures/packages/package-with-main/main-module')
          spyOn(mainModule, 'activate')
          pack = null
          waitsForPromise ->
            atom.packages.activatePackage('package-with-main').then (p) -> pack = p

          runs ->
            expect(mainModule.activate).toHaveBeenCalled()
            expect(pack.mainModule).toBe mainModule

      describe "when the metadata does not specify a main module", ->
        it "requires index.coffee", ->
          indexModule = require('./fixtures/packages/package-with-index/index')
          spyOn(indexModule, 'activate')
          pack = null
          waitsForPromise ->
            atom.packages.activatePackage('package-with-index').then (p) -> pack = p

          runs ->
            expect(indexModule.activate).toHaveBeenCalled()
            expect(pack.mainModule).toBe indexModule

      it "assigns config schema, including defaults when package contains a schema", ->
        expect(atom.config.get('package-with-config-schema.numbers.one')).toBeUndefined()

        waitsForPromise ->
          atom.packages.activatePackage('package-with-config-schema')

        runs ->
          expect(atom.config.get('package-with-config-schema.numbers.one')).toBe 1
          expect(atom.config.get('package-with-config-schema.numbers.two')).toBe 2

          expect(atom.config.set('package-with-config-schema.numbers.one', 'nope')).toBe false
          expect(atom.config.set('package-with-config-schema.numbers.one', '10')).toBe true
          expect(atom.config.get('package-with-config-schema.numbers.one')).toBe 10

      describe "when the package metadata includes `activationCommands`", ->
        [mainModule, promise, workspaceCommandListener, registration] = []

        beforeEach ->
          jasmine.attachToDOM(atom.workspace.getElement())
          mainModule = require './fixtures/packages/package-with-activation-commands/index'
          mainModule.activationCommandCallCount = 0
          spyOn(mainModule, 'activate').andCallThrough()
          spyOn(Package.prototype, 'requireMainModule').andCallThrough()

          workspaceCommandListener = jasmine.createSpy('workspaceCommandListener')
          registration = atom.commands.add '.workspace', 'activation-command', workspaceCommandListener

          promise = atom.packages.activatePackage('package-with-activation-commands')

        afterEach ->
          registration?.dispose()
          mainModule = null

        it "defers requiring/activating the main module until an activation event bubbles to the root view", ->
          expect(Package.prototype.requireMainModule.callCount).toBe 0

          atom.workspace.getElement().dispatchEvent(new CustomEvent('activation-command', bubbles: true))

          waitsForPromise ->
            promise

          runs ->
            expect(Package.prototype.requireMainModule.callCount).toBe 1

        it "triggers the activation event on all handlers registered during activation", ->
          waitsForPromise ->
            atom.workspace.open()

          runs ->
            editorElement = atom.workspace.getActiveTextEditor().getElement()
            editorCommandListener = jasmine.createSpy("editorCommandListener")
            atom.commands.add 'atom-text-editor', 'activation-command', editorCommandListener
            atom.commands.dispatch(editorElement, 'activation-command')
            expect(mainModule.activate.callCount).toBe 1
            expect(mainModule.activationCommandCallCount).toBe 1
            expect(editorCommandListener.callCount).toBe 1
            expect(workspaceCommandListener.callCount).toBe 1
            atom.commands.dispatch(editorElement, 'activation-command')
            expect(mainModule.activationCommandCallCount).toBe 2
            expect(editorCommandListener.callCount).toBe 2
            expect(workspaceCommandListener.callCount).toBe 2
            expect(mainModule.activate.callCount).toBe 1

        it "activates the package immediately when the events are empty", ->
          mainModule = require './fixtures/packages/package-with-empty-activation-commands/index'
          spyOn(mainModule, 'activate').andCallThrough()

          waitsForPromise ->
            atom.packages.activatePackage('package-with-empty-activation-commands')

          runs ->
            expect(mainModule.activate.callCount).toBe 1

        it "adds a notification when the activation commands are invalid", ->
          spyOn(atom, 'inSpecMode').andReturn(false)
          addErrorHandler = jasmine.createSpy()
          atom.notifications.onDidAddNotification(addErrorHandler)
          expect(-> atom.packages.activatePackage('package-with-invalid-activation-commands')).not.toThrow()
          expect(addErrorHandler.callCount).toBe 1
          expect(addErrorHandler.argsForCall[0][0].message).toContain("Failed to activate the package-with-invalid-activation-commands package")
          expect(addErrorHandler.argsForCall[0][0].options.packageName).toEqual "package-with-invalid-activation-commands"

        it "adds a notification when the context menu is invalid", ->
          spyOn(atom, 'inSpecMode').andReturn(false)
          addErrorHandler = jasmine.createSpy()
          atom.notifications.onDidAddNotification(addErrorHandler)
          expect(-> atom.packages.activatePackage('package-with-invalid-context-menu')).not.toThrow()
          expect(addErrorHandler.callCount).toBe 1
          expect(addErrorHandler.argsForCall[0][0].message).toContain("Failed to activate the package-with-invalid-context-menu package")
          expect(addErrorHandler.argsForCall[0][0].options.packageName).toEqual "package-with-invalid-context-menu"

        it "adds a notification when the grammar is invalid", ->
          addErrorHandler = jasmine.createSpy()
          atom.notifications.onDidAddNotification(addErrorHandler)

          expect(-> atom.packages.activatePackage('package-with-invalid-grammar')).not.toThrow()

          waitsFor ->
            addErrorHandler.callCount > 0

          runs ->
            expect(addErrorHandler.callCount).toBe 1
            expect(addErrorHandler.argsForCall[0][0].message).toContain("Failed to load a package-with-invalid-grammar package grammar")
            expect(addErrorHandler.argsForCall[0][0].options.packageName).toEqual "package-with-invalid-grammar"

        it "adds a notification when the settings are invalid", ->
          addErrorHandler = jasmine.createSpy()
          atom.notifications.onDidAddNotification(addErrorHandler)

          expect(-> atom.packages.activatePackage('package-with-invalid-settings')).not.toThrow()

          waitsFor ->
            addErrorHandler.callCount > 0

          runs ->
            expect(addErrorHandler.callCount).toBe 1
            expect(addErrorHandler.argsForCall[0][0].message).toContain("Failed to load the package-with-invalid-settings package settings")
            expect(addErrorHandler.argsForCall[0][0].options.packageName).toEqual "package-with-invalid-settings"

    describe "when the package metadata includes `activationHooks`", ->
      [mainModule, promise] = []

      beforeEach ->
        mainModule = require './fixtures/packages/package-with-activation-hooks/index'
        spyOn(mainModule, 'activate').andCallThrough()
        spyOn(Package.prototype, 'requireMainModule').andCallThrough()

      it "defers requiring/activating the main module until an triggering of an activation hook occurs", ->
        promise = atom.packages.activatePackage('package-with-activation-hooks')
        expect(Package.prototype.requireMainModule.callCount).toBe 0
        atom.packages.triggerActivationHook('language-fictitious:grammar-used')
        atom.packages.triggerDeferredActivationHooks()

        waitsForPromise ->
          promise

        runs ->
          expect(Package.prototype.requireMainModule.callCount).toBe 1

      it "does not double register activation hooks when deactivating and reactivating", ->
        promise = atom.packages.activatePackage('package-with-activation-hooks')
        expect(mainModule.activate.callCount).toBe 0
        atom.packages.triggerActivationHook('language-fictitious:grammar-used')
        atom.packages.triggerDeferredActivationHooks()

        waitsForPromise ->
          promise

        runs ->
          expect(mainModule.activate.callCount).toBe 1
          atom.packages.deactivatePackage('package-with-activation-hooks')
          promise = atom.packages.activatePackage('package-with-activation-hooks')
          atom.packages.triggerActivationHook('language-fictitious:grammar-used')
          atom.packages.triggerDeferredActivationHooks()

        waitsForPromise ->
          promise

        runs ->
          expect(mainModule.activate.callCount).toBe 2

      it "activates the package immediately when activationHooks is empty", ->
        mainModule = require './fixtures/packages/package-with-empty-activation-hooks/index'
        spyOn(mainModule, 'activate').andCallThrough()

        runs ->
          expect(Package.prototype.requireMainModule.callCount).toBe 0

        waitsForPromise ->
          atom.packages.activatePackage('package-with-empty-activation-hooks')

        runs ->
          expect(mainModule.activate.callCount).toBe 1
          expect(Package.prototype.requireMainModule.callCount).toBe 1

      it "activates the package immediately if the activation hook had already been triggered", ->
        atom.packages.triggerActivationHook('language-fictitious:grammar-used')
        atom.packages.triggerDeferredActivationHooks()
        expect(Package.prototype.requireMainModule.callCount).toBe 0

        waitsForPromise ->
          atom.packages.activatePackage('package-with-activation-hooks')

        runs ->
          expect(Package.prototype.requireMainModule.callCount).toBe 1

    describe "when the package has no main module", ->
      it "does not throw an exception", ->
        spyOn(console, "error")
        spyOn(console, "warn").andCallThrough()
        expect(-> atom.packages.activatePackage('package-without-module')).not.toThrow()
        expect(console.error).not.toHaveBeenCalled()
        expect(console.warn).not.toHaveBeenCalled()

    describe "when the package does not export an activate function", ->
      it "activates the package and does not throw an exception or log a warning", ->
        spyOn(console, "warn")
        expect(-> atom.packages.activatePackage('package-with-no-activate')).not.toThrow()

        waitsFor ->
          atom.packages.isPackageActive('package-with-no-activate')

        runs ->
          expect(console.warn).not.toHaveBeenCalled()

    it "passes the activate method the package's previously serialized state if it exists", ->
      pack = null
      waitsForPromise ->
        atom.packages.activatePackage("package-with-serialization").then (p) -> pack = p
      runs ->
        expect(pack.mainModule.someNumber).not.toBe 77
        pack.mainModule.someNumber = 77
        atom.packages.serializePackage("package-with-serialization")
        atom.packages.deactivatePackage("package-with-serialization")
        spyOn(pack.mainModule, 'activate').andCallThrough()
      waitsForPromise ->
        atom.packages.activatePackage("package-with-serialization")
      runs ->
        expect(pack.mainModule.activate).toHaveBeenCalledWith({someNumber: 77})

    it "invokes ::onDidActivatePackage listeners with the activated package", ->
      activatedPackage = null
      atom.packages.onDidActivatePackage (pack) ->
        activatedPackage = pack

      atom.packages.activatePackage('package-with-main')

      waitsFor -> activatedPackage?
      runs -> expect(activatedPackage.name).toBe 'package-with-main'

    describe "when the package's main module throws an error on load", ->
      it "adds a notification instead of throwing an exception", ->
        spyOn(atom, 'inSpecMode').andReturn(false)
        atom.config.set("core.disabledPackages", [])
        addErrorHandler = jasmine.createSpy()
        atom.notifications.onDidAddNotification(addErrorHandler)
        expect(-> atom.packages.activatePackage("package-that-throws-an-exception")).not.toThrow()
        expect(addErrorHandler.callCount).toBe 1
        expect(addErrorHandler.argsForCall[0][0].message).toContain("Failed to load the package-that-throws-an-exception package")
        expect(addErrorHandler.argsForCall[0][0].options.packageName).toEqual "package-that-throws-an-exception"

      it "re-throws the exception in test mode", ->
        atom.config.set("core.disabledPackages", [])
        addErrorHandler = jasmine.createSpy()
        expect(-> atom.packages.activatePackage("package-that-throws-an-exception")).toThrow("This package throws an exception")

    describe "when the package is not found", ->
      it "rejects the promise", ->
        atom.config.set("core.disabledPackages", [])

        onSuccess = jasmine.createSpy('onSuccess')
        onFailure = jasmine.createSpy('onFailure')
        spyOn(console, 'warn')

        atom.packages.activatePackage("this-doesnt-exist").then(onSuccess, onFailure)

        waitsFor "promise to be rejected", ->
          onFailure.callCount > 0

        runs ->
          expect(console.warn.callCount).toBe 1
          expect(onFailure.mostRecentCall.args[0] instanceof Error).toBe true
          expect(onFailure.mostRecentCall.args[0].message).toContain "Failed to load package 'this-doesnt-exist'"

    describe "keymap loading", ->
      describe "when the metadata does not contain a 'keymaps' manifest", ->
        it "loads all the .cson/.json files in the keymaps directory", ->
          element1 = createTestElement('test-1')
          element2 = createTestElement('test-2')
          element3 = createTestElement('test-3')

          expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-z', target: element1)).toHaveLength 0
          expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-z', target: element2)).toHaveLength 0
          expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-z', target: element3)).toHaveLength 0

          waitsForPromise ->
            atom.packages.activatePackage("package-with-keymaps")

          runs ->
            expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-z', target: element1)[0].command).toBe "test-1"
            expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-z', target: element2)[0].command).toBe "test-2"
            expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-z', target: element3)).toHaveLength 0

      describe "when the metadata contains a 'keymaps' manifest", ->
        it "loads only the keymaps specified by the manifest, in the specified order", ->
          element1 = createTestElement('test-1')
          element3 = createTestElement('test-3')

          expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-z', target: element1)).toHaveLength 0

          waitsForPromise ->
            atom.packages.activatePackage("package-with-keymaps-manifest")

          runs ->
            expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-z', target: element1)[0].command).toBe 'keymap-1'
            expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-n', target: element1)[0].command).toBe 'keymap-2'
            expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-y', target: element3)).toHaveLength 0

      describe "when the keymap file is empty", ->
        it "does not throw an error on activation", ->
          waitsForPromise ->
            atom.packages.activatePackage("package-with-empty-keymap")

          runs ->
            expect(atom.packages.isPackageActive("package-with-empty-keymap")).toBe true

      describe "when the package's keymaps have been disabled", ->
        it "does not add the keymaps", ->
          element1 = createTestElement('test-1')

          expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-z', target: element1)).toHaveLength 0

          atom.config.set("core.packagesWithKeymapsDisabled", ["package-with-keymaps-manifest"])

          waitsForPromise ->
            atom.packages.activatePackage("package-with-keymaps-manifest")

          runs ->
            expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-z', target: element1)).toHaveLength 0

      describe "when setting core.packagesWithKeymapsDisabled", ->
        it "ignores package names in the array that aren't loaded", ->
          atom.packages.observePackagesWithKeymapsDisabled()

          expect(-> atom.config.set("core.packagesWithKeymapsDisabled", ["package-does-not-exist"])).not.toThrow()
          expect(-> atom.config.set("core.packagesWithKeymapsDisabled", [])).not.toThrow()

      describe "when the package's keymaps are disabled and re-enabled after it is activated", ->
        it "removes and re-adds the keymaps", ->
          element1 = createTestElement('test-1')
          atom.packages.observePackagesWithKeymapsDisabled()

          waitsForPromise ->
            atom.packages.activatePackage("package-with-keymaps-manifest")

          runs ->
            atom.config.set("core.packagesWithKeymapsDisabled", ['package-with-keymaps-manifest'])
            expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-z', target: element1)).toHaveLength 0

            atom.config.set("core.packagesWithKeymapsDisabled", [])
            expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-z', target: element1)[0].command).toBe 'keymap-1'

      describe "when the package is de-activated and re-activated", ->
        [element, events, userKeymapPath] = []

        beforeEach ->
          userKeymapPath = path.join(temp.mkdirSync(), "user-keymaps.cson")
          spyOn(atom.keymaps, "getUserKeymapPath").andReturn(userKeymapPath)

          element = createTestElement('test-1')
          jasmine.attachToDOM(element)

          events = []
          element.addEventListener 'user-command', (e) -> events.push(e)
          element.addEventListener 'test-1', (e) -> events.push(e)

        afterEach ->
          element.remove()

          # Avoid leaking user keymap subscription
          atom.keymaps.watchSubscriptions[userKeymapPath].dispose()
          delete atom.keymaps.watchSubscriptions[userKeymapPath]

          temp.cleanupSync()

        it "doesn't override user-defined keymaps", ->
          fs.writeFileSync userKeymapPath, """
          ".test-1":
            "ctrl-z": "user-command"
          """
          atom.keymaps.loadUserKeymap()

          waitsForPromise ->
            atom.packages.activatePackage("package-with-keymaps")

          runs ->
            atom.keymaps.handleKeyboardEvent(buildKeydownEvent("z", ctrl: true, target: element))

            expect(events.length).toBe(1)
            expect(events[0].type).toBe("user-command")

            atom.packages.deactivatePackage("package-with-keymaps")

          waitsForPromise ->
            atom.packages.activatePackage("package-with-keymaps")

          runs ->
            atom.keymaps.handleKeyboardEvent(buildKeydownEvent("z", ctrl: true, target: element))

            expect(events.length).toBe(2)
            expect(events[1].type).toBe("user-command")

    describe "menu loading", ->
      beforeEach ->
        atom.contextMenu.definitions = []
        atom.menu.template = []

      describe "when the metadata does not contain a 'menus' manifest", ->
        it "loads all the .cson/.json files in the menus directory", ->
          element = createTestElement('test-1')

          expect(atom.contextMenu.templateForElement(element)).toEqual []

          waitsForPromise ->
            atom.packages.activatePackage("package-with-menus")

          runs ->
            expect(atom.menu.template.length).toBe 2
            expect(atom.menu.template[0].label).toBe "Second to Last"
            expect(atom.menu.template[1].label).toBe "Last"
            expect(atom.contextMenu.templateForElement(element)[0].label).toBe "Menu item 1"
            expect(atom.contextMenu.templateForElement(element)[1].label).toBe "Menu item 2"
            expect(atom.contextMenu.templateForElement(element)[2].label).toBe "Menu item 3"

      describe "when the metadata contains a 'menus' manifest", ->
        it "loads only the menus specified by the manifest, in the specified order", ->
          element = createTestElement('test-1')

          expect(atom.contextMenu.templateForElement(element)).toEqual []

          waitsForPromise ->
            atom.packages.activatePackage("package-with-menus-manifest")

          runs ->
            expect(atom.menu.template[0].label).toBe "Second to Last"
            expect(atom.menu.template[1].label).toBe "Last"
            expect(atom.contextMenu.templateForElement(element)[0].label).toBe "Menu item 2"
            expect(atom.contextMenu.templateForElement(element)[1].label).toBe "Menu item 1"
            expect(atom.contextMenu.templateForElement(element)[2]).toBeUndefined()

      describe "when the menu file is empty", ->
        it "does not throw an error on activation", ->
          waitsForPromise ->
            atom.packages.activatePackage("package-with-empty-menu")

          runs ->
            expect(atom.packages.isPackageActive("package-with-empty-menu")).toBe true

    describe "stylesheet loading", ->
      describe "when the metadata contains a 'styleSheets' manifest", ->
        it "loads style sheets from the styles directory as specified by the manifest", ->
          one = require.resolve("./fixtures/packages/package-with-style-sheets-manifest/styles/1.css")
          two = require.resolve("./fixtures/packages/package-with-style-sheets-manifest/styles/2.less")
          three = require.resolve("./fixtures/packages/package-with-style-sheets-manifest/styles/3.css")

          expect(atom.themes.stylesheetElementForId(one)).toBeNull()
          expect(atom.themes.stylesheetElementForId(two)).toBeNull()
          expect(atom.themes.stylesheetElementForId(three)).toBeNull()

          waitsForPromise ->
            atom.packages.activatePackage("package-with-style-sheets-manifest")

          runs ->
            expect(atom.themes.stylesheetElementForId(one)).not.toBeNull()
            expect(atom.themes.stylesheetElementForId(two)).not.toBeNull()
            expect(atom.themes.stylesheetElementForId(three)).toBeNull()

            expect(getComputedStyle(document.querySelector('#jasmine-content')).fontSize).toBe '1px'

      describe "when the metadata does not contain a 'styleSheets' manifest", ->
        it "loads all style sheets from the styles directory", ->
          one = require.resolve("./fixtures/packages/package-with-styles/styles/1.css")
          two = require.resolve("./fixtures/packages/package-with-styles/styles/2.less")
          three = require.resolve("./fixtures/packages/package-with-styles/styles/3.test-context.css")
          four = require.resolve("./fixtures/packages/package-with-styles/styles/4.css")

          expect(atom.themes.stylesheetElementForId(one)).toBeNull()
          expect(atom.themes.stylesheetElementForId(two)).toBeNull()
          expect(atom.themes.stylesheetElementForId(three)).toBeNull()
          expect(atom.themes.stylesheetElementForId(four)).toBeNull()

          waitsForPromise ->
            atom.packages.activatePackage("package-with-styles")

          runs ->
            expect(atom.themes.stylesheetElementForId(one)).not.toBeNull()
            expect(atom.themes.stylesheetElementForId(two)).not.toBeNull()
            expect(atom.themes.stylesheetElementForId(three)).not.toBeNull()
            expect(atom.themes.stylesheetElementForId(four)).not.toBeNull()
            expect(getComputedStyle(document.querySelector('#jasmine-content')).fontSize).toBe '3px'

      it "assigns the stylesheet's context based on the filename", ->
        waitsForPromise ->
          atom.packages.activatePackage("package-with-styles")

        runs ->
          count = 0

          for styleElement in atom.styles.getStyleElements()
            if styleElement.sourcePath.match /1.css/
              expect(styleElement.context).toBe undefined
              count++

            if styleElement.sourcePath.match /2.less/
              expect(styleElement.context).toBe undefined
              count++

            if styleElement.sourcePath.match /3.test-context.css/
              expect(styleElement.context).toBe 'test-context'
              count++

            if styleElement.sourcePath.match /4.css/
              expect(styleElement.context).toBe undefined
              count++

          expect(count).toBe 4

    describe "grammar loading", ->
      it "loads the package's grammars", ->
        waitsForPromise ->
          atom.packages.activatePackage('package-with-grammars')

        runs ->
          expect(atom.grammars.selectGrammar('a.alot').name).toBe 'Alot'
          expect(atom.grammars.selectGrammar('a.alittle').name).toBe 'Alittle'

    describe "scoped-property loading", ->
      it "loads the scoped properties", ->
        waitsForPromise ->
          atom.packages.activatePackage("package-with-settings")

        runs ->
          expect(atom.config.get 'editor.increaseIndentPattern', scope: ['.source.omg']).toBe '^a'

    describe "service registration", ->
      it "registers the package's provided and consumed services", ->
        consumerModule = require "./fixtures/packages/package-with-consumed-services"
        firstServiceV3Disposed = false
        firstServiceV4Disposed = false
        secondServiceDisposed = false
        spyOn(consumerModule, 'consumeFirstServiceV3').andReturn(new Disposable -> firstServiceV3Disposed = true)
        spyOn(consumerModule, 'consumeFirstServiceV4').andReturn(new Disposable -> firstServiceV4Disposed = true)
        spyOn(consumerModule, 'consumeSecondService').andReturn(new Disposable -> secondServiceDisposed = true)

        waitsForPromise ->
          atom.packages.activatePackage("package-with-consumed-services")

        waitsForPromise ->
          atom.packages.activatePackage("package-with-provided-services")

        runs ->
          expect(consumerModule.consumeFirstServiceV3.callCount).toBe(1)
          expect(consumerModule.consumeFirstServiceV3).toHaveBeenCalledWith('first-service-v3')
          expect(consumerModule.consumeFirstServiceV4).toHaveBeenCalledWith('first-service-v4')
          expect(consumerModule.consumeSecondService).toHaveBeenCalledWith('second-service')

          consumerModule.consumeFirstServiceV3.reset()
          consumerModule.consumeFirstServiceV4.reset()
          consumerModule.consumeSecondService.reset()

          atom.packages.deactivatePackage("package-with-provided-services")

          expect(firstServiceV3Disposed).toBe true
          expect(firstServiceV4Disposed).toBe true
          expect(secondServiceDisposed).toBe true

          atom.packages.deactivatePackage("package-with-consumed-services")

        waitsForPromise ->
          atom.packages.activatePackage("package-with-provided-services")

        runs ->
          expect(consumerModule.consumeFirstServiceV3).not.toHaveBeenCalled()
          expect(consumerModule.consumeFirstServiceV4).not.toHaveBeenCalled()
          expect(consumerModule.consumeSecondService).not.toHaveBeenCalled()

      it "ignores provided and consumed services that do not exist", ->
        addErrorHandler = jasmine.createSpy()
        atom.notifications.onDidAddNotification(addErrorHandler)

        waitsForPromise ->
          atom.packages.activatePackage("package-with-missing-consumed-services")

        waitsForPromise ->
          atom.packages.activatePackage("package-with-missing-provided-services")

        runs ->
          expect(atom.packages.isPackageActive("package-with-missing-consumed-services")).toBe true
          expect(atom.packages.isPackageActive("package-with-missing-provided-services")).toBe true
          expect(addErrorHandler.callCount).toBe 0

  describe "::serialize", ->
    it "does not serialize packages that threw an error during activation", ->
      spyOn(atom, 'inSpecMode').andReturn(false)
      spyOn(console, 'warn')
      badPack = null
      waitsForPromise ->
        atom.packages.activatePackage("package-that-throws-on-activate").then (p) -> badPack = p

      runs ->
        spyOn(badPack.mainModule, 'serialize').andCallThrough()

        atom.packages.serialize()
        expect(badPack.mainModule.serialize).not.toHaveBeenCalled()

    it "absorbs exceptions that are thrown by the package module's serialize method", ->
      spyOn(console, 'error')

      waitsForPromise ->
        atom.packages.activatePackage('package-with-serialize-error')

      waitsForPromise ->
        atom.packages.activatePackage('package-with-serialization')

      runs ->
        atom.packages.serialize()
        expect(atom.packages.packageStates['package-with-serialize-error']).toBeUndefined()
        expect(atom.packages.packageStates['package-with-serialization']).toEqual someNumber: 1
        expect(console.error).toHaveBeenCalled()

  describe "::deactivatePackages()", ->
    it "deactivates all packages but does not serialize them", ->
      [pack1, pack2] = []

      waitsForPromise ->
        atom.packages.activatePackage("package-with-deactivate").then (p) -> pack1 = p
        atom.packages.activatePackage("package-with-serialization").then (p) -> pack2 = p

      runs ->
        spyOn(pack1.mainModule, 'deactivate')
        spyOn(pack2.mainModule, 'serialize')
        atom.packages.deactivatePackages()

        expect(pack1.mainModule.deactivate).toHaveBeenCalled()
        expect(pack2.mainModule.serialize).not.toHaveBeenCalled()

  describe "::deactivatePackage(id)", ->
    afterEach ->
      atom.packages.unloadPackages()

    it "calls `deactivate` on the package's main module if activate was successful", ->
      spyOn(atom, 'inSpecMode').andReturn(false)
      pack = null
      waitsForPromise ->
        atom.packages.activatePackage("package-with-deactivate").then (p) -> pack = p

      runs ->
        expect(atom.packages.isPackageActive("package-with-deactivate")).toBeTruthy()
        spyOn(pack.mainModule, 'deactivate').andCallThrough()

        atom.packages.deactivatePackage("package-with-deactivate")
        expect(pack.mainModule.deactivate).toHaveBeenCalled()
        expect(atom.packages.isPackageActive("package-with-module")).toBeFalsy()

        spyOn(console, 'warn')

      badPack = null
      waitsForPromise ->
        atom.packages.activatePackage("package-that-throws-on-activate").then (p) -> badPack = p

      runs ->
        expect(atom.packages.isPackageActive("package-that-throws-on-activate")).toBeTruthy()
        spyOn(badPack.mainModule, 'deactivate').andCallThrough()

        atom.packages.deactivatePackage("package-that-throws-on-activate")
        expect(badPack.mainModule.deactivate).not.toHaveBeenCalled()
        expect(atom.packages.isPackageActive("package-that-throws-on-activate")).toBeFalsy()

    it "absorbs exceptions that are thrown by the package module's deactivate method", ->
      spyOn(console, 'error')

      waitsForPromise ->
        atom.packages.activatePackage("package-that-throws-on-deactivate")

      runs ->
        expect(-> atom.packages.deactivatePackage("package-that-throws-on-deactivate")).not.toThrow()
        expect(console.error).toHaveBeenCalled()

    it "removes the package's grammars", ->
      waitsForPromise ->
        atom.packages.activatePackage('package-with-grammars')

      runs ->
        atom.packages.deactivatePackage('package-with-grammars')
        expect(atom.grammars.selectGrammar('a.alot').name).toBe 'Null Grammar'
        expect(atom.grammars.selectGrammar('a.alittle').name).toBe 'Null Grammar'

    it "removes the package's keymaps", ->
      waitsForPromise ->
        atom.packages.activatePackage('package-with-keymaps')

      runs ->
        atom.packages.deactivatePackage('package-with-keymaps')
        expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-z', target: createTestElement('test-1'))).toHaveLength 0
        expect(atom.keymaps.findKeyBindings(keystrokes: 'ctrl-z', target: createTestElement('test-2'))).toHaveLength 0

    it "removes the package's stylesheets", ->
      waitsForPromise ->
        atom.packages.activatePackage('package-with-styles')

      runs ->
        atom.packages.deactivatePackage('package-with-styles')
        one = require.resolve("./fixtures/packages/package-with-style-sheets-manifest/styles/1.css")
        two = require.resolve("./fixtures/packages/package-with-style-sheets-manifest/styles/2.less")
        three = require.resolve("./fixtures/packages/package-with-style-sheets-manifest/styles/3.css")
        expect(atom.themes.stylesheetElementForId(one)).not.toExist()
        expect(atom.themes.stylesheetElementForId(two)).not.toExist()
        expect(atom.themes.stylesheetElementForId(three)).not.toExist()

    it "removes the package's scoped-properties", ->
      waitsForPromise ->
        atom.packages.activatePackage("package-with-settings")

      runs ->
        expect(atom.config.get 'editor.increaseIndentPattern', scope: ['.source.omg']).toBe '^a'
        atom.packages.deactivatePackage("package-with-settings")
        expect(atom.config.get 'editor.increaseIndentPattern', scope: ['.source.omg']).toBeUndefined()

    it "invokes ::onDidDeactivatePackage listeners with the deactivated package", ->
      waitsForPromise ->
        atom.packages.activatePackage("package-with-main")

      runs ->
        deactivatedPackage = null
        atom.packages.onDidDeactivatePackage (pack) -> deactivatedPackage = pack
        atom.packages.deactivatePackage("package-with-main")
        expect(deactivatedPackage.name).toBe "package-with-main"

  describe "::activate()", ->
    beforeEach ->
      spyOn(atom, 'inSpecMode').andReturn(false)
      jasmine.snapshotDeprecations()
      spyOn(console, 'warn')
      atom.packages.loadPackages()

      loadedPackages = atom.packages.getLoadedPackages()
      expect(loadedPackages.length).toBeGreaterThan 0

    afterEach ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

      jasmine.restoreDeprecationsSnapshot()

    it "sets hasActivatedInitialPackages", ->
      spyOn(atom.styles, 'getUserStyleSheetPath').andReturn(null)
      spyOn(atom.packages, 'activatePackages')
      expect(atom.packages.hasActivatedInitialPackages()).toBe false
      waitsForPromise -> atom.packages.activate()
      runs -> expect(atom.packages.hasActivatedInitialPackages()).toBe true

    it "activates all the packages, and none of the themes", ->
      packageActivator = spyOn(atom.packages, 'activatePackages')
      themeActivator = spyOn(atom.themes, 'activatePackages')

      atom.packages.activate()

      expect(packageActivator).toHaveBeenCalled()
      expect(themeActivator).toHaveBeenCalled()

      packages = packageActivator.mostRecentCall.args[0]
      expect(['atom', 'textmate']).toContain(pack.getType()) for pack in packages

      themes = themeActivator.mostRecentCall.args[0]
      expect(['theme']).toContain(theme.getType()) for theme in themes

    it "calls callbacks registered with ::onDidActivateInitialPackages", ->
      package1 = atom.packages.loadPackage('package-with-main')
      package2 = atom.packages.loadPackage('package-with-index')
      package3 = atom.packages.loadPackage('package-with-activation-commands')
      spyOn(atom.packages, 'getLoadedPackages').andReturn([package1, package2, package3])
      spyOn(atom.themes, 'activatePackages')
      activateSpy = jasmine.createSpy('activateSpy')
      atom.packages.onDidActivateInitialPackages(activateSpy)

      atom.packages.activate()
      waitsFor -> activateSpy.callCount > 0
      runs ->
        jasmine.unspy(atom.packages, 'getLoadedPackages')
        expect(package1 in atom.packages.getActivePackages()).toBe true
        expect(package2 in atom.packages.getActivePackages()).toBe true
        expect(package3 in atom.packages.getActivePackages()).toBe false

  describe "::enablePackage(id) and ::disablePackage(id)", ->
    describe "with packages", ->
      it "enables a disabled package", ->
        packageName = 'package-with-main'
        atom.config.pushAtKeyPath('core.disabledPackages', packageName)
        atom.packages.observeDisabledPackages()
        expect(atom.config.get('core.disabledPackages')).toContain packageName

        pack = atom.packages.enablePackage(packageName)
        loadedPackages = atom.packages.getLoadedPackages()
        activatedPackages = null
        waitsFor ->
          activatedPackages = atom.packages.getActivePackages()
          activatedPackages.length > 0

        runs ->
          expect(loadedPackages).toContain(pack)
          expect(activatedPackages).toContain(pack)
          expect(atom.config.get('core.disabledPackages')).not.toContain packageName

      it "disables an enabled package", ->
        packageName = 'package-with-main'
        waitsForPromise ->
          atom.packages.activatePackage(packageName)

        runs ->
          atom.packages.observeDisabledPackages()
          expect(atom.config.get('core.disabledPackages')).not.toContain packageName

          pack = atom.packages.disablePackage(packageName)

          activatedPackages = atom.packages.getActivePackages()
          expect(activatedPackages).not.toContain(pack)
          expect(atom.config.get('core.disabledPackages')).toContain packageName

      it "returns null if the package cannot be loaded", ->
        spyOn(console, 'warn')
        expect(atom.packages.enablePackage("this-doesnt-exist")).toBeNull()
        expect(console.warn.callCount).toBe 1

      it "does not disable an already disabled package", ->
        packageName = 'package-with-main'
        atom.config.pushAtKeyPath('core.disabledPackages', packageName)
        atom.packages.observeDisabledPackages()
        expect(atom.config.get('core.disabledPackages')).toContain packageName

        atom.packages.disablePackage(packageName)
        packagesDisabled = atom.config.get('core.disabledPackages').filter((pack) -> pack is packageName)
        expect(packagesDisabled.length).toEqual 1

    describe "with themes", ->
      didChangeActiveThemesHandler = null

      beforeEach ->
        waitsForPromise ->
          atom.themes.activateThemes()

      afterEach ->
        atom.themes.deactivateThemes()

      it "enables and disables a theme", ->
        packageName = 'theme-with-package-file'

        expect(atom.config.get('core.themes')).not.toContain packageName
        expect(atom.config.get('core.disabledPackages')).not.toContain packageName

        # enabling of theme
        pack = atom.packages.enablePackage(packageName)

        waitsFor 'theme to enable', 500, ->
          pack in atom.packages.getActivePackages()

        runs ->
          expect(atom.config.get('core.themes')).toContain packageName
          expect(atom.config.get('core.disabledPackages')).not.toContain packageName

          didChangeActiveThemesHandler = jasmine.createSpy('didChangeActiveThemesHandler')
          didChangeActiveThemesHandler.reset()
          atom.themes.onDidChangeActiveThemes didChangeActiveThemesHandler

          pack = atom.packages.disablePackage(packageName)

        waitsFor 'did-change-active-themes event to fire', 500, ->
          didChangeActiveThemesHandler.callCount is 1

        runs ->
          expect(atom.packages.getActivePackages()).not.toContain pack
          expect(atom.config.get('core.themes')).not.toContain packageName
          expect(atom.config.get('core.themes')).not.toContain packageName
          expect(atom.config.get('core.disabledPackages')).not.toContain packageName
