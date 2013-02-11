RootView = require 'root-view'
AtomPackage = require 'atom-package'
fs = require 'fs'

describe "AtomPackage", ->
  describe ".load()", ->
    afterEach ->
      rootView.deactivate()

    describe "when the package metadata includes activation events", ->
      [packageMainModule, pack] = []

      beforeEach ->
        new RootView(fixturesProject.getPath())
        pack = new AtomPackage(fs.resolve(config.packageDirPaths..., 'package-with-activation-events'))
        packageMainModule = require 'fixtures/packages/package-with-activation-events/main'
        spyOn(packageMainModule, 'activate').andCallThrough()
        pack.load()

      it "defers activating the package until an activation event bubbles to the root view", ->
        expect(packageMainModule.activate).not.toHaveBeenCalled()
        rootView.trigger 'activation-event'
        expect(packageMainModule.activate).toHaveBeenCalled()

      it "triggers the activation event on all handlers registered during activation", ->
        rootView.open('sample.js')
        editor = rootView.getActiveEditor()
        eventHandler = jasmine.createSpy("activation-event")
        editor.command 'activation-event', eventHandler
        editor.trigger 'activation-event'
        expect(packageMainModule.activate.callCount).toBe 1
        expect(packageMainModule.activationEventCallCount).toBe 1
        expect(eventHandler.callCount).toBe 1
        editor.trigger 'activation-event'
        expect(packageMainModule.activationEventCallCount).toBe 2
        expect(eventHandler.callCount).toBe 2
        expect(packageMainModule.activate.callCount).toBe 1

    describe "when the package does not specify a main module", ->
      describe "when the package has an index.coffee", ->
        it "uses index.coffee as the main module", ->
          new RootView(fixturesProject.getPath())
          pack = new AtomPackage(fs.resolve(config.packageDirPaths..., 'package-with-module'))
          packageMainModule = require 'fixtures/packages/package-with-module'
          spyOn(packageMainModule, 'activate').andCallThrough()

          expect(packageMainModule.activate).not.toHaveBeenCalled()
          pack.load()
          expect(packageMainModule.activate).toHaveBeenCalled()

      describe "when the package doesn't have an index.coffee", ->
        it "does not throw an exception or log an error", ->
          spyOn(console, "error")
          spyOn(console, "warn")
          new RootView(fixturesProject.getPath())
          pack = new AtomPackage(fs.resolve(config.packageDirPaths..., 'package-with-keymaps-manifest'))

          expect(-> pack.load()).not.toThrow()
          expect(console.error).not.toHaveBeenCalled()
          expect(console.warn).not.toHaveBeenCalled()

  describe "when a package is activated", ->
    it "loads config defaults based on the `configDefaults` key", ->
      expect(config.get('package-with-module.numbers.one')).toBeUndefined()
      atom.loadPackage("package-with-module")
      expect(config.get('package-with-module.numbers.one')).toBe 1
      expect(config.get('package-with-module.numbers.two')).toBe 2
