RootView = require 'root-view'
AtomPackage = require 'atom-package'
fs = require 'fs-utils'

describe "AtomPackage", ->
  [packageMainModule, pack] = []

  beforeEach ->
    pack = new AtomPackage(fs.resolve(config.packageDirPaths..., 'package-with-activation-events'))
    pack.load()

  describe ".load()", ->
    describe "if the package's metadata has a `deferredDeserializers` array", ->
      it "requires the package's main module attempting to use deserializers named in the array", ->
        expect(pack.mainModule).toBeNull()
        object = deserialize(deserializer: 'Foo', data: "Hello")
        expect(object.constructor.name).toBe 'Foo'
        expect(object.data).toBe 'Hello'
        expect(pack.mainModule).toBeDefined()
        expect(pack.mainModule.activateCallCount).toBe 0

  describe ".activate()", ->
    beforeEach ->
      window.rootView = new RootView
      packageMainModule = require 'fixtures/packages/package-with-activation-events/main'
      spyOn(packageMainModule, 'activate').andCallThrough()

    describe "when the package metadata includes activation events", ->
      beforeEach ->
        pack.activate()

      it "defers activating the package until an activation event bubbles to the root view", ->
        expect(packageMainModule.activate).not.toHaveBeenCalled()
        rootView.trigger 'activation-event'
        expect(packageMainModule.activate).toHaveBeenCalled()

      it "triggers the activation event on all handlers registered during activation", ->
        rootView.open('sample.js')
        editor = rootView.getActiveView()
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
