const _ = require('underscore-plus')
const async = require('async')
const fs = require('fs-plus')
const lockFile = require('lockfile')
const path = require('path')
const CSON = require('season')
const {watchPath} = require('./path-watcher')
const Color = require('./color')

const saveRetryTime = 250
const saveRetryCount = 8

module.exports = class ConfigStorage {
  static createConfigFilePath (configDirPath) {
    return fs.resolve(configDirPath, 'config', ['json', 'cson']) || path.join(configDirPath, 'config.cson')
  }

  constructor ({config, configDirPath, resourcePath, notificationManager}) {
    this.config = config
    this.configDirPath = configDirPath
    this.configFilePath = ConfigStorage.createConfigFilePath(configDirPath)
    this.resourcePath = resourcePath
    this.notificationManager = notificationManager
    this.isLoading = false
    this.isSaving = false
  }

  getUserConfigPath () {
    return this.configFilePath
  }

  start () {
    this.pendingOperations = []
    this.saveLockFail = 0
    this.configListener = this.config.onDidSetOrUnset(op => this.capturePendingOperation(op))
    this.initializeConfigDirectory()
    this.initializeUserConfig()
    this.load(() => {
      this.observeUserConfigFile()
    })
  }

  stop () {
    if (this.configListener != null) {
      this.configListener.dispose()
      this.configListener = null
    }
    this.unobserveUserConfigFile()
    this.startSave()
  }

  capturePendingOperation (op) {
    const option = op.slice(-1)[0]
    const userConfigSource = option == null || option.source == null || option.source === this.getUserConfigPath()
    const shouldSave = option == null || option.save

    if (shouldSave && userConfigSource) {
      this.pendingOperations.push(op)
      this.save()
    }
  }

  initializeConfigDirectory (done) {
    // Ideally this method would be async but traverseTree isn't so...
    if (fs.existsSync(this.configDirPath)) return

    fs.makeTreeSync(this.configDirPath)
    const queue = async.queue(({sourcePath, destinationPath}, callback) => fs.copy(sourcePath, destinationPath, callback))
    queue.drain = done

    const templateConfigDirPath = fs.resolve(this.resourcePath, 'dot-atom')
    const onConfigDirFile = sourcePath => {
      const relativePath = sourcePath.substring(templateConfigDirPath.length + 1)
      const destinationPath = path.join(this.configDirPath, relativePath)
      return queue.push({sourcePath, destinationPath})
    }
    fs.traverseTree(templateConfigDirPath, onConfigDirFile, path => true, () => {})
  }

  initializeUserConfig () {
    // TODO: Make this async
    try {
      if (!fs.existsSync(this.configFilePath)) {
        fs.makeTreeSync(path.dirname(this.configFilePath))
        CSON.writeFileSync(this.configFilePath, {}, {flag: 'wx'}) // fails if file exists
      }
    } catch (error) {
      if (error.code !== 'EEXIST') {
        this.configFileHasErrors = true
        this.notifyFailure(`Failed to initialize \`${path.basename(this.configFilePath)}\``, error.stack)
      }
    }
  }

  load (callback) {
    if (this.isLoading) {
      // Do not try and load while we are already loading
      callback(null, false)
      return
    }

    const loadErrorMessage = `Failed to load \`${path.basename(this.configFilePath)}\``

    this.isLoading = true
    CSON.readFile(this.configFilePath, (err, userConfig) => {
      this.isLoading = false
      if (err) {
        this.configFileHasErrors = true
        this.notifyFailure(loadErrorMessage, err.location != null ? err.stack : err.message)
        callback(err, false)
      } else {
        if (!isPlainObject(userConfig)) {
          const error = new Error(`\`${path.basename(this.configFilePath)}\` must contain valid JSON or CSON`)
          this.notifyFailure(loadErrorMessage, error)
          callback(error, false)
        } else {
          this.config.applyUserSettings(userConfig)
          this.configFileHasErrors = false
          callback(null, true)
        }
      }
    })
  }

  save () {
    // Debounce and retry saves
    if (this.saveTimer == null) {
      this.saveTimer = setInterval(() => this.startSave(), saveRetryTime)
    }
  }

  startSave () {
    if (this.isSaving || this.isLoading || this.configFileHasErrors) return
    this.isSaving = true

    clearInterval(this.saveTimer)
    this.saveTimer = null

    const lockFilePath = this.configFilePath + '.lock'
    lockFile.lock(lockFilePath, {}, (err) => {
      if (err) {
        if (this.saveLockFail++ > saveRetryCount) {
          this.saveFailureNotification = this.notifyFailure(`Failed to save \`${path.basename(this.configFilePath)}\``,
            'File lock could not be obtained. Is this file in use by another instance of Atom?', [
              { text: 'Retry',
                onDidClick: () => {
                  this.saveFailureNotification.dismiss()
                  this.saveLockFail = 0
                  this.save()
                }
              },
              { text: 'Force',
                onDidClick: () => {
                  this.saveFailureNotification.dismiss()
                  fs.unlink(lockFilePath, () => {
                    this.saveLockFail = 0
                    this.save()
                  })
                }
              }
            ])
        } else {
          this.save() // Try again until retry count limit reached
        }
        this.isSaving = false
      } else {
        this.load((err) => {
          if (err) {
            lockFile.unlock(lockFilePath, () => {
              this.isSaving = false
            })
          } else {
            this.actualSave(() => {
              lockFile.unlock(lockFilePath, () => {
                this.isSaving = false
                this.saveLockFail = 0
              })
            })
          }
        })
      }
    })
  }

  actualSave (callback) {
    // Take as many operations as currently in the queue and apply them
    const pendingOperationsCount = this.pendingOperations.length
    for (let op of this.pendingOperations.slice(0, pendingOperationsCount)) {
      this.applyOperation(op)
    }

    let allSettings = {'*': this.config.settings}
    allSettings = Object.assign(allSettings, this.config.scopedSettingsStore.propertiesForSource(this.getUserConfigPath()))
    allSettings = sortObject(allSettings)

    CSON.writeFile(this.configFilePath, allSettings, (error) => {
      if (error) {
        this.notifyFailure(`Failed to save \`${path.basename(this.configFilePath)}\``, error.message)
        callback(error)
      } else {
        // Remove the operations we successfully processed
        this.pendingOperations = this.pendingOperations.slice(pendingOperationsCount)
        // Schedule another save if some were received during call
        if (this.pendingOperations.length > 0) {
          this.save()
        }
      }
      callback(null)
    })
  }

  applyOperation (op) {
    switch (op[0]) {
      case 'set': {
        this.config.setActual(op[1], op[2], op[3])
        break
      }
      case 'unset': {
        this.config.unsetActual(op[1], op[2])
        break
      }
    }
  }

  observeUserConfigFile () {
    try {
      if (this.watchSubscriptionPromise == null) {
        this.watchSubscriptionPromise = watchPath(this.configFilePath, {}, events => {
          if (events.find(e => ['created', 'modified', 'renamed'].includes(e.action))) {
            this.load(() => {
              // TODO: How to recover here? Schedule like saves?
            })
          }
        })
      }
    } catch (error) {
      this.notifyFailure(`Unable to watch \`${this.configFilePath}\`.
        Make sure you have permissions to this file.` +
        process.platform === 'linux'
          ? `On Linux there are [problems with watch sizes](https://github.com/atom/atom/blob/master/docs/build-instructions/linux.md#typeerror-unable-to-watch-path])`
          : ''
      )
    }
  }

  unobserveUserConfigFile () {
    if (this.watchSubscriptionPromise == null) return
    this.watchSubscriptionPromise.then(watcher => { if (watcher != null) watcher.dispose() })
    this.watchSubscriptionPromise = null
  }

  notifyFailure (errorMessage, detail, buttons) {
    if (!this.notificationManager) return
    return this.notificationManager.addError(errorMessage, {detail, dismissable: true, buttons})
  }
}

function isPlainObject (value) {
  return _.isObject(value) && !_.isArray(value) && !_.isFunction(value) && !_.isString(value) && !(value instanceof Color)
}

function sortObject (value) {
  if (!isPlainObject(value)) return value

  const result = {}
  for (let key of Object.keys(value).sort()) {
    result[key] = sortObject(value[key])
  }
  return result
}
