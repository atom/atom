'use babel'

import FileRecoveryService from '../../src/browser/file-recovery-service'
import temp from 'temp'
import fs from 'fs-plus'
import path from 'path'
import os from 'os'
import crypto from 'crypto'
import {Emitter} from 'event-kit'

describe("FileRecoveryService", () => {
  let mockWindow, recoveryService, recoveryDirectory

  beforeEach(() => {
    mockWindow = new Emitter
    recoveryDirectory = temp.mkdirSync()
    recoveryService = new FileRecoveryService(recoveryDirectory)
  })

  describe("when no crash happens during a save", () => {
    it("creates a recovery file and deletes it after saving", () => {
      let filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      recoveryService.willSavePath({sender: mockWindow}, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "changed")
      recoveryService.didSavePath({sender: mockWindow}, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")
    })

    it("creates many recovery files and deletes them when many windows attempt to save the same file", () => {
      const anotherMockWindow = new Emitter
      let filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      recoveryService.willSavePath({sender: mockWindow}, filePath)
      recoveryService.willSavePath({sender: anotherMockWindow}, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 2)

      fs.writeFileSync(filePath, "changed")
      recoveryService.didSavePath({sender: mockWindow}, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")

      recoveryService.didSavePath({sender: anotherMockWindow}, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "changed")
    })
  })

  describe("when a crash happens during a save", () => {
    it("restores the created recovery file and deletes it", () => {
      let filePath = temp.path()

      fs.writeFileSync(filePath, "some content")
      recoveryService.willSavePath({sender: mockWindow}, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      fs.writeFileSync(filePath, "changed")
      mockWindow.emit("crashed")
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
      assert.equal(fs.readFileSync(filePath, 'utf8'), "some content")
    })

    it("restores the created recovery files and deletes them in the order in which windows crash", () => {
      const anotherMockWindow = new Emitter
      let filePath = temp.path()

      fs.writeFileSync(filePath, "window 1")
      recoveryService.willSavePath({sender: mockWindow}, filePath)
      fs.writeFileSync(filePath, "window 2")
      recoveryService.willSavePath({sender: anotherMockWindow}, filePath)
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 2)

      fs.writeFileSync(filePath, "changed")

      mockWindow.emit("crashed")
      assert.equal(fs.readFileSync(filePath, 'utf8'), "window 1")
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 1)

      anotherMockWindow.emit("crashed")
      assert.equal(fs.readFileSync(filePath, 'utf8'), "window 2")
      assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
    })
  })

  it("doesn't create a recovery file when the file that's being saved doesn't exist yet", () => {
    recoveryService.willSavePath({sender: mockWindow}, "a-file-that-doesnt-exist")
    assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)

    recoveryService.didSavePath({sender: mockWindow}, "a-file-that-doesnt-exist")
    assert.equal(fs.listTreeSync(recoveryDirectory).length, 0)
  })
})
