RootView = require 'root-view'
{$$} = require 'space-pen'

describe "the `atom` global", ->
  beforeEach ->
    window.rootView = new RootView

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

    it "aborts the worker when all packages have been loaded", ->
      LoadTextMatePackagesTask = require 'load-text-mate-packages-task'
      spyOn(LoadTextMatePackagesTask.prototype, 'abort').andCallThrough()
      eventHandler = jasmine.createSpy('eventHandler')
      syntax.on 'grammars-loaded', eventHandler
      config.get("core.disabledPackages").push('textmate-package.tmbundle', 'package-with-snippets')
      atom.loadPackages()

      waitsFor "all packages to load", 5000, -> eventHandler.callCount > 0

      runs ->
        expect(LoadTextMatePackagesTask.prototype.abort).toHaveBeenCalled()
        expect(LoadTextMatePackagesTask.prototype.abort.calls.length).toBe 1

  describe "package lifecycle", ->
    describe "activation", ->
      it "calls activate on the package main with its previous state", ->
        pack = window.loadPackage('package-with-module')
        spyOn(pack.mainModule, 'activate')

        serializedState = rootView.serialize()
        rootView.deactivate()
        RootView.deserialize(serializedState)
        window.loadPackage('package-with-module')

        expect(pack.mainModule.activate).toHaveBeenCalledWith(someNumber: 1)

    describe "deactivation", ->
      it "deactivates and removes the package module from the package module map", ->
        pack = window.loadPackage('package-with-module')
        expect(atom.activatedAtomPackages.length).toBe 1
        spyOn(pack.mainModule, "deactivate").andCallThrough()
        atom.deactivateAtomPackages()
        expect(pack.mainModule.deactivate).toHaveBeenCalled()
        expect(atom.activatedAtomPackages.length).toBe 0

    describe "serialization", ->
      it "uses previous serialization state on packages whose activation has been deferred", ->
        atom.atomPackageStates['package-with-activation-events'] = {previousData: 'exists'}
        unactivatedPackage = window.loadPackage('package-with-activation-events')
        activatedPackage = window.loadPackage('package-with-module')

        expect(atom.serializeAtomPackages()).toEqual
          'package-with-module':
            'someNumber': 1
          'package-with-activation-events':
            'previousData': 'exists'

        # ensure serialization occurs when the packageis activated
        unactivatedPackage.deferActivation = false
        unactivatedPackage.activate()
        expect(atom.serializeAtomPackages()).toEqual
          'package-with-module':
            'someNumber': 1
          'package-with-activation-events':
            'previousData': 'overwritten'

      it "absorbs exceptions that are thrown by the package module's serialize methods", ->
        spyOn(console, 'error')
        window.loadPackage('package-with-module', activateImmediately: true)
        window.loadPackage('package-with-serialize-error',  activateImmediately: true)

        packageStates = atom.serializeAtomPackages()
        expect(packageStates['package-with-module']).toEqual someNumber: 1
        expect(packageStates['package-with-serialize-error']).toBeUndefined()
        expect(console.error).toHaveBeenCalled()

  describe ".getVersion(callback)", ->
    it "calls the callback with the current version number", ->
      versionHandler = jasmine.createSpy("versionHandler")
      atom.getVersion(versionHandler)
      waitsFor ->
        versionHandler.callCount > 0

      runs ->
        expect(versionHandler.argsForCall[0][0]).toMatch /^\d+\.\d+(\.\d+)?$/

  describe "modal native dialogs", ->
    beforeEach ->
      spyOn(atom, 'sendMessageToBrowserProcess')
      atom.sendMessageToBrowserProcess.simulateConfirmation = (buttonText) ->
        labels = @argsForCall[0][1][2...]
        callbacks = @argsForCall[0][2]
        @reset()
        callbacks[labels.indexOf(buttonText)]()
        advanceClock 50

      atom.sendMessageToBrowserProcess.simulatePathSelection = (path) ->
        callback = @argsForCall[0][2]
        @reset()
        callback(path)
        advanceClock 50

    it "only presents one native dialog at a time", ->
      confirmHandler = jasmine.createSpy("confirmHandler")
      selectPathHandler = jasmine.createSpy("selectPathHandler")

      atom.confirm "Are you happy?", "really, truly happy?", "Yes", confirmHandler, "No"
      atom.confirm "Are you happy?", "really, truly happy?", "Yes", confirmHandler, "No"
      atom.showSaveDialog(selectPathHandler)
      atom.showSaveDialog(selectPathHandler)

      expect(atom.sendMessageToBrowserProcess.callCount).toBe 1
      atom.sendMessageToBrowserProcess.simulateConfirmation("Yes")
      expect(confirmHandler).toHaveBeenCalled()

      expect(atom.sendMessageToBrowserProcess.callCount).toBe 1
      atom.sendMessageToBrowserProcess.simulateConfirmation("No")

      expect(atom.sendMessageToBrowserProcess.callCount).toBe 1
      atom.sendMessageToBrowserProcess.simulatePathSelection('/selected/path')
      expect(selectPathHandler).toHaveBeenCalledWith('/selected/path')
      selectPathHandler.reset()

      expect(atom.sendMessageToBrowserProcess.callCount).toBe 1

    it "prioritizes dialogs presented as the result of dismissing other dialogs before any previously deferred dialogs", ->
      atom.confirm "A1", "", "Next", ->
        atom.confirm "B1", "", "Next", ->
          atom.confirm "C1", "", "Next", ->
          atom.confirm "C2", "", "Next", ->
        atom.confirm "B2", "", "Next", ->
      atom.confirm "A2", "", "Next", ->

      expect(atom.sendMessageToBrowserProcess.callCount).toBe 1
      expect(atom.sendMessageToBrowserProcess.argsForCall[0][1][0]).toBe "A1"
      atom.sendMessageToBrowserProcess.simulateConfirmation('Next')

      expect(atom.sendMessageToBrowserProcess.callCount).toBe 1
      expect(atom.sendMessageToBrowserProcess.argsForCall[0][1][0]).toBe "B1"
      atom.sendMessageToBrowserProcess.simulateConfirmation('Next')

      expect(atom.sendMessageToBrowserProcess.callCount).toBe 1
      expect(atom.sendMessageToBrowserProcess.argsForCall[0][1][0]).toBe "C1"
      atom.sendMessageToBrowserProcess.simulateConfirmation('Next')

      expect(atom.sendMessageToBrowserProcess.callCount).toBe 1
      expect(atom.sendMessageToBrowserProcess.argsForCall[0][1][0]).toBe "C2"
      atom.sendMessageToBrowserProcess.simulateConfirmation('Next')

      expect(atom.sendMessageToBrowserProcess.callCount).toBe 1
      expect(atom.sendMessageToBrowserProcess.argsForCall[0][1][0]).toBe "B2"
      atom.sendMessageToBrowserProcess.simulateConfirmation('Next')

      expect(atom.sendMessageToBrowserProcess.callCount).toBe 1
      expect(atom.sendMessageToBrowserProcess.argsForCall[0][1][0]).toBe "A2"
      atom.sendMessageToBrowserProcess.simulateConfirmation('Next')
