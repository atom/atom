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
    this.windowsByRecoveryFile = new Map()
  }

  willSavePath (window, path) {
    if (!fs.existsSync(path)) return

    const recoveryPath = Path.join(this.recoveryDirectory, RecoveryFile.fileNameForPath(path))
    const recoveryFile =
      this.recoveryFilesByFilePath.get(path) || new RecoveryFile(path, recoveryPath)

    try {
      recoveryFile.retain()
    } catch (err) {
      console.log(`Couldn't retain ${recoveryFile.recoveryPath}. Code: ${err.code}. Message: ${err.message}`)
      return
    }

    if (!this.recoveryFilesByWindow.has(window)) {
      this.recoveryFilesByWindow.set(window, new Set())
    }
    if (!this.windowsByRecoveryFile.has(recoveryFile)) {
      this.windowsByRecoveryFile.set(recoveryFile, new Set())
    }

    this.recoveryFilesByWindow.get(window).add(recoveryFile)
    this.windowsByRecoveryFile.get(recoveryFile).add(window)
    this.recoveryFilesByFilePath.set(path, recoveryFile)
  }

  didSavePath (window, path) {
    const recoveryFile = this.recoveryFilesByFilePath.get(path)
    if (recoveryFile != null) {
      try {
        recoveryFile.release()
      } catch (err) {
        console.log(`Couldn't release ${recoveryFile.recoveryPath}. Code: ${err.code}. Message: ${err.message}`)
      }
      if (recoveryFile.isReleased()) this.recoveryFilesByFilePath.delete(path)
      this.recoveryFilesByWindow.get(window).delete(recoveryFile)
      this.windowsByRecoveryFile.get(recoveryFile).delete(window)
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
          `Error ${error.code}. There was a crash while saving "${recoveryFile.originalPath}", so this file might be blank or corrupted.\n` +
          `Atom couldn't recover it automatically, but a recovery file has been saved at: "${recoveryFile.recoveryPath}".`
        console.log(detail)
        dialog.showMessageBox(window.browserWindow, {type: 'info', buttons: ['OK'], message, detail})
      } finally {
        for (let window of this.windowsByRecoveryFile.get(recoveryFile)) {
          this.recoveryFilesByWindow.get(window).delete(recoveryFile)
        }
        this.windowsByRecoveryFile.delete(recoveryFile)
        this.recoveryFilesByFilePath.delete(recoveryFile.originalPath)
      }
    }
  }

  didCloseWindow (window) {
    if (!this.recoveryFilesByWindow.has(window)) return

    for (let recoveryFile of this.recoveryFilesByWindow.get(window)) {
      this.windowsByRecoveryFile.get(recoveryFile).delete(window)
    }
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
    fs.copyFileSync(this.originalPath, this.recoveryPath)
  }

  recoverSync () {
    fs.copyFileSync(this.recoveryPath, this.originalPath)
    this.removeSync()
  }

  removeSync () {
    fs.unlinkSync(this.recoveryPath)
  }

  retain () {
    if (this.isReleased()) this.storeSync()
    this.refCount++
  }

  release () {
    this.refCount--
    if (this.isReleased()) this.removeSync()
  }

  isReleased () {
    return this.refCount === 0
  }
}
