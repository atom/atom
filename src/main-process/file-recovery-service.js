'use babel'

import {BrowserWindow, ipcMain} from 'electron'
import crypto from 'crypto'
import Path from 'path'
import fs from 'fs-plus'

class RecoveryFile {
  constructor (originalPath, recoveryPath) {
    this.originalPath = originalPath
    this.recoveryPath = recoveryPath
    this.refCount = 0
  }

  storeSync () {
    fs.writeFileSync(this.recoveryPath, fs.readFileSync(this.originalPath))
  }

  recoverSync () {
    fs.writeFileSync(this.originalPath, fs.readFileSync(this.recoveryPath))
    this.removeSync()
    this.refCount = 0
  }

  removeSync () {
    fs.unlinkSync(this.recoveryPath)
  }

  retain () {
    if (this.refCount === 0) this.storeSync()
    this.refCount++
  }

  release () {
    this.refCount--
    if (this.refCount === 0) this.removeSync()
  }

  isReleased () {
    return this.refCount === 0
  }
}

export default class FileRecoveryService {
  constructor (recoveryDirectory) {
    this.recoveryDirectory = recoveryDirectory
    this.recoveryFilesByFilePath = new Map()
    this.recoveryFilesByWindow = new WeakMap()
    this.observedWindows = new WeakSet()
  }

  start () {
    ipcMain.on('will-save-path', this.willSavePath.bind(this))
    ipcMain.on('did-save-path', this.didSavePath.bind(this))
  }

  willSavePath (event, path) {
    if (!fs.existsSync(path)) {
      // Unexisting files won't be truncated/overwritten, and so there's no data to be lost.
      event.returnValue = false
      return
    }

    const window = BrowserWindow.fromWebContents(event.sender)
    let recoveryFile = this.recoveryFilesByFilePath.get(path)
    if (recoveryFile == null) {
      const recoveryPath = Path.join(this.recoveryDirectory, crypto.randomBytes(5).toString('hex'))
      recoveryFile = new RecoveryFile(path, recoveryPath)
      this.recoveryFilesByFilePath.set(path, recoveryFile)
    }
    recoveryFile.retain()

    if (!this.recoveryFilesByWindow.has(window)) this.recoveryFilesByWindow.set(window, new Set())
    this.recoveryFilesByWindow.get(window).add(recoveryFile)

    if (!this.observedWindows.has(window)) {
      this.observedWindows.add(window)
      window.webContents.on('crashed', () => this.recoverFilesForWindow(window))
      window.on('closed', () => {
        this.observedWindows.delete(window)
        this.recoveryFilesByWindow.delete(window)
      })
    }

    event.returnValue = true
  }

  didSavePath (event, path) {
    const window = BrowserWindow.fromWebContents(event.sender)
    const recoveryFile = this.recoveryFilesByFilePath.get(path)
    if (recoveryFile != null) {
      recoveryFile.release()
      if (recoveryFile.isReleased()) this.recoveryFilesByFilePath.delete(path)
      this.recoveryFilesByWindow.get(window).delete(recoveryFile)
    }

    event.returnValue = true
  }

  recoverFilesForWindow (window) {
    if (!this.recoveryFilesByWindow.has(window)) return

    for (const recoveryFile of this.recoveryFilesByWindow.get(window)) {
      try {
        recoveryFile.recoverSync()
      } catch (error) {
        console.log(`Cannot recover ${recoveryFile.originalPath}. A recovery file has been saved here: ${recoveryFile.recoveryPath}.`)
      } finally {
        this.recoveryFilesByFilePath.delete(recoveryFile.originalPath)
      }
    }

    this.recoveryFilesByWindow.delete(window)
  }
}
