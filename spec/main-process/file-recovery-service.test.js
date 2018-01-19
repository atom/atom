const {dialog} = require('electron')
const FileRecoveryService = require('../../src/main-process/file-recovery-service')
const fs = require('fs-plus')
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
    it("creates a recovery file and deletes it after saving", async () => {
      const mockWindow = {}
      const filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      await recoveryService.willSavePath(mockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "changed")
      await recoveryService.didSavePath(mockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")

      fs.removeSync(filePath)
    })

    it("creates only one recovery file when many windows attempt to save the same file, deleting it when the last one finishes saving it", async () => {
      const mockWindow = {}
      const anotherMockWindow = {}
      const filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      await recoveryService.willSavePath(mockWindow, filePath)
      await recoveryService.willSavePath(anotherMockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "changed")
      await recoveryService.didSavePath(mockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")

      await recoveryService.didSavePath(anotherMockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")

      fs.removeSync(filePath)
    })
  })

  describe("when a crash happens during a save", () => {
    it("restores the created recovery file and deletes it", async () => {
      const mockWindow = {}
      const filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      await recoveryService.willSavePath(mockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "changed")
      await recoveryService.didCrashWindow(mockWindow)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
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
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "C")

      await recoveryService.didCrashWindow(mockWindow)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "A")
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)

      fs.writeFileSync(filePath, "D")
      await recoveryService.willSavePath(mockWindow, filePath)
      fs.writeFileSync(filePath, "E")
      await recoveryService.willSavePath(anotherMockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "F")

      await recoveryService.didCrashWindow(anotherMockWindow)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "D")
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)

      fs.removeSync(filePath)
    })

    it("emits a warning when a file can't be recovered", async () => {
      const mockWindow = {}
      const filePath = temp.path()
      fs.writeFileSync(filePath, "content")
      fs.chmodSync(filePath, 0444)

      let logs = []
      spies.stub(console, 'log', (message) => logs.push(message))
      spies.stub(dialog, 'showMessageBox')

      await recoveryService.willSavePath(mockWindow, filePath)
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
})
