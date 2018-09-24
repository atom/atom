const {dialog} = require('electron')
const crypto = require('crypto')
const Path = require('path')
const fs = require('fs-plus')
const mkdirp = require('mkdirp')
const {promisify} = require('util')
const unlink = promisify(fs.unlink)

const HOUR_MS = 60 * 60 * 1000

module.exports =
class FileRecoveryService {
  constructor (recoveryDirectory, gcInterval=HOUR_MS) {
    this.recoveryDirectory = recoveryDirectory
    this.recoveryFilesByFilePath = new Map()
    this.recoveryFilesByWindow = new WeakMap()
    this.windowsByRecoveryFile = new Map()
    gcInterval && setInterval(() => this.sweep(), gcInterval)
  }

  async willSavePath (window, path) {
    const stats = await tryStatFile(path)
    if (!stats) return

    const recoveryPath = Path.join(this.recoveryDirectory, RecoveryFile.fileNameForPath(path))
    const recoveryFile =
      this.recoveryFilesByFilePath.get(path) || new RecoveryFile(path, stats.mode, recoveryPath)

    try {
      await recoveryFile.retain()
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

  async didSavePath (window, path) {
    const recoveryFile = this.recoveryFilesByFilePath.get(path)
    if (recoveryFile != null) {
      try {
        await recoveryFile.release()
      } catch (err) {
        console.log(`Couldn't release ${recoveryFile.recoveryPath}. Code: ${err.code}. Message: ${err.message}`)
      }
      if (recoveryFile.isReleased()) this.recoveryFilesByFilePath.delete(path)
      this.recoveryFilesByWindow.get(window).delete(recoveryFile)
      this.windowsByRecoveryFile.get(recoveryFile).delete(window)
    }
  }

  async didCrashWindow (window) {
    if (!this.recoveryFilesByWindow.has(window)) return

    const promises = []
    for (const recoveryFile of this.recoveryFilesByWindow.get(window)) {
      promises.push(recoveryFile.recover()
        .catch(error => {
          const message = 'A file that Atom was saving could be corrupted'
          const detail =
            `Error ${error.code}. There was a crash while saving "${recoveryFile.originalPath}", so this file might be blank or corrupted.\n` +
            `Atom couldn't recover it automatically, but a recovery file has been saved at: "${recoveryFile.recoveryPath}".`
          console.log(detail)
          dialog.showMessageBox(window, {type: 'info', buttons: ['OK'], message, detail}, () => { /* noop callback to get async behavior */ })
        })
        .then(() => {
          for (let window of this.windowsByRecoveryFile.get(recoveryFile)) {
            this.recoveryFilesByWindow.get(window).delete(recoveryFile)
          }
          this.windowsByRecoveryFile.delete(recoveryFile)
          this.recoveryFilesByFilePath.delete(recoveryFile.originalPath)
        })
      )
    }

    await Promise.all(promises)
  }

  didCloseWindow (window) {
    if (!this.recoveryFilesByWindow.has(window)) return

    for (let recoveryFile of this.recoveryFilesByWindow.get(window)) {
      this.windowsByRecoveryFile.get(recoveryFile).delete(window)
    }
    this.recoveryFilesByWindow.delete(window)
  }

  async sweep(maxAge=HOUR_MS, {ls=ls, unlink=unlink}={}) {
    const minMTime = Date.now() - maxAge
    const pathStats = await ls(this.recoveryPath, name => name.endsWith('~'))
    const garbage = pathStats.filter(({stat: {mtimeMs}}) => mtimeMs < minMTime)
    return Promise.all(garbage.map(({path}) => unlink(path)))
  }
}

class RecoveryFile {
  static fileNameForPath (path) {
    const extension = Path.extname(path)
    const basename = Path.basename(path, extension).substring(0, 34)
    const randomSuffix = crypto.randomBytes(3).toString('hex')
    return `${basename}-${randomSuffix}${extension}`
  }

  constructor (originalPath, fileMode, recoveryPath) {
    this.originalPath = originalPath
    this.fileMode = fileMode
    this.recoveryPath = recoveryPath
    this.refCount = 0
  }

  async store () {
    await copyFile(this.originalPath, this.recoveryPath, this.fileMode)
  }

  async recover () {
    await copyFile(this.recoveryPath, this.originalPath, this.fileMode)
    await this.remove()
  }

  async remove () {
    return new Promise((resolve, reject) =>
      fs.move(this.recoveryPath, this.recoveryPath + '~', error =>
        error && error.code !== 'ENOENT' ? reject(error) : resolve()
      )
    )
  }

  async retain () {
    if (this.isReleased()) await this.store()
    this.refCount++
  }

  async release () {
    this.refCount--
    if (this.isReleased()) await this.remove()
  }

  isReleased () {
    return this.refCount === 0
  }
}

async function tryStatFile (path) {
  return new Promise((resolve, reject) =>
    fs.stat(path, (error, result) =>
      resolve(error == null && result)
    )
  )
}

async function copyFile (source, destination, mode) {
  return new Promise((resolve, reject) => {
    mkdirp(Path.dirname(destination), (error) => {
      if (error) return reject(error)
      const readStream = fs.createReadStream(source)
      readStream
        .on('error', reject)
        .once('open', () => {
          const writeStream = fs.createWriteStream(destination, {mode})
          writeStream
            .on('error', reject)
            .on('open', () => readStream.pipe(writeStream))
            .once('close', () => resolve())
        })
    })
  })
}

const stat = promisify(fs.stat)
const readdir = promisify(fs.readdir)

async function ls (dir, pathPredicate=name => true) {
  const entries = await readdir(dir)
  return Promise.all(entries.map(ent => {
    const path = Path.join(dir, ent)
    if (!pathPredicate(path)) return
    return stat(path).then(stat => ({path, stat}))
  }).filter(x => x))
}
