{$, $$} = require '../src/space-pen-extensions'
Package = require '../src/package'
{Disposable} = require 'atom'

describe "PackageManager", ->
  workspaceElement = null

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)

  describe "::loadPackage(name)", ->
    beforeEach ->
      atom.config.set("core.disabledPackages", [])

    it "returns the package", ->
      pack = atom.packages.loadPackage("package-with-index")
      expect(pack instanceof Package).toBe true
      expect(pack.metadata.name).toBe "package-with-index"

    it "returns the package if it has an invalid keymap", ->
      pack = atom.packages.loadPackage("package-with-broken-keymap")
      expect(pack instanceof Package).toBe true
      expect(pack.metadata.name).toBe "package-with-broken-keymap"

    it "returns the package if it has an invalid stylesheet", ->
      pack = atom.packages.loadPackage("package-with-invalid-styles")
      expect(pack instanceof Package).toBe true
      expect(pack.metadata.name).toBe "package-with-invalid-styles"
      expect(pack.stylesheets.length).toBe 0

    it "returns null if the package has an invalid package.json", ->
      addErrorHandler = jasmine.createSpy()
      atom.notifications.onDidAddNotification(addErrorHandler)
      expect(atom.packages.loadPackage("package-with-broken-package-json")).toBeNull()
      expect(addErrorHandler.callCount).toBe 1
      expect(addErrorHandler.argsForCall[0][0].message).toContain("Failed to load the package-with-broken-package-json package")

    it "returns null if the package is not found in any package directory", ->
      spyOn(console, 'warn')
      expect(atom.packages.loadPackage("this-package-cannot-be-found")).toBeNull()
      expect(console.warn.callCount).toBe(1)
      expect(console.warn.argsForCall[0][0]).toContain("Could not resolve")

    it "invokes ::onDidLoadPackage listeners with the loaded package", ->
      loadedPackage = null
      atom.packages.onDidLoadPackage (pack) -> loadedPackage = pack

      atom.packages.loadPackage("package-with-main")

      expect(loadedPackage.name).toBe "package-with-main"

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

      describe "when a package has configDefaults", ->
        beforeEach ->
          jasmine.snapshotDeprecations()

        afterEach ->
          jasmine.restoreDeprecationsSnapshot()

        it "still assigns configDefaults from the module though deprecated", ->

          expect(atom.config.get('package-with-config-defaults.numbers.one')).toBeUndefined()

          waitsForPromise ->
            atom.packages.activatePackage('package-with-config-defaults')

          runs ->
            expect(atom.config.get('package-with-config-defaults.numbers.one')).toBe 1
            expect(atom.config.get('package-with-config-defaults.numbers.two')).toBe 2

      describe "when the package metadata includes `activationCommands`", ->
        [mainModule, promise, workspaceCommandListener] = []

        beforeEach ->
          jasmine.attachToDOM(workspaceElement)
          mainModule = require './fixtures/packages/package-with-activation-commands/index'
          mainModule.legacyActivationCommandCallCount = 0
          mainModule.activationCommandCallCount = 0
          spyOn(mainModule, 'activate').andCallThrough()
          spyOn(Package.prototype, 'requireMainModule').andCallThrough()

          workspaceCommandListener = jasmine.createSpy('workspaceCommandListener')
          atom.commands.add '.workspace', 'activation-command', workspaceCommandListener

          promise = atom.packages.activatePackage('package-with-activation-commands')

        it "defers requiring/activating the main module until an activation event bubbles to the root view", ->
          expect(promise.isFulfilled()).not.toBeTruthy()
          workspaceElement.dispatchEvent(new CustomEvent('activation-command', bubbles: true))

          waitsForPromise ->
            promise

        it "triggers the activation event on all handlers registered during activation", ->
          waitsForPromise ->
            atom.workspace.open()

          runs ->
            editorView = atom.views.getView(atom.workspace.getActiveTextEditor()).__spacePenView
            legacyCommandListener = jasmine.createSpy("legacyCommandListener")
            editorView.command 'activation-command', legacyCommandListener
            editorCommandListener = jasmine.createSpy("editorCommandListener")
            atom.commands.add 'atom-text-editor', 'activation-command', editorCommandListener
            atom.commands.dispatch(editorView[0], 'activation-command')
            expect(mainModule.activate.callCount).toBe 1
            expect(mainModule.legacyActivationCommandCallCount).toBe 1
            expect(mainModule.activationCommandCallCount).toBe 1
            expect(legacyCommandListener.callCount).toBe 1
            expect(editorCommandListener.callCount).toBe 1
            expect(workspaceCommandListener.callCount).toBe 1
            atom.commands.dispatch(editorView[0], 'activation-command')
            expect(mainModule.legacyActivationCommandCallCount).toBe 2
            expect(mainModule.activationCommandCallCount).toBe 2
            expect(legacyCommandListener.callCount).toBe 2
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
          addErrorHandler = jasmine.createSpy()
          atom.notifications.onDidAddNotification(addErrorHandler)
          expect(-> atom.packages.activatePackage('package-with-invalid-activation-commands')).not.toThrow()
          expect(addErrorHandler.callCount).toBe 1
          expect(addErrorHandler.argsForCall[0][0].message).toContain("Failed to activate the package-with-invalid-activation-commands package")

        it "adds a notification when the context menu is invalid", ->
          addErrorHandler = jasmine.createSpy()
          atom.notifications.onDidAddNotification(addErrorHandler)
          expect(-> atom.packages.activatePackage('package-with-invalid-context-menu')).not.toThrow()
          expect(addErrorHandler.callCount).toBe 1
          expect(addErrorHandler.argsForCall[0][0].message).toContain("Failed to activate the package-with-invalid-context-menu package")

        it "adds a notification when the grammar is invalid", ->
          addErrorHandler = jasmine.createSpy()
          atom.notifications.onDidAddNotification(addErrorHandler)

          expect(-> atom.packages.activatePackage('package-with-invalid-grammar')).not.toThrow()

          waitsFor ->
            addErrorHandler.callCount > 0

          runs ->
            expect(addErrorHandler.callCount).toBe 1
            expect(addErrorHandler.argsForCall[0][0].message).toContain("Failed to load a package-with-invalid-grammar package grammar")

        it "adds a notification when the settings are invalid", ->
          addErrorHandler = jasmine.createSpy()
          atom.notifications.onDidAddNotification(addErrorHandler)

          expect(-> atom.packages.activatePackage('package-with-invalid-settings')).not.toThrow()

          waitsFor ->
            addErrorHandler.callCount > 0

          runs ->
            expect(addErrorHandler.callCount).toBe 1
            expect(addErrorHandler.argsForCall[0][0].message).toContain("Failed to load the package-with-invalid-settings package settings")

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

    describe "when the package throws an error while loading", ->
      it "adds a notification instead of throwing an exception", ->
        atom.config.set("core.disabledPackages", [])
        addErrorHandler = jasmine.createSpy()
        atom.notifications.onDidAddNotification(addErrorHandler)
        expect(-> atom.packages.activatePackage("package-that-throws-an-exception")).not.toThrow()
        expect(addErrorHandler.callCount).toBe 1
        expect(addErrorHandler.argsForCall[0][0].message).toContain("Failed to load the package-that-throws-an-exception package")

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
          element1 = $$ -> @div class: 'test-1'
          element2 = $$ -> @div class: 'test-2'
          element3 = $$ -> @div class: 'test-3'

          expect(atom.keymaps.findKeyBindings(keystrokes:'ctrl-z', target:element1[0])).toHaveLength 0
          expect(atom.keymaps.findKeyBindings(keystrokes:'ctrl-z', target:element2[0])).toHaveLength 0
          expect(atom.keymaps.findKeyBindings(keystrokes:'ctrl-z', target:element3[0])).toHaveLength 0

          waitsForPromise ->
            atom.packages.activatePackage("package-with-keymaps")

          runs ->
            expect(atom.keymaps.findKeyBindings(keystrokes:'ctrl-z', target:element1[0])[0].command).toBe "test-1"
            expect(atom.keymaps.findKeyBindings(keystrokes:'ctrl-z', target:element2[0])[0].command).toBe "test-2"
            expect(atom.keymaps.findKeyBindings(keystrokes:'ctrl-z', target:element3[0])).toHaveLength 0

      describe "when the metadata contains a 'keymaps' manifest", ->
        it "loads only the keymaps specified by the manifest, in the specified order", ->
          element1 = $$ -> @div class: 'test-1'
          element3 = $$ -> @div class: 'test-3'

          expect(atom.keymaps.findKeyBindings(keystrokes:'ctrl-z', target:element1[0])).toHaveLength 0

          waitsForPromise ->
            atom.packages.activatePackage("package-with-keymaps-manifest")

          runs ->
            expect(atom.keymaps.findKeyBindings(keystrokes:'ctrl-z', target:element1[0])[0].command).toBe 'keymap-1'
            expect(atom.keymaps.findKeyBindings(keystrokes:'ctrl-n', target:element1[0])[0].command).toBe 'keymap-2'
            expect(atom.keymaps.findKeyBindings(keystrokes:'ctrl-y', target:element3[0])).toHaveLength 0

      describe "when the keymap file is empty", ->
        it "does not throw an error on activation", ->
          waitsForPromise ->
            atom.packages.activatePackage("package-with-empty-keymap")

          runs ->
            expect(atom.packages.isPackageActive("package-with-empty-keymap")).toBe true

    describe "menu loading", ->
      beforeEach ->
        atom.contextMenu.definitions = []
        atom.menu.template = []

      describe "when the metadata does not contain a 'menus' manifest", ->
        it "loads all the .cson/.json files in the menus directory", ->
          element = ($$ -> @div class: 'test-1')[0]

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
          element = ($$ -> @div class: 'test-1')[0]

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

          one = atom.themes.stringToId(one)
          two = atom.themes.stringToId(two)
          three = atom.themes.stringToId(three)

          expect(atom.themes.stylesheetElementForId(one)).toBeNull()
          expect(atom.themes.stylesheetElementForId(two)).toBeNull()
          expect(atom.themes.stylesheetElementForId(three)).toBeNull()

          waitsForPromise ->
            atom.packages.activatePackage("package-with-style-sheets-manifest")

          runs ->
            expect(atom.themes.stylesheetElementForId(one)).not.toBeNull()
            expect(atom.themes.stylesheetElementForId(two)).not.toBeNull()
            expect(atom.themes.stylesheetElementForId(three)).toBeNull()
            expect($('#jasmine-content').css('font-size')).toBe '1px'

      describe "when the metadata does not contain a 'styleSheets' manifest", ->
        it "loads all style sheets from the styles directory", ->
          one = require.resolve("./fixtures/packages/package-with-styles/styles/1.css")
          two = require.resolve("./fixtures/packages/package-with-styles/styles/2.less")
          three = require.resolve("./fixtures/packages/package-with-styles/styles/3.test-context.css")
          four = require.resolve("./fixtures/packages/package-with-styles/styles/4.css")

          one = atom.themes.stringToId(one)
          two = atom.themes.stringToId(two)
          three = atom.themes.stringToId(three)
          four = atom.themes.stringToId(four)

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
            expect($('#jasmine-content').css('font-size')).toBe '3px'

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

  describe "::deactivatePackage(id)", ->
    afterEach ->
      atom.packages.unloadPackages()

    it "calls `deactivate` on the package's main module if activate was successful", ->
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

    it "does not serialize packages that have not been activated called on their main module", ->
      spyOn(console, 'warn')
      badPack = null
      waitsForPromise ->
        atom.packages.activatePackage("package-that-throws-on-activate").then (p) -> badPack = p

      runs ->
        spyOn(badPack.mainModule, 'serialize').andCallThrough()

        atom.packages.deactivatePackage("package-that-throws-on-activate")
        expect(badPack.mainModule.serialize).not.toHaveBeenCalled()

    it "absorbs exceptions that are thrown by the package module's serialize method", ->
      spyOn(console, 'error')

      waitsForPromise ->
        atom.packages.activatePackage('package-with-serialize-error')

      waitsForPromise ->
        atom.packages.activatePackage('package-with-serialization')

      runs ->
        atom.packages.deactivatePackages()
        expect(atom.packages.packageStates['package-with-serialize-error']).toBeUndefined()
        expect(atom.packages.packageStates['package-with-serialization']).toEqual someNumber: 1
        expect(console.error).toHaveBeenCalled()

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
        expect(atom.keymaps.findKeyBindings(keystrokes:'ctrl-z', target: ($$ -> @div class: 'test-1')[0])).toHaveLength 0
        expect(atom.keymaps.findKeyBindings(keystrokes:'ctrl-z', target: ($$ -> @div class: 'test-2')[0])).toHaveLength 0

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
      jasmine.snapshotDeprecations()
      spyOn(console, 'warn')
      atom.packages.loadPackages()

      loadedPackages = atom.packages.getLoadedPackages()
      expect(loadedPackages.length).toBeGreaterThan 0

    afterEach ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

      GrammarRegistry = require '../src/grammar-registry'
      atom.grammars = window.syntax = new GrammarRegistry()
      jasmine.restoreDeprecationsSnapshot()

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
      spyOn(atom.packages, 'getLoadedPackages').andReturn([package1, package2])

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

        waitsFor ->
          pack in atom.packages.getActivePackages()

        runs ->
          expect(atom.config.get('core.themes')).toContain packageName
          expect(atom.config.get('core.disabledPackages')).not.toContain packageName

          didChangeActiveThemesHandler = jasmine.createSpy('didChangeActiveThemesHandler')
          didChangeActiveThemesHandler.reset()
          atom.themes.onDidChangeActiveThemes didChangeActiveThemesHandler

          pack = atom.packages.disablePackage(packageName)

        waitsFor ->
          didChangeActiveThemesHandler.callCount is 1

        runs ->
          expect(atom.packages.getActivePackages()).not.toContain pack
          expect(atom.config.get('core.themes')).not.toContain packageName
          expect(atom.config.get('core.themes')).not.toContain packageName
          expect(atom.config.get('core.disabledPackages')).not.toContain packageName
