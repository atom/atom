'use babel'

import {dialog} from 'electron'
import crypto from 'crypto'
import Path from 'path'
import fs from 'fs-plus'

export default class FileRecoveryService {
  constructor (recoveryDirectory) {
    this.recoveryDirectory = recoveryDirectory
    this.recoveryFilesByFilePath = new Map()
    this.recoveryFilesByWindow = new WeakMap()
    this.observedWindows = new WeakSet()
  }

  willSavePath (window, path) {
    if (!fs.existsSync(path)) return

    let recoveryFile = this.recoveryFilesByFilePath.get(path)
    if (recoveryFile == null) {
      recoveryFile = new RecoveryFile(
        path,
        Path.join(this.recoveryDirectory, RecoveryFile.fileNameForPath(path))
      )
      this.recoveryFilesByFilePath.set(path, recoveryFile)
    }
    recoveryFile.retain()

    if (!this.observedWindows.has(window)) {
      this.observedWindows.add(window)
    }

    if (!this.recoveryFilesByWindow.has(window)) {
      this.recoveryFilesByWindow.set(window, new Set())
    }
    this.recoveryFilesByWindow.get(window).add(recoveryFile)
  }

  didSavePath (window, path) {
    const recoveryFile = this.recoveryFilesByFilePath.get(path)
    if (recoveryFile != null) {
      recoveryFile.release()
      if (recoveryFile.isReleased()) this.recoveryFilesByFilePath.delete(path)
      this.recoveryFilesByWindow.get(window).delete(recoveryFile)
    }
  }

  didCrashWindow (window) {
    if (!this.recoveryFilesByWindow.has(window)) return

    for (const recoveryFile of this.recoveryFilesByWindow.get(window)) {
      try {
        recoveryFile.recoverSync()
      } catch (error) {
        const message = 'A file that Atom was saving could be corrupted'
        const detail =
          `There was a crash while saving "${recoveryFile.originalPath}", so this file might be blank or corrupted.\n` +
          `Atom couldn't recover it automatically, but a recovery file has been saved at: "${recoveryFile.recoveryPath}".`
        console.log(detail)
        dialog.showMessageBox(window.browserWindow, {type: 'info', buttons: ['OK'], message, detail})
      } finally {
        this.recoveryFilesByFilePath.delete(recoveryFile.originalPath)
      }
    }

    this.recoveryFilesByWindow.delete(window)
  }

  didCloseWindow (window) {
    this.observedWindows.delete(window)
    this.recoveryFilesByWindow.delete(window)
  }
}

class RecoveryFile {
  static fileNameForPath (path) {
    const extension = Path.extname(path)
    const basename = Path.basename(path, extension).substring(0, 34)
    const randomSuffix = crypto.randomBytes(3).toString('hex')
    return `${basename}-${randomSuffix}${extension}`
  }

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
