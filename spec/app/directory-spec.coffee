Directory = require 'app/directory'
fs = require 'fs'
path = require 'path'

describe "Directory", ->
  directory = null

  beforeEach ->
    directory = new Directory(path.resolveOnLoadPath('fixtures'))

  afterEach ->
    directory.off()

  describe "when the contents of the directory change on disk", ->
    temporaryFilePath = null

    beforeEach ->
      temporaryFilePath = path.join(path.resolveOnLoadPath('fixtures'), 'temporary')
      fs.unlink(temporaryFilePath) if fs.existsSync(temporaryFilePath)

    afterEach ->
      fs.unlink(temporaryFilePath) if fs.existsSync(temporaryFilePath)

    it "triggers 'contents-change' event handlers", ->
      changeHandler = null

      runs ->
        changeHandler = jasmine.createSpy('changeHandler')
        directory.on 'contents-change', changeHandler
        fs.write(temporaryFilePath, '')

      waitsFor "first change", -> changeHandler.callCount > 0

      runs ->
        changeHandler.reset()
        fs.unlink(temporaryFilePath)

      waitsFor "second change", -> changeHandler.callCount > 0

  describe "when the directory unsubscribes from events", ->
    temporaryFilePath = null

    beforeEach ->
      temporaryFilePath = path.join(directory.path, 'temporary')
      fs.unlink(temporaryFilePath) if fs.existsSync(temporaryFilePath)

    afterEach ->
      fs.unlink(temporaryFilePath) if fs.existsSync(temporaryFilePath)

    it "no longer triggers events", ->
      changeHandler = null

      runs ->
        changeHandler = jasmine.createSpy('changeHandler')
        directory.on 'contents-change', changeHandler
        fs.write(temporaryFilePath, '')

      waitsFor "change event", -> changeHandler.callCount > 0

      runs ->
        changeHandler.reset()
        directory.off()
      waits 20

      runs -> fs.unlink(temporaryFilePath)
      waits 20
      runs -> expect(changeHandler.callCount).toBe 0

