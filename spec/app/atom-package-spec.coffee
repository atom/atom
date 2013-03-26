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
