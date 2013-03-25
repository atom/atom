RootView = require 'root-view'
{$$} = require 'space-pen'
fs = require 'fs-utils'

describe "the `atom` global", ->
  beforeEach ->
    window.rootView = new RootView

  describe "package lifecycle methods", ->
    packageModule = null

    beforeEach ->
      packageModule = require "package-with-module"

    afterEach ->
      atom.deactivatePackages()

    describe ".activatePackage(id)", ->
      describe "atom packages", ->
        stylesheetPath = null

        beforeEach ->
          stylesheetPath = fs.resolveOnLoadPath("fixtures/packages/package-with-module/stylesheets/styles.css")

        afterEach ->
          removeStylesheet(stylesheetPath)

        it "requires and activates the package's main module if it exists", ->
          spyOn(packageModule, 'activate').andCallThrough()
          atom.activatePackage("package-with-module")
          expect(packageModule.activate).toHaveBeenCalledWith({})

        it "passes the package its previously serialized state if it exists", ->
          pack = atom.activatePackage("package-with-module")
          expect(pack.mainModule.someNumber).not.toBe 77
          pack.mainModule.someNumber = 77
          atom.deactivatePackage("package-with-module")

          pack.requireMainModule() # deactivating the package nukes its main module, so we require it again to spy on it
          spyOn(pack.mainModule, 'activate').andCallThrough()

          atom.activatePackage("package-with-module")
          expect(pack.mainModule.activate).toHaveBeenCalledWith({someNumber: 77})

        it "logs warning instead of throwing an exception if a package fails to load", ->
          config.set("core.disabledPackages", [])
          spyOn(console, "warn")
          expect(-> atom.activatePackage("package-that-throws-an-exception")).not.toThrow()
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

              atom.activatePackage("package-with-module")

              expect(keymap.bindingsForElement(element1)['ctrl-z']).toBe "test-1"
              expect(keymap.bindingsForElement(element2)['ctrl-z']).toBe "test-2"
              expect(keymap.bindingsForElement(element3)['ctrl-z']).toBeUndefined()

          describe "when package.json contains a 'keymaps' manifest", ->
            it "loads only the keymaps specified by the manifest, in the specified order", ->
              element1 = $$ -> @div class: 'test-1'
              element3 = $$ -> @div class: 'test-3'

              expect(keymap.bindingsForElement(element1)['ctrl-z']).toBeUndefined()

              atom.activatePackage("package-with-keymaps-manifest")

              expect(keymap.bindingsForElement(element1)['ctrl-z']).toBe 'keymap-1'
              expect(keymap.bindingsForElement(element1)['ctrl-n']).toBe 'keymap-2'
              expect(keymap.bindingsForElement(element3)['ctrl-y']).toBeUndefined()

        it "loads stylesheets associated with the package", ->
          stylesheetPath = fs.resolveOnLoadPath("fixtures/packages/package-with-module/stylesheets/styles.css")
          expect(stylesheetElementForId(stylesheetPath).length).toBe 0
          atom.activatePackage("package-with-module")
          expect(stylesheetElementForId(stylesheetPath).length).toBe 1

      describe "textmate packages", ->
        it "loads the package's grammars", ->
          expect(syntax.selectGrammar("file.rb").name).toBe "Null Grammar"
          atom.activatePackage('ruby.tmbundle', sync: true)
          expect(syntax.selectGrammar("file.rb").name).toBe "Ruby"

    describe ".deactivatePackage(id)", ->
      describe "atom packages", ->
        it "calls `deactivate` on the package's main module and deletes the package's module reference and require cache entry", ->
          pack = atom.activatePackage("package-with-module")
          expect(atom.getActivePackage("package-with-module")).toBe pack
          spyOn(pack.mainModule, 'deactivate').andCallThrough()

          atom.deactivatePackage("package-with-module")
          expect(pack.mainModule.deactivate).toHaveBeenCalled()
          expect(atom.getActivePackage("package-with-module")).toBeUndefined()

        it "absorbs exceptions that are thrown by the package module's serialize methods", ->
          spyOn(console, 'error')
          atom.activatePackage('package-with-module', immediate: true)
          atom.activatePackage('package-with-serialize-error',  immediate: true)
          atom.deactivatePackages()
          expect(atom.packageStates['package-with-module']).toEqual someNumber: 1
          expect(atom.packageStates['package-with-serialize-error']).toBeUndefined()
          expect(console.error).toHaveBeenCalled()

      describe "texmate packages", ->
        it "removes the package's grammars", ->
          expect(syntax.selectGrammar("file.rb").name).toBe "Null Grammar"
          atom.activatePackage('ruby.tmbundle', sync: true)
          expect(syntax.selectGrammar("file.rb").name).toBe "Ruby"
          atom.deactivatePackage('ruby.tmbundle')
          expect(syntax.selectGrammar("file.rb").name).toBe "Null Grammar"

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
