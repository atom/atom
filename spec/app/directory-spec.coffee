Directory = require 'directory'
fs = require 'fs'

describe "Directory", ->
  directory = null

  beforeEach ->
    directory = new Directory(require.resolve('fixtures'))

  fdescribe "when the contents of the directory change on disk", ->
    temporaryFilePath = null

    beforeEach ->
      temporaryFilePath = fs.join(require.resolve('fixtures'), 'temporary')
      fs.remove(temporaryFilePath) if fs.exists(temporaryFilePath)

    afterEach ->
      fs.remove(temporaryFilePath) if fs.exists(temporaryFilePath)

    it "triggers 'contents-change' event handlers", ->
      changeHandler = null

      runs ->
        changeHandler = jasmine.createSpy('changeHandler')
        directory.on 'contents-change', changeHandler
        fs.write(temporaryFilePath, '')

      waitsFor "first change", -> changeHandler.callCount > 0

      runs ->
        changeHandler.reset()
        fs.remove(temporaryFilePath)

      waitsFor "second change", -> changeHandler.callCount > 0

  fdescribe "when the directory unsubscribes from events", ->
    temporaryFilePath = null

    beforeEach ->
      temporaryFilePath = fs.join(directory.path, 'temporary')
      fs.remove(temporaryFilePath) if fs.exists(temporaryFilePath)

    afterEach ->
      fs.remove(temporaryFilePath) if fs.exists(temporaryFilePath)

    it "no longer triggers events", ->
      changeHandler = null

      runs ->
        changeHandler = jasmine.createSpy('changeHandler')
        directory.on 'contents-change', changeHandler
        fs.write(temporaryFilePath, '')

      waitsFor "first change", -> changeHandler.callCount > 0

      runs ->
        changeHandler.reset()
        directory.unsubscribeFromNativeChangeEvents()

      ticks = 0
      waitsFor "100 ticks", -> ticks++ < 100

      runs ->
        expect(changeHandler.callCount).toBe 0
