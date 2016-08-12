/** @babel */

import {dialog} from 'electron'
import FileRecoveryService from '../../src/main-process/file-recovery-service'
import temp from 'temp'
import fs from 'fs-plus'
import sinon from 'sinon'

describe("FileRecoveryService", () => {
  let recoveryService, recoveryDirectory

  beforeEach(() => {
    recoveryDirectory = temp.mkdirSync()
    recoveryService = new FileRecoveryService(recoveryDirectory)
  })

  describe("when no crash happens during a save", () => {
    it("creates a recovery file and deletes it after saving", () => {
      const mockWindow = {}
      const filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      recoveryService.willSavePath(mockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "changed")
      recoveryService.didSavePath(mockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")
    })

    it("creates only one recovery file when many windows attempt to save the same file, deleting it when the last one finishes saving it", () => {
      const mockWindow = {}
      const anotherMockWindow = {}
      const filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      recoveryService.willSavePath(mockWindow, filePath)
      recoveryService.willSavePath(anotherMockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "changed")
      recoveryService.didSavePath(mockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")

      recoveryService.didSavePath(anotherMockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")
    })
  })

  describe("when a crash happens during a save", () => {
    it("restores the created recovery file and deletes it", () => {
      const mockWindow = {}
      const filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      recoveryService.willSavePath(mockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "changed")
      recoveryService.didCrashWindow(mockWindow)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "some content")
    })

    it("restores the created recovery file when many windows attempt to save the same file and one of them crashes", () => {
      const mockWindow = {}
      const anotherMockWindow = {}
      const filePath = temp.path()

      fs.writeFileSync(filePath, "A")
      recoveryService.willSavePath(mockWindow, filePath)
      fs.writeFileSync(filePath, "B")
      recoveryService.willSavePath(anotherMockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "C")

      recoveryService.didCrashWindow(mockWindow)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "A")
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)

      fs.writeFileSync(filePath, "D")
      recoveryService.willSavePath(mockWindow, filePath)
      fs.writeFileSync(filePath, "E")
      recoveryService.willSavePath(anotherMockWindow, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "F")

      recoveryService.didCrashWindow(anotherMockWindow)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "D")
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
    })

    it("emits a warning when a file can't be recovered", sinon.test(function () {
      const mockWindow = {}
      const filePath = temp.path()
      fs.writeFileSync(filePath, "content")
      fs.chmodSync(filePath, 0444)

      let logs = []
      this.stub(console, 'log', (message) => logs.push(message))
      this.stub(dialog, 'showMessageBox')

      recoveryService.willSavePath(mockWindow, filePath)
      recoveryService.didCrashWindow(mockWindow)
      let recoveryFiles = fs.listTreeSync(recoveryDirectory)
      assert.equal(recoveryFiles.length, 1)
      assert.equal(logs.length, 1)
      assert.match(logs[0], new RegExp(filePath))
      assert.match(logs[0], new RegExp(recoveryFiles[0]))
    }))
  })

  it("doesn't create a recovery file when the file that's being saved doesn't exist yet", () => {
    const mockWindow = {}

    recoveryService.willSavePath(mockWindow, "a-file-that-doesnt-exist")
    assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)

    recoveryService.didSavePath(mockWindow, "a-file-that-doesnt-exist")
    assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
  })
})
