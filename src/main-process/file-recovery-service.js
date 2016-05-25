'use babel'

import {BrowserWindow, ipcMain} from 'electron'
import crypto from 'crypto'
import Path from 'path'
import fs from 'fs-plus'

export default class FileRecoveryService {
  constructor (recoveryDirectory) {
    this.recoveryDirectory = recoveryDirectory
    this.recoveryPathsByWindowAndFilePath = new WeakMap()
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
    const recoveryFileName = crypto.randomBytes(5).toString('hex')
    const recoveryPath = Path.join(this.recoveryDirectory, recoveryFileName)
    fs.writeFileSync(recoveryPath, fs.readFileSync(path))

    if (!this.recoveryPathsByWindowAndFilePath.has(window)) {
      this.recoveryPathsByWindowAndFilePath.set(window, new Map())
    }
    this.recoveryPathsByWindowAndFilePath.get(window).set(path, recoveryPath)

    if (!this.observedWindows.has(window)) {
      window.webContents.on("crashed", () => this.recoverFilesForWindow(window))
      window.on("closed", () => {
        this.observedWindows.delete(window)
        this.recoveryPathsByWindowAndFilePath.delete(window)
      })
      this.observedWindows.add(window)
    }

    event.returnValue = true
  }

  didSavePath (event, path) {
    const window = BrowserWindow.fromWebContents(event.sender)
    const recoveryPathsByFilePath = this.recoveryPathsByWindowAndFilePath.get(window)
    if (recoveryPathsByFilePath == null || !recoveryPathsByFilePath.has(path)) {
      event.returnValue = false
      return
    }

    const recoveryPath = recoveryPathsByFilePath.get(path)
    fs.unlinkSync(recoveryPath)
    recoveryPathsByFilePath.delete(path)
    event.returnValue = true
  }

  recoverFilesForWindow (window) {
    const recoveryPathsByFilePath = this.recoveryPathsByWindowAndFilePath.get(window)
    for (let [filePath, recoveryPath] of recoveryPathsByFilePath) {
      try {
        fs.writeFileSync(filePath, fs.readFileSync(recoveryPath))
        fs.unlinkSync(recoveryPath)
      } catch (error) {
        console.log(`Cannot recover ${filePath}. A recovery file has been saved here: ${recoveryPath}.`)
      }
    }

    recoveryPathsByFilePath.clear()
  }
}
