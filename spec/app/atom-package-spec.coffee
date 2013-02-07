RootView = require 'root-view'
AtomPackage = require 'atom-package'
fs = require 'fs'

describe "AtomPackage", ->
  describe ".load()", ->
    [packageMainModule, pack, rootView] = []
    beforeEach ->
      rootView = new RootView(fixturesProject.getPath())
      pack = new AtomPackage(fs.resolve(config.packageDirPaths..., 'package-with-activation-events'))
      packageMainModule = require 'fixtures/packages/package-with-activation-events/main'
      spyOn(packageMainModule, 'activate').andCallThrough()
      pack.load()

    afterEach ->
      rootView.deactivate()

    describe "when the package metadata includes activation events", ->
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
