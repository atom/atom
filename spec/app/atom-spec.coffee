$ = require 'jquery'
RootView = require 'root-view'
{$$} = require 'space-pen'
fs = require 'fs-utils'

describe "the `atom` global", ->
  beforeEach ->
    window.rootView = new RootView

  describe "package lifecycle methods", ->
    describe ".activatePackage(id)", ->
      describe "atom packages", ->
        describe "when the package has a main module", ->
          describe "when the metadata specifies a main module path˜", ->
            it "requires the module at the specified path", ->
              mainModule = require('package-with-main/main-module')
              spyOn(mainModule, 'activate')
              pack = atom.activatePackage('package-with-main')
              expect(mainModule.activate).toHaveBeenCalled()
              expect(pack.mainModule).toBe mainModule

          describe "when the metadata does not specify a main module", ->
            it "requires index.coffee", ->
              indexModule = require('package-with-index/index')
              spyOn(indexModule, 'activate')
              pack = atom.activatePackage('package-with-index')
              expect(indexModule.activate).toHaveBeenCalled()
              expect(pack.mainModule).toBe indexModule

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
              one = fs.resolveOnLoadPath("package-with-stylesheets-manifest/stylesheets/1.css")
              two = fs.resolveOnLoadPath("package-with-stylesheets-manifest/stylesheets/2.less")
              three = fs.resolveOnLoadPath("package-with-stylesheets-manifest/stylesheets/3.css")
              expect(stylesheetElementForId(one)).not.toExist()
              expect(stylesheetElementForId(two)).not.toExist()
              expect(stylesheetElementForId(three)).not.toExist()

              atom.activatePackage("package-with-stylesheets-manifest")

              expect(stylesheetElementForId(one)).toExist()
              expect(stylesheetElementForId(two)).toExist()
              expect(stylesheetElementForId(three)).not.toExist()
              expect($('#jasmine-content').css('font-size')).toBe '1px'

          describe "when the metadata does not contains a 'stylesheets' manifest", ->
            it "loads all stylesheets from the stylesheets directory", ->
              one = fs.resolveOnLoadPath("package-with-stylesheets/stylesheets/1.css")
              two = fs.resolveOnLoadPath("package-with-stylesheets/stylesheets/2.less")
              three = fs.resolveOnLoadPath("package-with-stylesheets/stylesheets/3.css")
              expect(stylesheetElementForId(one)).not.toExist()
              expect(stylesheetElementForId(two)).not.toExist()
              expect(stylesheetElementForId(three)).not.toExist()

              atom.activatePackage("package-with-stylesheets")
              expect(stylesheetElementForId(one)).toExist()
              expect(stylesheetElementForId(two)).toExist()
              expect(stylesheetElementForId(three)).toExist()
              expect($('#jasmine-content').css('font-size')).toBe '3px'

      describe "textmate packages", ->
        it "loads the package's grammars", ->
          expect(syntax.selectGrammar("file.rb").name).toBe "Null Grammar"
          atom.activatePackage('ruby.tmbundle', sync: true)
          expect(syntax.selectGrammar("file.rb").name).toBe "Ruby"

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
