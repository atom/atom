File = require 'file'
fs = require 'fs'

describe 'File', ->
  file = null

  beforeEach ->
    path = fs.join(require.resolve('fixtures'), "temp.txt")
    fs.remove(path) if fs.exists(path)
    fs.write(path, "this is old!")
    file = new File(path)

  afterEach ->
    file.off()
    fs.remove(file.getPath()) if fs.exists(file.getPath())

  fdescribe "when the contents of the file change", ->
    it "triggers 'contents-change' event handlers", ->
      changeHandler = null
      runs ->
        changeHandler = jasmine.createSpy('changeHandler')
        file.on 'contents-change', changeHandler
        console.log "ATOMIC WRITE"
        fs.write(file.getPath(), "this is new!")

      waitsFor "change event", ->
        changeHandler.callCount > 0

      runs ->
        changeHandler.reset()
        console.log 'writing'
        fs.write(file.getPath(), "this is newer!")

      waitsFor "second change event", ->
        changeHandler.callCount > 0
