const {dialog} = require('electron')
const FileRecoveryService = require('../../src/main-process/file-recovery-service')
const fs = require('fs-plus')
const fsreal = require('fs')
const EventEmitter = require('events').EventEmitter
const sinon = require('sinon')
const {escapeRegExp} = require('underscore-plus')
const temp = require('temp').track()

describe("FileRecoveryService", () => {
  let recoveryService, recoveryDirectory, spies

  beforeEach(() => {
    recoveryDirectory = temp.mkdirSync('atom-spec-file-recovery')
    recoveryService = new FileRecoveryService(recoveryDirectory)
    spies = sinon.sandbox.create()
  })

  afterEach(() => {
    spies.restore()
    try {
      temp.cleanupSync()
    } catch (e) {
      // Ignore
    }
  })

  describe("when no crash happens during a save", () => {
    it("creates a recovery file and renames it after saving", async () => {
      const mockWindow = {}
      const filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      await recoveryService.willSavePath(mockWindow, filePath)
      let entries = fs.listTreeSync(recoveryDirectory)
      assert.equal(entries.length, 1)
      const [recoveryFilename] = entries

      fs.writeFileSync(filePath, "changed")
      await recoveryService.didSavePath(mockWindow, filePath)
      entries = fs.listTreeSync(recoveryDirectory)
      assert.equal(entries.length, 1)
      const [renamedFilename] = entries
      assert.equal(renamedFilename, recoveryFilename + '~')
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")

      fs.removeSync(filePath)
    })

    it("creates only one recovery file when many windows attempt to save the same file, renaming it when the last one finishes saving it", async () => {
      const mockWindow = {}
      const anotherMockWindow = {}
      const filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      await recoveryService.willSavePath(mockWindow, filePath)
      await recoveryService.willSavePath(anotherMockWindow, filePath)
      let entries = fs.listTreeSync(recoveryDirectory)
      assert.equal(entries.length, 1)
      const [recoveryFilename] = entries

      fs.writeFileSync(filePath, "changed")
      await recoveryService.didSavePath(mockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")

      await recoveryService.didSavePath(anotherMockWindow, filePath)
      entries = fs.listTreeSync(recoveryDirectory)
      assert.equal(entries.length, 1)
      const [renamedFilename] = entries
      assert.equal(renamedFilename, recoveryFilename + '~')
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")

      fs.removeSync(filePath)
    })
  })

  describe("when a crash happens during a save", () => {
    it("restores the created recovery file and renames it", async () => {
      const mockWindow = {}
      const filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      await recoveryService.willSavePath(mockWindow, filePath)
      let entries = fs.listTreeSync(recoveryDirectory)      
      assert.equal(entries.length, 1)
      const [recoveryFilename] = entries

      fs.writeFileSync(filePath, "changed")
      await recoveryService.didCrashWindow(mockWindow)
      entries = fs.listTreeSync(recoveryDirectory)
      assert.equal(entries.length, 1)
      const [renamedFilename] = entries
      assert.equal(renamedFilename, recoveryFilename + '~')
      assert.equal(fs.readFileSync(filePath, 'utf8'), "some content")

      fs.removeSync(filePath)
    })

    it("restores the created recovery file when many windows attempt to save the same file and one of them crashes", async () => {
      const mockWindow = {}
      const anotherMockWindow = {}
      const filePath = temp.path()

      fs.writeFileSync(filePath, "A")
      await recoveryService.willSavePath(mockWindow, filePath)
      fs.writeFileSync(filePath, "B")
      await recoveryService.willSavePath(anotherMockWindow, filePath)
      let entries = fs.listTreeSync(recoveryDirectory)
      assert.equal(entries.length, 1)
      const [recoveryFilename] = entries

      fs.writeFileSync(filePath, "C")

      await recoveryService.didCrashWindow(mockWindow)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "A")

      entries = fs.listTreeSync(recoveryDirectory)
      assert.equal(entries.length, 1)

      fs.writeFileSync(filePath, "D")
      await recoveryService.willSavePath(mockWindow, filePath)
      fs.writeFileSync(filePath, "E")
      await recoveryService.willSavePath(anotherMockWindow, filePath)
      entries = fs.listTreeSync(recoveryDirectory)
      assert.equal(entries.length, 2)

      fs.writeFileSync(filePath, "F")

      await recoveryService.didCrashWindow(anotherMockWindow)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "D")
      entries = fs.listTreeSync(recoveryDirectory)
      assert.equal(entries.length, 2)
      assert(entries[0].endsWith('~'))
      assert(entries[1].endsWith('~'))

      fs.removeSync(filePath)
    })

    it("emits a warning when a file can't be recovered", async () => {
      const mockWindow = {}
      const filePath = temp.path()
      fs.writeFileSync(filePath, "content")

      let logs = []
      spies.stub(console, 'log', (message) => logs.push(message))
      spies.stub(dialog, 'showMessageBox')

      // Copy files to be recovered before mocking fs.createWriteStream
      await recoveryService.willSavePath(mockWindow, filePath)

      // Stub out fs.createWriteStream so that we can return a fake error when
      // attempting to copy the recovered file to its original location
      var fakeEmitter = new EventEmitter()
      var onStub = spies.stub(fakeEmitter, 'on')
      onStub.withArgs('error').yields(new Error('Nope')).returns(fakeEmitter)
      onStub.withArgs('open').returns(fakeEmitter)
      spies.stub(fsreal, 'createWriteStream').withArgs(filePath).returns(fakeEmitter)

      await recoveryService.didCrashWindow(mockWindow)
      let recoveryFiles = fs.listTreeSync(recoveryDirectory)
      assert.equal(recoveryFiles.length, 1)
      assert.equal(logs.length, 1)
      assert.match(logs[0], new RegExp(escapeRegExp(filePath)))
      assert.match(logs[0], new RegExp(escapeRegExp(recoveryFiles[0])))

      fs.removeSync(filePath)
    })
  })

  it("doesn't create a recovery file when the file that's being saved doesn't exist yet", async () => {
    const mockWindow = {}

    await recoveryService.willSavePath(mockWindow, "a-file-that-doesnt-exist")
    assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)

    await recoveryService.didSavePath(mockWindow, "a-file-that-doesnt-exist")
    assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
  })

  describe("sweep", () => { 
    it("deletes only files ending in ~ older than maxAge", async () => {
      const now = Date.now()
      const ls = sinon.spy((_dir, pred) => {
        return [
          {path: 'dead~', stat: {mtimeMs: now - 2000}},
          {path: 'not-yet-recovered', stat: {mtimeMs: now - 100000}},
          {path: 'too-young-to-die~', stat: {mtimeMs: now - 100}},
          {path: 'AlsoDead~', stat: {mtimeMs: now - 2000}},          
        ].filter(({path}) => pred(path))
      })
      const unlink = sinon.spy(path => path)
      const garbage = await recoveryService.sweep(1000, {ls, unlink})
      
      assert.equal(unlink.callCount, 2)
      assert(unlink.getCall(0).calledWith('dead~'))
      assert(unlink.getCall(1).calledWith('AlsoDead~'))
      assert.deepEqual(garbage, unlink.getCalls().map(call => call.args[0]))
    })
  })
})
