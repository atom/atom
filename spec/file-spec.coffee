{File, fs} = require 'atom-api'
path = require 'path'

describe 'File', ->
  [filePath, file] = []

  beforeEach ->
    filePath = path.join(__dirname, 'fixtures', 'atom-file-test.txt') # Don't put in /tmp because /tmp symlinks to /private/tmp and screws up the rename test
    fs.remove(filePath) if fs.exists(filePath)
    fs.writeSync(filePath, "this is old!")
    file = new File(filePath)

  afterEach ->
    file.off()
    fs.remove(filePath) if fs.exists(filePath)

  describe "when the file has not been read", ->
    describe "when the contents of the file change", ->
      it "triggers 'contents-changed' event handlers", ->
        file.on 'contents-changed', changeHandler = jasmine.createSpy('changeHandler')
        fs.writeSync(file.getPath(), "this is new!")

        waitsFor "change event", ->
          changeHandler.callCount > 0

  describe "when the file has already been read", ->
    beforeEach ->
      file.read()

    describe "when the contents of the file change", ->
      it "triggers 'contents-changed' event handlers", ->
        changeHandler = null
        changeHandler = jasmine.createSpy('changeHandler')
        file.on 'contents-changed', changeHandler
        fs.writeSync(file.getPath(), "this is new!")

        waitsFor "change event", ->
          changeHandler.callCount > 0

        runs ->
          changeHandler.reset()
          fs.writeSync(file.getPath(), "this is newer!")

        waitsFor "second change event", ->
          changeHandler.callCount > 0

    describe "when the file is removed", ->
      it "triggers 'remove' event handlers", ->
        removeHandler = null
        removeHandler = jasmine.createSpy('removeHandler')
        file.on 'removed', removeHandler
        fs.remove(file.getPath())

        waitsFor "remove event", ->
          removeHandler.callCount > 0

    describe "when a file is moved (via the filesystem)", ->
      newPath = null

      beforeEach ->
        newPath = path.join(path.dirname(filePath), "atom-file-was-moved-test.txt")

      afterEach ->
        if fs.exists(newPath)
          fs.remove(newPath)
          waitsFor "remove event", (done) -> file.on 'removed', done

      it "it updates its path", ->
        jasmine.unspy(window, "setTimeout")
        moveHandler = null
        moveHandler = jasmine.createSpy('moveHandler')
        file.on 'moved', moveHandler

        fs.move(filePath, newPath)

        waitsFor "move event", ->
          moveHandler.callCount > 0

        runs ->
          expect(file.getPath()).toBe newPath

      it "maintains 'contents-changed' events set on previous path", ->
        jasmine.unspy(window, "setTimeout")
        moveHandler = null
        moveHandler = jasmine.createSpy('moveHandler')
        file.on 'moved', moveHandler
        changeHandler = null
        changeHandler = jasmine.createSpy('changeHandler')
        file.on 'contents-changed', changeHandler

        fs.move(filePath, newPath)

        waitsFor "move event", ->
          moveHandler.callCount > 0

        runs ->
          expect(changeHandler).not.toHaveBeenCalled()
          fs.writeSync(file.getPath(), "this is new!")

        waitsFor "change event", ->
          changeHandler.callCount > 0

    describe "when a file is deleted and the recreated within a small amount of time (git sometimes does this)", ->
      it "triggers a contents change event if the contents change", ->
        jasmine.unspy(File.prototype, 'detectResurrectionAfterDelay')
        jasmine.unspy(window, "setTimeout")

        changeHandler = jasmine.createSpy("file changed")
        removeHandler = jasmine.createSpy("file removed")
        file.on 'contents-changed', changeHandler
        file.on 'removed', removeHandler

        expect(changeHandler).not.toHaveBeenCalled()

        fs.remove(filePath)

        expect(changeHandler).not.toHaveBeenCalled()
        waits 20
        runs ->
          fs.writeSync(filePath, "HE HAS RISEN!")
          expect(changeHandler).not.toHaveBeenCalled()

        waitsFor "resurrection change event", ->
          changeHandler.callCount == 1

        runs ->
          expect(removeHandler).not.toHaveBeenCalled()
          fs.writeSync(filePath, "Hallelujah!")
          changeHandler.reset()

        waitsFor "post-resurrection change event", ->
          changeHandler.callCount > 0
