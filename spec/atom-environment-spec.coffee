_ = require "underscore-plus"
path = require 'path'
temp = require 'temp'
Package = require '../src/package'
ThemeManager = require '../src/theme-manager'
AtomEnvironment = require '../src/atom-environment'

describe "AtomEnvironment", ->
  describe 'window sizing methods', ->
    describe '::getPosition and ::setPosition', ->
      originalPosition = null
      beforeEach ->
        originalPosition = atom.getPosition()

      afterEach ->
        atom.setPosition(originalPosition.x, originalPosition.y)

      it 'sets the position of the window, and can retrieve the position just set', ->
        atom.setPosition(22, 45)
        expect(atom.getPosition()).toEqual x: 22, y: 45

    describe '::getSize and ::setSize', ->
      originalSize = null
      beforeEach ->
        originalSize = atom.getSize()
      afterEach ->
        atom.setSize(originalSize.width, originalSize.height)

      it 'sets the size of the window, and can retrieve the size just set', ->
        atom.setSize(100, 400)
        expect(atom.getSize()).toEqual width: 100, height: 400

  describe ".isReleasedVersion()", ->
    it "returns false if the version is a SHA and true otherwise", ->
      version = '0.1.0'
      spyOn(atom, 'getVersion').andCallFake -> version
      expect(atom.isReleasedVersion()).toBe true
      version = '36b5518'
      expect(atom.isReleasedVersion()).toBe false

  describe "loading default config", ->
    it 'loads the default core config schema', ->
      expect(atom.config.get('core.excludeVcsIgnoredPaths')).toBe true
      expect(atom.config.get('core.followSymlinks')).toBe true
      expect(atom.config.get('editor.showInvisibles')).toBe false

  describe "window onerror handler", ->
    devToolsPromise = null
    beforeEach ->
      devToolsPromise = Promise.resolve()
      spyOn(atom, 'openDevTools').andReturn(devToolsPromise)
      spyOn(atom, 'executeJavaScriptInDevTools')

    it "will open the dev tools when an error is triggered", ->
      try
        a + 1
      catch e
        window.onerror.call(window, e.toString(), 'abc', 2, 3, e)

      waitsForPromise -> devToolsPromise
      runs ->
        expect(atom.openDevTools).toHaveBeenCalled()
        expect(atom.executeJavaScriptInDevTools).toHaveBeenCalled()

    describe "::onWillThrowError", ->
      willThrowSpy = null
      beforeEach ->
        willThrowSpy = jasmine.createSpy()

      it "is called when there is an error", ->
        error = null
        atom.onWillThrowError(willThrowSpy)
        try
          a + 1
        catch e
          error = e
          window.onerror.call(window, e.toString(), 'abc', 2, 3, e)

        delete willThrowSpy.mostRecentCall.args[0].preventDefault
        expect(willThrowSpy).toHaveBeenCalledWith
          message: error.toString()
          url: 'abc'
          line: 2
          column: 3
          originalError: error

      it "will not show the devtools when preventDefault() is called", ->
        willThrowSpy.andCallFake (errorObject) -> errorObject.preventDefault()
        atom.onWillThrowError(willThrowSpy)

        try
          a + 1
        catch e
          window.onerror.call(window, e.toString(), 'abc', 2, 3, e)

        expect(willThrowSpy).toHaveBeenCalled()
        expect(atom.openDevTools).not.toHaveBeenCalled()
        expect(atom.executeJavaScriptInDevTools).not.toHaveBeenCalled()

    describe "::onDidThrowError", ->
      didThrowSpy = null
      beforeEach ->
        didThrowSpy = jasmine.createSpy()

      it "is called when there is an error", ->
        error = null
        atom.onDidThrowError(didThrowSpy)
        try
          a + 1
        catch e
          error = e
          window.onerror.call(window, e.toString(), 'abc', 2, 3, e)
        expect(didThrowSpy).toHaveBeenCalledWith
          message: error.toString()
          url: 'abc'
          line: 2
          column: 3
          originalError: error

  describe ".assert(condition, message, callback)", ->
    errors = null

    beforeEach ->
      errors = []
      atom.onDidFailAssertion (error) -> errors.push(error)

    describe "if the condition is false", ->
      it "notifies onDidFailAssertion handlers with an error object based on the call site of the assertion", ->
        result = atom.assert(false, "a == b")
        expect(result).toBe false
        expect(errors.length).toBe 1
        expect(errors[0].message).toBe "Assertion failed: a == b"
        expect(errors[0].stack).toContain('atom-environment-spec')

      describe "if passed a callback function", ->
        it "calls the callback with the assertion failure's error object", ->
          error = null
          atom.assert(false, "a == b", (e) -> error = e)
          expect(error).toBe errors[0]

    describe "if the condition is true", ->
      it "does nothing", ->
        result = atom.assert(true, "a == b")
        expect(result).toBe true
        expect(errors).toEqual []

  describe "saving and loading", ->
    beforeEach ->
      atom.enablePersistence = true

    afterEach ->
      atom.enablePersistence = false

    it "selects the state based on the current project paths", ->
      [dir1, dir2] = [temp.mkdirSync("dir1-"), temp.mkdirSync("dir2-")]

      loadSettings = _.extend atom.getLoadSettings(),
        initialPaths: [dir1]
        windowState: null

      spyOn(atom, 'getLoadSettings').andCallFake -> loadSettings
      spyOn(atom.getStorageFolder(), 'getPath').andReturn(temp.mkdirSync("storage-dir-"))

      atom.state.stuff = "cool"
      atom.project.setPaths([dir1, dir2])
      atom.saveStateSync()

      atom.state = {}
      atom.loadStateSync()
      expect(atom.state.stuff).toBeUndefined()

      loadSettings.initialPaths = [dir2, dir1]
      atom.state = {}
      atom.loadStateSync()
      expect(atom.state.stuff).toBe("cool")

  describe "openInitialEmptyEditorIfNecessary", ->
    describe "when there are no paths set", ->
      beforeEach ->
        spyOn(atom, 'getLoadSettings').andReturn(initialPaths: [])

      it "opens an empty buffer", ->
        spyOn(atom.workspace, 'open')
        atom.openInitialEmptyEditorIfNecessary()
        expect(atom.workspace.open).toHaveBeenCalledWith(null)

      describe "when there is already a buffer open", ->
        beforeEach ->
          waitsForPromise -> atom.workspace.open()

        it "does not open an empty buffer", ->
          spyOn(atom.workspace, 'open')
          atom.openInitialEmptyEditorIfNecessary()
          expect(atom.workspace.open).not.toHaveBeenCalled()

    describe "when the project has a path", ->
      beforeEach ->
        spyOn(atom, 'getLoadSettings').andReturn(initialPaths: ['something'])
        spyOn(atom.workspace, 'open')

      it "does not open an empty buffer", ->
        atom.openInitialEmptyEditorIfNecessary()
        expect(atom.workspace.open).not.toHaveBeenCalled()

  describe "adding a project folder", ->
    it "adds a second path to the project", ->
      initialPaths = atom.project.getPaths()
      tempDirectory = temp.mkdirSync("a-new-directory")
      spyOn(atom, "pickFolder").andCallFake (callback) ->
        callback([tempDirectory])
      atom.addProjectFolder()
      expect(atom.project.getPaths()).toEqual(initialPaths.concat([tempDirectory]))

    it "does nothing if the user dismisses the file picker", ->
      initialPaths = atom.project.getPaths()
      tempDirectory = temp.mkdirSync("a-new-directory")
      spyOn(atom, "pickFolder").andCallFake (callback) -> callback(null)
      atom.addProjectFolder()
      expect(atom.project.getPaths()).toEqual(initialPaths)

  describe "::unloadEditorWindow()", ->
    it "saves the BlobStore so it can be loaded after reload", ->
      configDirPath = temp.mkdirSync()
      fakeBlobStore = jasmine.createSpyObj("blob store", ["save"])
      atomEnvironment = new AtomEnvironment({applicationDelegate: atom.applicationDelegate, enablePersistence: true, configDirPath, blobStore: fakeBlobStore, window, document})

      atomEnvironment.unloadEditorWindow()

      expect(fakeBlobStore.save).toHaveBeenCalled()

      atomEnvironment.destroy()

    it "saves the serialized state of the window so it can be deserialized after reload", ->
      atomEnvironment = new AtomEnvironment({applicationDelegate: atom.applicationDelegate, window, document})
      spyOn(atomEnvironment, 'saveStateSync')

      workspaceState = atomEnvironment.workspace.serialize()
      grammarsState = {grammarOverridesByPath: atomEnvironment.grammars.grammarOverridesByPath}
      projectState = atomEnvironment.project.serialize()

      atomEnvironment.unloadEditorWindow()

      expect(atomEnvironment.state.workspace).toEqual workspaceState
      expect(atomEnvironment.state.grammars).toEqual grammarsState
      expect(atomEnvironment.state.project).toEqual projectState
      expect(atomEnvironment.saveStateSync).toHaveBeenCalled()

      atomEnvironment.destroy()

  describe "::destroy()", ->
    it "does not throw exceptions when unsubscribing from ipc events (regression)", ->
      configDirPath = temp.mkdirSync()
      fakeDocument = {
        addEventListener: ->
        removeEventListener: ->
        head: document.createElement('head')
        body: document.createElement('body')
      }
      atomEnvironment = new AtomEnvironment({applicationDelegate: atom.applicationDelegate, window, document: fakeDocument})
      spyOn(atomEnvironment.packages, 'getAvailablePackagePaths').andReturn []
      atomEnvironment.startEditorWindow()
      atomEnvironment.unloadEditorWindow()
      atomEnvironment.destroy()

  describe "::openLocations(locations) (called via IPC from browser process)", ->
    beforeEach ->
      spyOn(atom.workspace, 'open')
      atom.project.setPaths([])

    describe "when the opened path exists", ->
      it "adds it to the project's paths", ->
        pathToOpen = __filename
        atom.openLocations([{pathToOpen}])
        expect(atom.project.getPaths()[0]).toBe __dirname

    describe "when the opened path does not exist but its parent directory does", ->
      it "adds the parent directory to the project paths", ->
        pathToOpen = path.join(__dirname, 'this-path-does-not-exist.txt')
        atom.openLocations([{pathToOpen}])
        expect(atom.project.getPaths()[0]).toBe __dirname

    describe "when the opened path is a file", ->
      it "opens it in the workspace", ->
        pathToOpen = __filename
        atom.openLocations([{pathToOpen}])
        expect(atom.workspace.open.mostRecentCall.args[0]).toBe __filename

    describe "when the opened path is a directory", ->
      it "does not open it in the workspace", ->
        pathToOpen = __dirname
        atom.openLocations([{pathToOpen}])
        expect(atom.workspace.open.callCount).toBe 0

    describe "when the opened path is a uri", ->
      it "adds it to the project's paths as is", ->
        pathToOpen = 'remote://server:7644/some/dir/path'
        atom.openLocations([{pathToOpen}])
        expect(atom.project.getPaths()[0]).toBe pathToOpen

  describe "::updateAvailable(info) (called via IPC from browser process)", ->
    subscription = null

    afterEach ->
      subscription?.dispose()

    it "invokes onUpdateAvailable listeners", ->
      atom.listenForUpdates()

      updateAvailableHandler = jasmine.createSpy("update-available-handler")
      subscription = atom.onUpdateAvailable updateAvailableHandler

      autoUpdater = require('remote').require('auto-updater')
      autoUpdater.emit 'update-downloaded', null, "notes", "version"

      waitsFor ->
        updateAvailableHandler.callCount > 0

      runs ->
        {releaseVersion} = updateAvailableHandler.mostRecentCall.args[0]
        expect(releaseVersion).toBe 'version'
