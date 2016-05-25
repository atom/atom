'use babel'

import {BrowserWindow} from 'electron'
import FileRecoveryService from '../../src/main-process/file-recovery-service'
import temp from 'temp'
import fs from 'fs-plus'
import {Emitter} from 'event-kit'
import sinon from 'sinon'

describe("FileRecoveryService", () => {
  let recoveryService, recoveryDirectory, windows, previousConsoleLog

  function createWindow () {
    const window = new BrowserWindow({show: false})
    windows.push(window)
    return window
  }

  beforeEach(() => {
    windows = []
    recoveryDirectory = temp.mkdirSync()
    recoveryService = new FileRecoveryService(recoveryDirectory)
  })

  afterEach(() => {
    for (let window of windows) {
      window.destroy()
    }
  })

  describe("when no crash happens during a save", () => {
    it("creates a recovery file and deletes it after saving", () => {
      const mockWindow = createWindow()
      const filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      recoveryService.willSavePath({sender: mockWindow.webContents}, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "changed")
      recoveryService.didSavePath({sender: mockWindow.webContents}, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")
    })

    it("creates only one recovery file when many windows attempt to save the same file, deleting it when the last one finishes saving it", () => {
      const mockWindow = createWindow()
      const anotherMockWindow = createWindow()
      const filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      recoveryService.willSavePath({sender: mockWindow.webContents}, filePath)
      recoveryService.willSavePath({sender: anotherMockWindow.webContents}, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "changed")
      recoveryService.didSavePath({sender: mockWindow.webContents}, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")

      recoveryService.didSavePath({sender: anotherMockWindow.webContents}, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")
    })
  })

  describe("when a crash happens during a save", () => {
    it("restores the created recovery file and deletes it", () => {
      const mockWindow = createWindow()
      const filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      recoveryService.willSavePath({sender: mockWindow.webContents}, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "changed")
      mockWindow.webContents.emit("crashed")
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "some content")
    })

    describe("when many windows attempt to save the same file", () => {
      it("recovers the file when the window that initiated the save crashes", () => {
        const mockWindow = createWindow()
        const anotherMockWindow = createWindow()
        const filePath = temp.path()

        fs.writeFileSync(filePath, "window 1")
        recoveryService.willSavePath({sender: mockWindow.webContents}, filePath)
        fs.writeFileSync(filePath, "window 2")
        recoveryService.willSavePath({sender: anotherMockWindow.webContents}, filePath)
        assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

        fs.writeFileSync(filePath, "changed")

        mockWindow.webContents.emit("crashed")
        assert.equal(fs.readFileSync(filePath, 'utf8'), "window 1")
        assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
      })

      it("recovers the file when a window that did not initiate the save crashes", () => {
        const mockWindow = createWindow()
        const anotherMockWindow = createWindow()
        const filePath = temp.path()

        fs.writeFileSync(filePath, "window 1")
        recoveryService.willSavePath({sender: mockWindow.webContents}, filePath)
        fs.writeFileSync(filePath, "window 2")
        recoveryService.willSavePath({sender: anotherMockWindow.webContents}, filePath)
        assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

        fs.writeFileSync(filePath, "changed")

        anotherMockWindow.webContents.emit("crashed")
        assert.equal(fs.readFileSync(filePath, 'utf8'), "window 1")
        assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
      })
    })

    it("emits a warning when a file can't be recovered", sinon.test(function () {
      const mockWindow = createWindow()
      const filePath = temp.path()
      fs.writeFileSync(filePath, "content")
      fs.chmodSync(filePath, 0444)

      let logs = []
      this.stub(console, 'log', (message) => logs.push(message))

      recoveryService.willSavePath({sender: mockWindow.webContents}, filePath)
      mockWindow.webContents.emit("crashed")
      let recoveryFiles = fs.listTreeSync(recoveryDirectory)
      assert.equal(recoveryFiles.length, 1)
      assert.equal(logs.length, 1)
      assert.match(logs[0], new RegExp(filePath))
      assert.match(logs[0], new RegExp(recoveryFiles[0]))
    }))
  })

  it("doesn't create a recovery file when the file that's being saved doesn't exist yet", () => {
    const mockWindow = createWindow()

    recoveryService.willSavePath({sender: mockWindow.webContents}, "a-file-that-doesnt-exist")
    assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)

    recoveryService.didSavePath({sender: mockWindow.webContents}, "a-file-that-doesnt-exist")
    assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
  })
})
