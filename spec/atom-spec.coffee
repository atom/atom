{$, $$, fs, WorkspaceView}  = require 'atom'
Exec = require('child_process').exec
path = require 'path'
ThemeManager = require '../src/theme-manager'

describe "the `atom` global", ->
  beforeEach ->
    atom.workspaceView = new WorkspaceView

  describe "package lifecycle methods", ->
    describe ".loadPackage(name)", ->
      describe "when the package has deferred deserializers", ->
        it "requires the package's main module if one of its deferred deserializers is referenced", ->
          pack = atom.packages.loadPackage('package-with-activation-events')
          spyOn(pack, 'activateStylesheets').andCallThrough()
          expect(pack.mainModule).toBeNull()
          object = atom.deserializers.deserialize({deserializer: 'Foo', data: 5})
          expect(pack.mainModule).toBeDefined()
          expect(object.constructor.name).toBe 'Foo'
          expect(object.data).toBe 5
          expect(pack.activateStylesheets).toHaveBeenCalled()

        it "continues if the package has an invalid package.json", ->
          spyOn(console, 'warn')
          atom.config.set("core.disabledPackages", [])
          expect(-> atom.packages.loadPackage("package-with-broken-package-json")).not.toThrow()

        it "continues if the package has an invalid keymap", ->
          atom.config.set("core.disabledPackages", [])
          expect(-> atom.packages.loadPackage("package-with-broken-keymap")).not.toThrow()

    describe ".unloadPackage(name)", ->
      describe "when the package is active", ->
        it "throws an error", ->
          pack = atom.packages.activatePackage('package-with-main')
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

    describe ".activatePackage(id)", ->
      describe "atom packages", ->
        describe "when the package has a main module", ->
          describe "when the metadata specifies a main module path˜", ->
            it "requires the module at the specified path", ->
              mainModule = require('./fixtures/packages/package-with-main/main-module')
              spyOn(mainModule, 'activate')
              pack = atom.packages.activatePackage('package-with-main')
              expect(mainModule.activate).toHaveBeenCalled()
              expect(pack.mainModule).toBe mainModule

          describe "when the metadata does not specify a main module", ->
            it "requires index.coffee", ->
              indexModule = require('./fixtures/packages/package-with-index/index')
              spyOn(indexModule, 'activate')
              pack = atom.packages.activatePackage('package-with-index')
              expect(indexModule.activate).toHaveBeenCalled()
              expect(pack.mainModule).toBe indexModule

          it "assigns config defaults from the module", ->
            expect(atom.config.get('package-with-config-defaults.numbers.one')).toBeUndefined()
            atom.packages.activatePackage('package-with-config-defaults')
            expect(atom.config.get('package-with-config-defaults.numbers.one')).toBe 1
            expect(atom.config.get('package-with-config-defaults.numbers.two')).toBe 2

          describe "when the package metadata includes activation events", ->
            [mainModule, pack] = []

            beforeEach ->
              mainModule = require './fixtures/packages/package-with-activation-events/index'
              spyOn(mainModule, 'activate').andCallThrough()
              AtomPackage = require '../src/atom-package'
              spyOn(AtomPackage.prototype, 'requireMainModule').andCallThrough()
              pack = atom.packages.activatePackage('package-with-activation-events')

            it "defers requiring/activating the main module until an activation event bubbles to the root view", ->
              expect(pack.requireMainModule).not.toHaveBeenCalled()
              expect(mainModule.activate).not.toHaveBeenCalled()
              atom.workspaceView.trigger 'activation-event'
              expect(mainModule.activate).toHaveBeenCalled()

            it "triggers the activation event on all handlers registered during activation", ->
              atom.workspaceView.openSync()
              editorView = atom.workspaceView.getActiveView()
              eventHandler = jasmine.createSpy("activation-event")
              editorView.command 'activation-event', eventHandler
              editorView.trigger 'activation-event'
              expect(mainModule.activate.callCount).toBe 1
              expect(mainModule.activationEventCallCount).toBe 1
              expect(eventHandler.callCount).toBe 1
              editorView.trigger 'activation-event'
              expect(mainModule.activationEventCallCount).toBe 2
              expect(eventHandler.callCount).toBe 2
              expect(mainModule.activate.callCount).toBe 1

        describe "when the package has no main module", ->
          it "does not throw an exception", ->
            spyOn(console, "error")
            spyOn(console, "warn").andCallThrough()
            expect(-> atom.packages.activatePackage('package-without-module')).not.toThrow()
            expect(console.error).not.toHaveBeenCalled()
            expect(console.warn).not.toHaveBeenCalled()

        it "passes the activate method the package's previously serialized state if it exists", ->
          pack = atom.packages.activatePackage("package-with-serialization")
          expect(pack.mainModule.someNumber).not.toBe 77
          pack.mainModule.someNumber = 77
          atom.packages.deactivatePackage("package-with-serialization")
          spyOn(pack.mainModule, 'activate').andCallThrough()
          atom.packages.activatePackage("package-with-serialization")
          expect(pack.mainModule.activate).toHaveBeenCalledWith({someNumber: 77})

        it "logs warning instead of throwing an exception if the package fails to load", ->
          atom.config.set("core.disabledPackages", [])
          spyOn(console, "warn")
          expect(-> atom.packages.activatePackage("package-that-throws-an-exception")).not.toThrow()
          expect(console.warn).toHaveBeenCalled()

        describe "keymap loading", ->
          describe "when the metadata does not contain a 'keymaps' manifest", ->
            it "loads all the .cson/.json files in the keymaps directory", ->
              element1 = $$ -> @div class: 'test-1'
              element2 = $$ -> @div class: 'test-2'
              element3 = $$ -> @div class: 'test-3'

              expect(atom.keymap.keyBindingsForKeystrokeMatchingElement('ctrl-z', element1)).toHaveLength 0
              expect(atom.keymap.keyBindingsForKeystrokeMatchingElement('ctrl-z', element2)).toHaveLength 0
              expect(atom.keymap.keyBindingsForKeystrokeMatchingElement('ctrl-z', element3)).toHaveLength 0

              atom.packages.activatePackage("package-with-keymaps")

              expect(atom.keymap.keyBindingsForKeystrokeMatchingElement('ctrl-z', element1)[0].command).toBe "test-1"
              expect(atom.keymap.keyBindingsForKeystrokeMatchingElement('ctrl-z', element2)[0].command).toBe "test-2"
              expect(atom.keymap.keyBindingsForKeystrokeMatchingElement('ctrl-z', element3)).toHaveLength 0

          describe "when the metadata contains a 'keymaps' manifest", ->
            it "loads only the keymaps specified by the manifest, in the specified order", ->
              element1 = $$ -> @div class: 'test-1'
              element3 = $$ -> @div class: 'test-3'

              expect(atom.keymap.keyBindingsForKeystrokeMatchingElement('ctrl-z', element1)).toHaveLength 0

              atom.packages.activatePackage("package-with-keymaps-manifest")

              expect(atom.keymap.keyBindingsForKeystrokeMatchingElement('ctrl-z', element1)[0].command).toBe 'keymap-1'
              expect(atom.keymap.keyBindingsForKeystrokeMatchingElement('ctrl-n', element1)[0].command).toBe 'keymap-2'
              expect(atom.keymap.keyBindingsForKeystrokeMatchingElement('ctrl-y', element3)).toHaveLength 0

        describe "menu loading", ->
          beforeEach ->
            atom.contextMenu.definitions = []
            atom.menu.template = []

          describe "when the metadata does not contain a 'menus' manifest", ->
            it "loads all the .cson/.json files in the menus directory", ->
              element = ($$ -> @div class: 'test-1')[0]

              expect(atom.contextMenu.definitionsForElement(element)).toEqual []

              atom.packages.activatePackage("package-with-menus")

              expect(atom.menu.template.length).toBe 2
              expect(atom.menu.template[0].label).toBe "Second to Last"
              expect(atom.menu.template[1].label).toBe "Last"
              expect(atom.contextMenu.definitionsForElement(element)[0].label).toBe "Menu item 1"
              expect(atom.contextMenu.definitionsForElement(element)[1].label).toBe "Menu item 2"
              expect(atom.contextMenu.definitionsForElement(element)[2].label).toBe "Menu item 3"

          describe "when the metadata contains a 'menus' manifest", ->
            it "loads only the menus specified by the manifest, in the specified order", ->
              element = ($$ -> @div class: 'test-1')[0]

              expect(atom.contextMenu.definitionsForElement(element)).toEqual []

              atom.packages.activatePackage("package-with-menus-manifest")

              expect(atom.menu.template[0].label).toBe "Second to Last"
              expect(atom.menu.template[1].label).toBe "Last"
              expect(atom.contextMenu.definitionsForElement(element)[0].label).toBe "Menu item 2"
              expect(atom.contextMenu.definitionsForElement(element)[1].label).toBe "Menu item 1"
              expect(atom.contextMenu.definitionsForElement(element)[2]).toBeUndefined()

        describe "stylesheet loading", ->
          describe "when the metadata contains a 'stylesheets' manifest", ->
            it "loads stylesheets from the stylesheets directory as specified by the manifest", ->
              one = require.resolve("./fixtures/packages/package-with-stylesheets-manifest/stylesheets/1.css")
              two = require.resolve("./fixtures/packages/package-with-stylesheets-manifest/stylesheets/2.less")
              three = require.resolve("./fixtures/packages/package-with-stylesheets-manifest/stylesheets/3.css")

              one = atom.themes.stringToId(one)
              two = atom.themes.stringToId(two)
              three = atom.themes.stringToId(three)

              expect(atom.themes.stylesheetElementForId(one)).not.toExist()
              expect(atom.themes.stylesheetElementForId(two)).not.toExist()
              expect(atom.themes.stylesheetElementForId(three)).not.toExist()

              atom.packages.activatePackage("package-with-stylesheets-manifest")

              expect(atom.themes.stylesheetElementForId(one)).toExist()
              expect(atom.themes.stylesheetElementForId(two)).toExist()
              expect(atom.themes.stylesheetElementForId(three)).not.toExist()
              expect($('#jasmine-content').css('font-size')).toBe '1px'

          describe "when the metadata does not contain a 'stylesheets' manifest", ->
            it "loads all stylesheets from the stylesheets directory", ->
              one = require.resolve("./fixtures/packages/package-with-stylesheets/stylesheets/1.css")
              two = require.resolve("./fixtures/packages/package-with-stylesheets/stylesheets/2.less")
              three = require.resolve("./fixtures/packages/package-with-stylesheets/stylesheets/3.css")


              one = atom.themes.stringToId(one)
              two = atom.themes.stringToId(two)
              three = atom.themes.stringToId(three)

              expect(atom.themes.stylesheetElementForId(one)).not.toExist()
              expect(atom.themes.stylesheetElementForId(two)).not.toExist()
              expect(atom.themes.stylesheetElementForId(three)).not.toExist()

              atom.packages.activatePackage("package-with-stylesheets")
              expect(atom.themes.stylesheetElementForId(one)).toExist()
              expect(atom.themes.stylesheetElementForId(two)).toExist()
              expect(atom.themes.stylesheetElementForId(three)).toExist()
              expect($('#jasmine-content').css('font-size')).toBe '3px'

        describe "grammar loading", ->
          it "loads the package's grammars", ->
            atom.packages.activatePackage('package-with-grammars')
            expect(atom.syntax.selectGrammar('a.alot').name).toBe 'Alot'
            expect(atom.syntax.selectGrammar('a.alittle').name).toBe 'Alittle'

        describe "scoped-property loading", ->
          it "loads the scoped properties", ->
            atom.packages.activatePackage("package-with-scoped-properties")
            expect(atom.syntax.getProperty ['.source.omg'], 'editor.increaseIndentPattern').toBe '^a'

      describe "textmate packages", ->
        it "loads the package's grammars", ->
          expect(atom.syntax.selectGrammar("file.rb").name).toBe "Null Grammar"
          atom.packages.activatePackage('language-ruby', sync: true)
          expect(atom.syntax.selectGrammar("file.rb").name).toBe "Ruby"

        it "translates the package's scoped properties to Atom terms", ->
          expect(atom.syntax.getProperty(['.source.ruby'], 'editor.commentStart')).toBeUndefined()
          atom.packages.activatePackage('language-ruby', sync: true)
          expect(atom.syntax.getProperty(['.source.ruby'], 'editor.commentStart')).toBe '# '

        describe "when the package has no grammars but does have preferences", ->
          it "loads the package's preferences as scoped properties", ->
            jasmine.unspy(window, 'setTimeout')
            spyOn(atom.syntax, 'addProperties').andCallThrough()

            atom.packages.activatePackage('package-with-preferences-tmbundle')

            waitsFor ->
              atom.syntax.addProperties.callCount > 0

            runs ->
              expect(atom.syntax.getProperty(['.source.pref'], 'editor.increaseIndentPattern')).toBe '^abc$'

    describe ".deactivatePackage(id)", ->
      describe "atom packages", ->
        it "calls `deactivate` on the package's main module if activate was successful", ->
          pack = atom.packages.activatePackage("package-with-deactivate")
          expect(atom.packages.isPackageActive("package-with-deactivate")).toBeTruthy()
          spyOn(pack.mainModule, 'deactivate').andCallThrough()

          atom.packages.deactivatePackage("package-with-deactivate")
          expect(pack.mainModule.deactivate).toHaveBeenCalled()
          expect(atom.packages.isPackageActive("package-with-module")).toBeFalsy()

          spyOn(console, 'warn')
          badPack = atom.packages.activatePackage("package-that-throws-on-activate")
          expect(atom.packages.isPackageActive("package-that-throws-on-activate")).toBeTruthy()
          spyOn(badPack.mainModule, 'deactivate').andCallThrough()

          atom.packages.deactivatePackage("package-that-throws-on-activate")
          expect(badPack.mainModule.deactivate).not.toHaveBeenCalled()
          expect(atom.packages.isPackageActive("package-that-throws-on-activate")).toBeFalsy()

        it "does not serialize packages that have not been activated called on their main module", ->
          spyOn(console, 'warn')
          badPack = atom.packages.activatePackage("package-that-throws-on-activate")
          spyOn(badPack.mainModule, 'serialize').andCallThrough()

          atom.packages.deactivatePackage("package-that-throws-on-activate")
          expect(badPack.mainModule.serialize).not.toHaveBeenCalled()

        it "absorbs exceptions that are thrown by the package module's serialize methods", ->
          spyOn(console, 'error')
          atom.packages.activatePackage('package-with-serialize-error',  immediate: true)
          atom.packages.activatePackage('package-with-serialization', immediate: true)
          atom.packages.deactivatePackages()
          expect(atom.packages.packageStates['package-with-serialize-error']).toBeUndefined()
          expect(atom.packages.packageStates['package-with-serialization']).toEqual someNumber: 1
          expect(console.error).toHaveBeenCalled()

        it "removes the package's grammars", ->
          atom.packages.activatePackage('package-with-grammars')
          atom.packages.deactivatePackage('package-with-grammars')
          expect(atom.syntax.selectGrammar('a.alot').name).toBe 'Null Grammar'
          expect(atom.syntax.selectGrammar('a.alittle').name).toBe 'Null Grammar'

        it "removes the package's keymaps", ->
          atom.packages.activatePackage('package-with-keymaps')
          atom.packages.deactivatePackage('package-with-keymaps')
          expect(atom.keymap.keyBindingsForKeystrokeMatchingElement('ctrl-z', $$ -> @div class: 'test-1')).toHaveLength 0
          expect(atom.keymap.keyBindingsForKeystrokeMatchingElement('ctrl-z', $$ -> @div class: 'test-2')).toHaveLength 0

        it "removes the package's stylesheets", ->
          atom.packages.activatePackage('package-with-stylesheets')
          atom.packages.deactivatePackage('package-with-stylesheets')
          one = require.resolve("./fixtures/packages/package-with-stylesheets-manifest/stylesheets/1.css")
          two = require.resolve("./fixtures/packages/package-with-stylesheets-manifest/stylesheets/2.less")
          three = require.resolve("./fixtures/packages/package-with-stylesheets-manifest/stylesheets/3.css")
          expect(atom.themes.stylesheetElementForId(one)).not.toExist()
          expect(atom.themes.stylesheetElementForId(two)).not.toExist()
          expect(atom.themes.stylesheetElementForId(three)).not.toExist()

        it "removes the package's scoped-properties", ->
          atom.packages.activatePackage("package-with-scoped-properties")
          expect(atom.syntax.getProperty ['.source.omg'], 'editor.increaseIndentPattern').toBe '^a'
          atom.packages.deactivatePackage("package-with-scoped-properties")
          expect(atom.syntax.getProperty ['.source.omg'], 'editor.increaseIndentPattern').toBeUndefined()

      describe "textmate packages", ->
        it "removes the package's grammars", ->
          expect(atom.syntax.selectGrammar("file.rb").name).toBe "Null Grammar"
          atom.packages.activatePackage('language-ruby', sync: true)
          expect(atom.syntax.selectGrammar("file.rb").name).toBe "Ruby"
          atom.packages.deactivatePackage('language-ruby')
          expect(atom.syntax.selectGrammar("file.rb").name).toBe "Null Grammar"

        it "removes the package's scoped properties", ->
          atom.packages.activatePackage('language-ruby', sync: true)
          atom.packages.deactivatePackage('language-ruby')
          expect(atom.syntax.getProperty(['.source.ruby'], 'editor.commentStart')).toBeUndefined()

    describe ".activate()", ->
      packageActivator = null
      themeActivator = null

      beforeEach ->
        spyOn(console, 'warn')
        atom.packages.loadPackages()

        loadedPackages = atom.packages.getLoadedPackages()
        expect(loadedPackages.length).toBeGreaterThan 0

        packageActivator = spyOn(atom.packages, 'activatePackages')
        themeActivator = spyOn(atom.themes, 'activatePackages')

      afterEach ->
        atom.packages.unloadPackages()

        Syntax = require '../src/syntax'
        atom.syntax = window.syntax = new Syntax()

      it "activates all the packages, and none of the themes", ->
        atom.packages.activate()

        expect(packageActivator).toHaveBeenCalled()
        expect(themeActivator).toHaveBeenCalled()

        packages = packageActivator.mostRecentCall.args[0]
        expect(['atom', 'textmate']).toContain(pack.getType()) for pack in packages

        themes = themeActivator.mostRecentCall.args[0]
        expect(['theme']).toContain(theme.getType()) for theme in themes

    describe ".en/disablePackage()", ->
      describe "with packages", ->
        it ".enablePackage() enables a disabled package", ->
          packageName = 'package-with-main'
          atom.config.pushAtKeyPath('core.disabledPackages', packageName)
          atom.packages.observeDisabledPackages()
          expect(atom.config.get('core.disabledPackages')).toContain packageName

          pack = atom.packages.enablePackage(packageName)

          loadedPackages = atom.packages.getLoadedPackages()
          activatedPackages = atom.packages.getActivePackages()
          expect(loadedPackages).toContain(pack)
          expect(activatedPackages).toContain(pack)
          expect(atom.config.get('core.disabledPackages')).not.toContain packageName

        it ".disablePackage() disables an enabled package", ->
          packageName = 'package-with-main'
          atom.packages.activatePackage(packageName)
          atom.packages.observeDisabledPackages()
          expect(atom.config.get('core.disabledPackages')).not.toContain packageName

          pack = atom.packages.disablePackage(packageName)

          activatedPackages = atom.packages.getActivePackages()
          expect(activatedPackages).not.toContain(pack)
          expect(atom.config.get('core.disabledPackages')).toContain packageName

      describe "with themes", ->
        beforeEach ->
          atom.themes.activateThemes()

        afterEach ->
          atom.themes.deactivateThemes()
          atom.config.unobserve('core.themes')

        it ".enablePackage() and .disablePackage() enables and disables a theme", ->
          packageName = 'theme-with-package-file'

          expect(atom.config.get('core.themes')).not.toContain packageName
          expect(atom.config.get('core.disabledPackages')).not.toContain packageName

          # enabling of theme
          pack = atom.packages.enablePackage(packageName)
          activatedPackages = atom.packages.getActivePackages()
          expect(activatedPackages).toContain(pack)
          expect(atom.config.get('core.themes')).toContain packageName
          expect(atom.config.get('core.disabledPackages')).not.toContain packageName

          # disabling of theme
          pack = atom.packages.disablePackage(packageName)
          activatedPackages = atom.packages.getActivePackages()
          expect(activatedPackages).not.toContain(pack)
          expect(atom.config.get('core.themes')).not.toContain packageName
          expect(atom.config.get('core.themes')).not.toContain packageName
          expect(atom.config.get('core.disabledPackages')).not.toContain packageName

  describe ".isReleasedVersion()", ->
    it "returns false if the version is a SHA and true otherwise", ->
      version = '0.1.0'
      spyOn(atom, 'getVersion').andCallFake -> version
      expect(atom.isReleasedVersion()).toBe true
      version = '36b5518'
      expect(atom.isReleasedVersion()).toBe false
