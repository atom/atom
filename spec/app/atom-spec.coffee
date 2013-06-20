$ = require 'jquery'
RootView = require 'root-view'
{$$} = require 'space-pen'
fsUtils = require 'fs-utils'
Exec = require('child_process').exec
path = require 'path'

describe "the `atom` global", ->
  beforeEach ->
    window.rootView = new RootView

  describe "package lifecycle methods", ->
    describe ".loadPackage(name)", ->
      describe "when the package has deferred deserializers", ->
        it "requires the package's main module if one of its deferred deserializers is referenced", ->
          pack = atom.loadPackage('package-with-activation-events')
          expect(pack.mainModule).toBeNull()
          object = deserialize({deserializer: 'Foo', data: 5})
          expect(pack.mainModule).toBeDefined()
          expect(object.constructor.name).toBe 'Foo'
          expect(object.data).toBe 5

    describe ".unloadPackage(name)", ->
      describe "when the package is active", ->
        it "throws an error", ->
          pack = atom.activatePackage('package-with-main')
          expect(atom.isPackageLoaded(pack.name)).toBeTruthy()
          expect(atom.isPackageActive(pack.name)).toBeTruthy()
          expect( -> atom.unloadPackage(pack.name)).toThrow()
          expect(atom.isPackageLoaded(pack.name)).toBeTruthy()
          expect(atom.isPackageActive(pack.name)).toBeTruthy()

      describe "when the package is not loaded", ->
        it "throws an error", ->
          expect(atom.isPackageLoaded('unloaded')).toBeFalsy()
          expect( -> atom.unloadPackage('unloaded')).toThrow()
          expect(atom.isPackageLoaded('unloaded')).toBeFalsy()

      describe "when the package is loaded", ->
        it "no longers reports it as being loaded", ->
          pack = atom.loadPackage('package-with-main')
          expect(atom.isPackageLoaded(pack.name)).toBeTruthy()
          atom.unloadPackage(pack.name)
          expect(atom.isPackageLoaded(pack.name)).toBeFalsy()

    describe ".activatePackage(id)", ->
      describe "atom packages", ->
        describe "when the package has a main module", ->
          describe "when the metadata specifies a main module path˜", ->
            it "requires the module at the specified path", ->
              mainModule = require('fixtures/packages/package-with-main/main-module')
              spyOn(mainModule, 'activate')
              pack = atom.activatePackage('package-with-main')
              expect(mainModule.activate).toHaveBeenCalled()
              expect(pack.mainModule).toBe mainModule

          describe "when the metadata does not specify a main module", ->
            it "requires index.coffee", ->
              indexModule = require('fixtures/packages/package-with-index/index')
              spyOn(indexModule, 'activate')
              pack = atom.activatePackage('package-with-index')
              expect(indexModule.activate).toHaveBeenCalled()
              expect(pack.mainModule).toBe indexModule

          it "assigns config defaults from the module", ->
            expect(config.get('package-with-config-defaults.numbers.one')).toBeUndefined()
            atom.activatePackage('package-with-config-defaults')
            expect(config.get('package-with-config-defaults.numbers.one')).toBe 1
            expect(config.get('package-with-config-defaults.numbers.two')).toBe 2

          describe "when the package metadata includes activation events", ->
            [mainModule, pack] = []

            beforeEach ->
              mainModule = require 'fixtures/packages/package-with-activation-events/index'
              spyOn(mainModule, 'activate').andCallThrough()
              AtomPackage = require 'atom-package'
              spyOn(AtomPackage.prototype, 'requireMainModule').andCallThrough()
              pack = atom.activatePackage('package-with-activation-events')

            it "defers requiring/activating the main module until an activation event bubbles to the root view", ->
              expect(pack.requireMainModule).not.toHaveBeenCalled()
              expect(mainModule.activate).not.toHaveBeenCalled()
              rootView.trigger 'activation-event'
              expect(mainModule.activate).toHaveBeenCalled()

            it "triggers the activation event on all handlers registered during activation", ->
              rootView.open()
              editor = rootView.getActiveView()
              eventHandler = jasmine.createSpy("activation-event")
              editor.command 'activation-event', eventHandler
              editor.trigger 'activation-event'
              expect(mainModule.activate.callCount).toBe 1
              expect(mainModule.activationEventCallCount).toBe 1
              expect(eventHandler.callCount).toBe 1
              editor.trigger 'activation-event'
              expect(mainModule.activationEventCallCount).toBe 2
              expect(eventHandler.callCount).toBe 2
              expect(mainModule.activate.callCount).toBe 1

        describe "when the package has no main module", ->
          it "does not throw an exception", ->
            spyOn(console, "error")
            spyOn(console, "warn").andCallThrough()
            expect(-> atom.activatePackage('package-without-module')).not.toThrow()
            expect(console.error).not.toHaveBeenCalled()
            expect(console.warn).not.toHaveBeenCalled()

        it "passes the activate method the package's previously serialized state if it exists", ->
          pack = atom.activatePackage("package-with-serialization")
          expect(pack.mainModule.someNumber).not.toBe 77
          pack.mainModule.someNumber = 77
          atom.deactivatePackage("package-with-serialization")
          spyOn(pack.mainModule, 'activate').andCallThrough()
          atom.activatePackage("package-with-serialization")
          expect(pack.mainModule.activate).toHaveBeenCalledWith({someNumber: 77})

        it "logs warning instead of throwing an exception if the package fails to load", ->
          config.set("core.disabledPackages", [])
          spyOn(console, "warn")
          expect(-> atom.activatePackage("package-that-throws-an-exception")).not.toThrow()
          expect(console.warn).toHaveBeenCalled()

        describe "keymap loading", ->
          describe "when the metadata does not contain a 'keymaps' manifest", ->
            it "loads all the .cson/.json files in the keymaps directory", ->
              element1 = $$ -> @div class: 'test-1'
              element2 = $$ -> @div class: 'test-2'
              element3 = $$ -> @div class: 'test-3'

              expect(keymap.bindingsForElement(element1)['ctrl-z']).toBeUndefined()
              expect(keymap.bindingsForElement(element2)['ctrl-z']).toBeUndefined()
              expect(keymap.bindingsForElement(element3)['ctrl-z']).toBeUndefined()

              atom.activatePackage("package-with-keymaps")

              expect(keymap.bindingsForElement(element1)['ctrl-z']).toBe "test-1"
              expect(keymap.bindingsForElement(element2)['ctrl-z']).toBe "test-2"
              expect(keymap.bindingsForElement(element3)['ctrl-z']).toBeUndefined()

          describe "when the metadata contains a 'keymaps' manifest", ->
            it "loads only the keymaps specified by the manifest, in the specified order", ->
              element1 = $$ -> @div class: 'test-1'
              element3 = $$ -> @div class: 'test-3'

              expect(keymap.bindingsForElement(element1)['ctrl-z']).toBeUndefined()

              atom.activatePackage("package-with-keymaps-manifest")

              expect(keymap.bindingsForElement(element1)['ctrl-z']).toBe 'keymap-1'
              expect(keymap.bindingsForElement(element1)['ctrl-n']).toBe 'keymap-2'
              expect(keymap.bindingsForElement(element3)['ctrl-y']).toBeUndefined()

        describe "stylesheet loading", ->
          describe "when the metadata contains a 'stylesheets' manifest", ->
            it "loads stylesheets from the stylesheets directory as specified by the manifest", ->
              one = fsUtils.resolveOnLoadPath("fixtures/packages/package-with-stylesheets-manifest/stylesheets/1.css")
              two = fsUtils.resolveOnLoadPath("fixtures/packages/package-with-stylesheets-manifest/stylesheets/2.less")
              three = fsUtils.resolveOnLoadPath("fixtures/packages/package-with-stylesheets-manifest/stylesheets/3.css")
              expect(stylesheetElementForId(one)).not.toExist()
              expect(stylesheetElementForId(two)).not.toExist()
              expect(stylesheetElementForId(three)).not.toExist()

              atom.activatePackage("package-with-stylesheets-manifest")

              expect(stylesheetElementForId(one)).toExist()
              expect(stylesheetElementForId(two)).toExist()
              expect(stylesheetElementForId(three)).not.toExist()
              expect($('#jasmine-content').css('font-size')).toBe '1px'

          describe "when the metadata does not contain a 'stylesheets' manifest", ->
            it "loads all stylesheets from the stylesheets directory", ->
              one = fsUtils.resolveOnLoadPath("fixtures/packages/package-with-stylesheets/stylesheets/1.css")
              two = fsUtils.resolveOnLoadPath("fixtures/packages/package-with-stylesheets/stylesheets/2.less")
              three = fsUtils.resolveOnLoadPath("fixtures/packages/package-with-stylesheets/stylesheets/3.css")
              expect(stylesheetElementForId(one)).not.toExist()
              expect(stylesheetElementForId(two)).not.toExist()
              expect(stylesheetElementForId(three)).not.toExist()

              atom.activatePackage("package-with-stylesheets")
              expect(stylesheetElementForId(one)).toExist()
              expect(stylesheetElementForId(two)).toExist()
              expect(stylesheetElementForId(three)).toExist()
              expect($('#jasmine-content').css('font-size')).toBe '3px'

        describe "grammar loading", ->
          it "loads the package's grammars", ->
            atom.activatePackage('package-with-grammars')
            expect(syntax.selectGrammar('a.alot').name).toBe 'Alot'
            expect(syntax.selectGrammar('a.alittle').name).toBe 'Alittle'

        describe "scoped-property loading", ->
          it "loads the scoped properties", ->
            atom.activatePackage("package-with-scoped-properties")
            expect(syntax.getProperty ['.source.omg'], 'editor.increaseIndentPattern').toBe '^a'

      describe "textmate packages", ->
        it "loads the package's grammars", ->
          expect(syntax.selectGrammar("file.rb").name).toBe "Null Grammar"
          atom.activatePackage('ruby-tmbundle', sync: true)
          expect(syntax.selectGrammar("file.rb").name).toBe "Ruby"

        it "translates the package's scoped properties to Atom terms", ->
          expect(syntax.getProperty(['.source.ruby'], 'editor.commentStart')).toBeUndefined()
          atom.activatePackage('ruby-tmbundle', sync: true)
          expect(syntax.getProperty(['.source.ruby'], 'editor.commentStart')).toBe '# '

        describe "when the package has no grammars but does have preferences", ->
          it "loads the package's preferences as scoped properties", ->
            jasmine.unspy(window, 'setTimeout')
            spyOn(syntax, 'addProperties').andCallThrough()

            atom.activatePackage('package-with-preferences-tmbundle')

            waitsFor ->
              syntax.addProperties.callCount > 0
            runs ->
              expect(syntax.getProperty(['.source.pref'], 'editor.increaseIndentPattern')).toBe '^abc$'

    describe ".activatePackageConfig(id)", ->
      it "calls the optional .activateConfigMenu method on the package's main module", ->
        pack = atom.activatePackageConfig('package-with-activate-config')
        expect(pack.mainModule.activateCalled).toBeFalsy()
        expect(pack.mainModule.activateConfigCalled).toBeTruthy()

      it "loads the package's config defaults", ->
        expect(config.get('package-with-config-defaults.numbers.one')).toBeUndefined()
        atom.activatePackageConfig('package-with-config-defaults')
        expect(config.get('package-with-config-defaults.numbers.one')).toBe 1
        expect(config.get('package-with-config-defaults.numbers.two')).toBe 2

    describe ".deactivatePackage(id)", ->
      describe "atom packages", ->
        it "calls `deactivate` on the package's main module", ->
          pack = atom.activatePackage("package-with-deactivate")
          expect(atom.isPackageActive("package-with-deactivate")).toBeTruthy()
          spyOn(pack.mainModule, 'deactivate').andCallThrough()

          atom.deactivatePackage("package-with-deactivate")
          expect(pack.mainModule.deactivate).toHaveBeenCalled()
          expect(atom.isPackageActive("package-with-module")).toBeFalsy()

        it "absorbs exceptions that are thrown by the package module's serialize methods", ->
          spyOn(console, 'error')
          atom.activatePackage('package-with-serialize-error',  immediate: true)
          atom.activatePackage('package-with-serialization', immediate: true)
          atom.deactivatePackages()
          expect(atom.packageStates['package-with-serialize-error']).toBeUndefined()
          expect(atom.packageStates['package-with-serialization']).toEqual someNumber: 1
          expect(console.error).toHaveBeenCalled()

        it "removes the package's grammars", ->
          atom.activatePackage('package-with-grammars')
          atom.deactivatePackage('package-with-grammars')
          expect(syntax.selectGrammar('a.alot').name).toBe 'Null Grammar'
          expect(syntax.selectGrammar('a.alittle').name).toBe 'Null Grammar'

        it "removes the package's keymaps", ->
          atom.activatePackage('package-with-keymaps')
          atom.deactivatePackage('package-with-keymaps')
          expect(keymap.bindingsForElement($$ -> @div class: 'test-1')['ctrl-z']).toBeUndefined()
          expect(keymap.bindingsForElement($$ -> @div class: 'test-2')['ctrl-z']).toBeUndefined()

        it "removes the package's stylesheets", ->
          atom.activatePackage('package-with-stylesheets')
          atom.deactivatePackage('package-with-stylesheets')
          one = fsUtils.resolveOnLoadPath("package-with-stylesheets/stylesheets/1.css")
          two = fsUtils.resolveOnLoadPath("package-with-stylesheets/stylesheets/2.less")
          three = fsUtils.resolveOnLoadPath("package-with-stylesheets/stylesheets/3.css")
          expect(stylesheetElementForId(one)).not.toExist()
          expect(stylesheetElementForId(two)).not.toExist()
          expect(stylesheetElementForId(three)).not.toExist()

        it "removes the package's scoped-properties", ->
          atom.activatePackage("package-with-scoped-properties")
          expect(syntax.getProperty ['.source.omg'], 'editor.increaseIndentPattern').toBe '^a'
          atom.deactivatePackage("package-with-scoped-properties")
          expect(syntax.getProperty ['.source.omg'], 'editor.increaseIndentPattern').toBeUndefined()

      describe "texmate packages", ->
        it "removes the package's grammars", ->
          expect(syntax.selectGrammar("file.rb").name).toBe "Null Grammar"
          atom.activatePackage('ruby-tmbundle', sync: true)
          expect(syntax.selectGrammar("file.rb").name).toBe "Ruby"
          atom.deactivatePackage('ruby-tmbundle')
          expect(syntax.selectGrammar("file.rb").name).toBe "Null Grammar"

        it "removes the package's scoped properties", ->
          atom.activatePackage('ruby-tmbundle', sync: true)
          atom.deactivatePackage('ruby-tmbundle')
          expect(syntax.getProperty(['.source.ruby'], 'editor.commentStart')).toBeUndefined()

  describe ".getVersion", ->
    it "returns the current version number", ->
      expect(typeof atom.getVersion()).toBe 'string'

  describe "API documentation", ->
    it "meets a minimum threshold for /app (with no errors)", ->
      docRunner = jasmine.createSpy("docRunner")
      Exec "./node_modules/.bin/coffee ./node_modules/.bin/biscotto -- --statsOnly src/app/", cwd: project.resolve('../..'), docRunner
      waitsFor ->
        docRunner.callCount > 0

      runs ->
        # error
        expect(docRunner.argsForCall[0][0]).toBeNull()

        results = docRunner.argsForCall[0][1].split("\n")
        results.pop()

        errors = parseInt results.pop().match(/\d+/)
        if errors > 0
          console.error results.join('\n')
          throw new Error("There were errors compiling documentation. See console for details.")

        coverage = parseFloat results.pop().match(/.+?%/)
        expect(coverage).toBeGreaterThan 75

        # stderr
        expect(docRunner.argsForCall[0][2]).toBe ''
