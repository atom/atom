RootView = require 'root-view'
{$$} = require 'space-pen'

describe "the `atom` global", ->
  beforeEach ->
    new RootView

  afterEach ->
    rootView.deactivate()

  describe "when a package is built and loaded", ->
    [extension, stylesheetPath] = []

    beforeEach ->
      extension = require "package-with-module"
      stylesheetPath = require.resolve("fixtures/packages/package-with-module/stylesheets/styles.css")

    afterEach ->
      removeStylesheet(stylesheetPath)

    it "requires and activates the package's main module if it exists", ->
      spyOn(atom, 'activateAtomPackage').andCallThrough()
      window.loadPackage("package-with-module")
      expect(atom.activateAtomPackage).toHaveBeenCalled()

    it "logs warning instead of throwing an exception if a package fails to load", ->
      config.set("core.disabledPackages", [])
      spyOn(console, "warn")
      expect(-> window.loadPackage("package-that-throws-an-exception")).not.toThrow()
      expect(console.warn).toHaveBeenCalled()

    describe "keymap loading", ->
      describe "when package.json does not contain a 'keymaps' manifest", ->
        it "loads all the .cson/.json files in the keymaps directory", ->
          element1 = $$ -> @div class: 'test-1'
          element2 = $$ -> @div class: 'test-2'
          element3 = $$ -> @div class: 'test-3'

          expect(keymap.bindingsForElement(element1)['ctrl-z']).toBeUndefined()
          expect(keymap.bindingsForElement(element2)['ctrl-z']).toBeUndefined()
          expect(keymap.bindingsForElement(element3)['ctrl-z']).toBeUndefined()

          window.loadPackage("package-with-module")

          expect(keymap.bindingsForElement(element1)['ctrl-z']).toBe "test-1"
          expect(keymap.bindingsForElement(element2)['ctrl-z']).toBe "test-2"
          expect(keymap.bindingsForElement(element3)['ctrl-z']).toBeUndefined()

      describe "when package.json contains a 'keymaps' manifest", ->
        it "loads only the keymaps specified by the manifest, in the specified order", ->
          element1 = $$ -> @div class: 'test-1'
          element3 = $$ -> @div class: 'test-3'

          expect(keymap.bindingsForElement(element1)['ctrl-z']).toBeUndefined()

          window.loadPackage("package-with-keymaps-manifest")

          expect(keymap.bindingsForElement(element1)['ctrl-z']).toBe 'keymap-1'
          expect(keymap.bindingsForElement(element1)['ctrl-n']).toBe 'keymap-2'
          expect(keymap.bindingsForElement(element3)['ctrl-y']).toBeUndefined()

    it "loads stylesheets associated with the package", ->
      stylesheetPath = require.resolve("fixtures/packages/package-with-module/stylesheets/styles.css")
      expect(stylesheetElementForId(stylesheetPath).length).toBe 0
      window.loadPackage("package-with-module")
      expect(stylesheetElementForId(stylesheetPath).length).toBe 1

  describe ".loadPackages()", ->
    beforeEach ->
      spyOn(syntax, 'addGrammar')

    it "terminates the worker when all packages have been loaded", ->
      spyOn(Worker.prototype, 'terminate').andCallThrough()
      eventHandler = jasmine.createSpy('eventHandler')
      syntax.on 'grammars-loaded', eventHandler
      disabledPackages = config.get("core.disabledPackages")
      disabledPackages.push('textmate-package.tmbundle')
      disabledPackages.push('package-with-snippets')
      config.set "core.disabledPackages", disabledPackages
      atom.loadPackages()

      waitsFor "all packages to load", 5000, -> eventHandler.callCount > 0

      runs ->
        expect(Worker.prototype.terminate).toHaveBeenCalled()
        expect(Worker.prototype.terminate.calls.length).toBe 1

  describe "package lifecycle", ->
    describe "activation", ->
      it "calls activate on the package main with its previous state", ->
        pack = window.loadPackage('package-with-module')
        spyOn(pack.packageMain, 'activate')

        serializedState = rootView.serialize()
        rootView.deactivate()
        RootView.deserialize(serializedState)
        window.loadPackage('package-with-module')

        expect(pack.packageMain.activate).toHaveBeenCalledWith(someNumber: 1)

    describe "deactivation", ->
      it "deactivates and removes the package module from the package module map", ->
        pack = window.loadPackage('package-with-module')
        expect(atom.activatedAtomPackages.length).toBe 1
        spyOn(pack.packageMain, "deactivate").andCallThrough()
        atom.deactivateAtomPackages()
        expect(pack.packageMain.deactivate).toHaveBeenCalled()
        expect(atom.activatedAtomPackages.length).toBe 0

    describe "serialization", ->
      it "uses previous serialization state on unactivated packages", ->
        atom.atomPackageStates['package-with-activation-events'] = {previousData: 'exists'}
        unactivatedPackage = window.loadPackage('package-with-activation-events')
        activatedPackage = window.loadPackage('package-with-module')

        expect(atom.serializeAtomPackages()).toEqual
          'package-with-module':
            'someNumber': 1
          'package-with-activation-events':
            'previousData': 'exists'

        # ensure serialization occurs when the packageis activated
        unactivatedPackage.activatePackageMain()
        expect(atom.serializeAtomPackages()).toEqual
          'package-with-module':
            'someNumber': 1
          'package-with-activation-events':
            'previousData': 'overwritten'

      it "absorbs exceptions that are thrown by the package module's serialize methods", ->
        spyOn(console, 'error')
        window.loadPackage('package-with-module')
        window.loadPackage('package-with-serialize-error', activateImmediately: true)

        packageStates = atom.serializeAtomPackages()
        expect(packageStates['package-with-module']).toEqual someNumber: 1
        expect(packageStates['package-with-serialize-error']).toBeUndefined()
        expect(console.error).toHaveBeenCalled()
