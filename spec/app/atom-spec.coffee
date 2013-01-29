RootView = require 'root-view'
{$$} = require 'space-pen'

describe "the `atom` global", ->
  describe ".loadPackage(name)", ->
    [extension, stylesheetPath] = []

    beforeEach ->
      rootView = new RootView
      extension = require "package-with-module"
      stylesheetPath = require.resolve("fixtures/packages/package-with-module/stylesheets/styles.css")

    afterEach ->
      removeStylesheet(stylesheetPath)

    it "requires and activates the package's main module if it exists", ->
      spyOn(rootView, 'activatePackage').andCallThrough()
      atom.loadPackage("package-with-module")
      expect(rootView.activatePackage).toHaveBeenCalled()

    it "logs warning instead of throwing an exception if a package fails to load", ->
      config.set("core.disabledPackages", [])
      spyOn(console, "warn")
      expect(-> atom.loadPackage("package-that-throws-an-exception")).not.toThrow()
      expect(console.warn).toHaveBeenCalled()

    describe "keymap loading", ->
      describe "when package.json does not contain a 'keymaps' manifest", ->
        it "loads all keymaps in the directory", ->
          element1 = $$ -> @div class: 'test-1'
          element2 = $$ -> @div class: 'test-2'

          expect(keymap.bindingsForElement(element1)['ctrl-z']).toBeUndefined()
          expect(keymap.bindingsForElement(element2)['ctrl-z']).toBeUndefined()

          atom.loadPackage("package-with-module")

          expect(keymap.bindingsForElement(element1)['ctrl-z']).toBe "test-1"
          expect(keymap.bindingsForElement(element2)['ctrl-z']).toBe "test-2"

      describe "when package.json contains a 'keymaps' manifest", ->
        it "loads only the keymaps specified by the manifest, in the specified order", ->
          element1 = $$ -> @div class: 'test-1'
          element3 = $$ -> @div class: 'test-3'

          expect(keymap.bindingsForElement(element1)['ctrl-z']).toBeUndefined()

          atom.loadPackage("package-with-keymaps-manifest")

          expect(keymap.bindingsForElement(element1)['ctrl-z']).toBe 'keymap-1'
          expect(keymap.bindingsForElement(element1)['ctrl-n']).toBe 'keymap-2'
          expect(keymap.bindingsForElement(element3)['ctrl-y']).toBeUndefined()

    it "loads stylesheets associated with the package", ->
      stylesheetPath = require.resolve("fixtures/packages/package-with-module/stylesheets/styles.css")
      expect(stylesheetElementForId(stylesheetPath).length).toBe 0
      atom.loadPackage("package-with-module")
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
      config.set "core.disabledPackages", disabledPackages
      atom.loadPackages()

      waitsFor "all packages to load", 5000, -> eventHandler.callCount > 0

      runs ->
        expect(Worker.prototype.terminate).toHaveBeenCalled()
        expect(Worker.prototype.terminate.calls.length).toBe 1
