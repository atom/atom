{$, $$}  = require '../src/space-pen-extensions'
Exec = require('child_process').exec
path = require 'path'
Package = require '../src/package'
ThemeManager = require '../src/theme-manager'
_ = require "underscore-plus"
temp = require "temp"

describe "the `atom` global", ->
  describe 'window sizing methods', ->
    describe '::getPosition and ::setPosition', ->
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

  describe "when an update becomes available", ->
    subscription = null

    afterEach ->
      subscription?.dispose()

    it "invokes onUpdateAvailable listeners", ->
      updateAvailableHandler = jasmine.createSpy("update-available-handler")
      subscription = atom.onUpdateAvailable updateAvailableHandler

      autoUpdater = require('remote').require('auto-updater')
      autoUpdater.emit 'update-downloaded', null, "notes", "version"

      waitsFor ->
        updateAvailableHandler.callCount > 0

      runs ->
        {releaseVersion} = updateAvailableHandler.mostRecentCall.args[0]
        expect(releaseVersion).toBe 'version'

  describe "loading default config", ->
    it 'loads the default core config', ->
      expect(atom.config.get('core.excludeVcsIgnoredPaths')).toBe true
      expect(atom.config.get('core.followSymlinks')).toBe true
      expect(atom.config.get('editor.showInvisibles')).toBe false

  describe "window onerror handler", ->
    beforeEach ->
      spyOn atom, 'openDevTools'
      spyOn atom, 'executeJavaScriptInDevTools'

    it "will open the dev tools when an error is triggered", ->
      try
        a + 1
      catch e
        window.onerror.call(window, e.toString(), 'abc', 2, 3, e)

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

  describe "saving and loading", ->
    afterEach -> atom.mode = "spec"

    it "selects the state based on the current project paths", ->
      Atom = atom.constructor
      [dir1, dir2] = [temp.mkdirSync("dir1-"), temp.mkdirSync("dir2-")]

      loadSettings = _.extend Atom.getLoadSettings(),
        initialPaths: [dir1]
        windowState: null

      spyOn(Atom, 'getLoadSettings').andCallFake -> loadSettings
      spyOn(Atom, 'getStorageDirPath').andReturn(temp.mkdirSync("storage-dir-"))

      atom.mode = "editor"
      atom.state.stuff = "cool"
      atom.project.setPaths([dir1, dir2])
      atom.saveSync.originalValue.call(atom)

      atom1 = Atom.loadOrCreate("editor")
      expect(atom1.state.stuff).toBeUndefined()

      loadSettings.initialPaths = [dir2, dir1]
      atom2 = Atom.loadOrCreate("editor")
      expect(atom2.state.stuff).toBe("cool")

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
