Directory = require 'directory'
fsUtils = require 'fs-utils'

describe "Directory", ->
  directory = null

  beforeEach ->
    directory = new Directory(fsUtils.resolveOnLoadPath('fixtures'))

  afterEach ->
    directory.off()

  describe "when the contents of the directory change on disk", ->
    temporaryFilePath = null

    beforeEach ->
      temporaryFilePath = fsUtils.join(fsUtils.resolveOnLoadPath('fixtures'), 'temporary')
      fsUtils.remove(temporaryFilePath) if fsUtils.exists(temporaryFilePath)

    afterEach ->
      fsUtils.remove(temporaryFilePath) if fsUtils.exists(temporaryFilePath)

    it "triggers 'contents-changed' event handlers", ->
      changeHandler = null

      runs ->
        changeHandler = jasmine.createSpy('changeHandler')
        directory.on 'contents-changed', changeHandler
        fsUtils.write(temporaryFilePath, '')

      waitsFor "first change", -> changeHandler.callCount > 0

      runs ->
        changeHandler.reset()
        fsUtils.remove(temporaryFilePath)

      waitsFor "second change", -> changeHandler.callCount > 0

  describe "when the directory unsubscribes from events", ->
    temporaryFilePath = null

    beforeEach ->
      temporaryFilePath = fsUtils.join(directory.path, 'temporary')
      fsUtils.remove(temporaryFilePath) if fsUtils.exists(temporaryFilePath)

    afterEach ->
      fsUtils.remove(temporaryFilePath) if fsUtils.exists(temporaryFilePath)

    it "no longer triggers events", ->
      changeHandler = null

      runs ->
        changeHandler = jasmine.createSpy('changeHandler')
        directory.on 'contents-changed', changeHandler
        fsUtils.write(temporaryFilePath, '')

      waitsFor "change event", -> changeHandler.callCount > 0

      runs ->
        changeHandler.reset()
        directory.off()
      waits 20

      runs -> fsUtils.remove(temporaryFilePath)
      waits 20
      runs -> expect(changeHandler.callCount).toBe 0

  it "includes symlink information about entries", ->
    entries = directory.getEntries()
    for entry in entries
      name = entry.getBaseName()
      if name is 'symlink-to-dir' or name is 'symlink-to-file'
        expect(entry.symlink).toBeTruthy()
      else
        expect(entry.symlink).toBeFalsy()
