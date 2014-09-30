{$, $$, WorkspaceView}  = require 'atom'
Exec = require('child_process').exec
path = require 'path'
Package = require '../src/package'
ThemeManager = require '../src/theme-manager'

describe "the `atom` global", ->
  beforeEach ->
    atom.workspaceView = atom.workspace.getView(atom.workspace).__spacePenView

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

  describe "window:update-available", ->
    it "is triggered when the auto-updater sends the update-downloaded event", ->
      updateAvailableHandler = jasmine.createSpy("update-available-handler")
      atom.workspaceView.on 'window:update-available', updateAvailableHandler
      autoUpdater = require('remote').require('auto-updater')
      autoUpdater.emit 'update-downloaded', null, "notes", "version"

      waitsFor ->
        updateAvailableHandler.callCount > 0

      runs ->
        [event, version, notes] = updateAvailableHandler.mostRecentCall.args
        expect(notes).toBe 'notes'
        expect(version).toBe 'version'

  describe "loading default config", ->
    it 'loads the default core config', ->
      expect(atom.config.get('core.excludeVcsIgnoredPaths')).toBe true
      expect(atom.config.get('editor.showInvisibles')).toBe false
