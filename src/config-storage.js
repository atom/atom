const _ = require('underscore-plus')
const async = require('async')
const fs = require('fs-plus')
const lockFile = require('lockfile')
const path = require('path')
const CSON = require('season')
const {watchPath} = require('./path-watcher')
const Color = require('./color')

module.exports = class ConfigStorage {
  constructor ({config, configDirPath, resourcePath, notificationManager}) {
    this.config = config
    this.configDirPath = configDirPath
    this.resourcePath = resourcePath
    this.notificationManager = notificationManager
    this.configFilePath = fs.resolve(configDirPath, 'config', ['json', 'cson'])
    this.configFilePath = this.configFilePath || path.join(configDirPath, 'config.cson')
    console.log(`ConfigFilePath is ${this.configFilePath}`)

    this.isLoading = false
    this.isSaving = false
  }

  getUserConfigPath() {
    return this.configFilePath
  }

  start () {
    this.pendingOperations = []
    this.initializeConfigDirectory()
    this.initializeUserConfig()
    this.load()
    this.observeUserConfigFile()
  }

  stop () {
    this.save()
    this.unobserveUserConfigFile()
  }

  initializeConfigDirectory (done) {
    // TODO: Make this method async
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

  load () {
    // Do not try and load while we are waiting to load
    console.trace('load')
    if (this.isLoading) return
    this.isLoading = true

    console.log('will load')

    // Only load the config if we can get a lock as it might be mid-write
    this.withinConfigFileLock(() => {
      try {
        console.log('load access file')
        const userConfig = CSON.readFileSync(this.configFilePath) || {}

        if (!isPlainObject(userConfig)) {
          throw new Error(`\`${path.basename(this.configFilePath)}\` must contain valid JSON or CSON`)
        }

        console.log('load applying settings')
        this.config.applyUserSettings(userConfig)
        this.configFileHasErrors = false
      } catch (error) {
        this.configFileHasErrors = true
        this.settingsLoaded = true
        this.notifyFailure(`Failed to load \`${path.basename(this.configFilePath)}\``, (error.location != null) ? error.stack : error.message)
      }
    }, () => {
      this.isLoading = false
    })
  }

  save () {
    if (this.isSaving || this.isLoading || this.configFileHasErrors) return
    this.isSaving = true

    this.withinConfigFileLock(() => {
      // Reload the user configuration file in case it changed
      this.loadUserConfig()
      // Take as many operations as currently in the queue and apply them
      const pendingOperationsCount = this.pendingOperations.length
      for (let op of this.pendingOperations.slice(0, pendingOperationsCount)) { op() }

      console.log(`There are ${this.pendingOperations.length}`)
      let allSettings = {'*': this.settings}
      allSettings = Object.assign(allSettings, this.scopedSettingsStore.propertiesForSource(this.getUserConfigPath()))
      allSettings = sortObject(allSettings)

      try {
        CSON.writeFileSync(this.configFilePath, allSettings)
        // Remove the operations we successfully processed
        this.pendingOperations = this.pendingOperations.slice(pendingOperationsCount)
        console.log(`There are now ${this.pendingOperations.length}`)
      } catch (error) {
        this.notifyFailure(`Failed to save \`${path.basename(this.configFilePath)}\``, error.message)
      }
    }, () => {
      this.isSaving = false
    })
  }

  withinConfigFileLock (acquiredOperation, releaseOperation) {
    const lockFilePath = this.configFilePath + '.lock'
    lockFile.lock(lockFilePath, {}, err => {
      if (err) console.error(err)
      acquiredOperation()
      lockFile.unlock(lockFilePath, err => {
        if (err) console.error(err)
        releaseOperation()
      })
    })
  }

  observeUserConfigFile () {
    try {
      if (this.watchSubscriptionPromise == null) {
        this.watchSubscriptionPromise = watchPath(this.configFilePath, {}, events => {
          if (events.find(e => ['created', 'modified', 'renamed'].includes(e.action))) {
            this.load()
          }
        })
      }
    } catch (error) {
      this.notifyFailure(`\Unable to watch \`${this.configFilePath}\`.
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

  notifyFailure (errorMessage, detail) {
    if (!this.notificationManager) return
    this.notificationManager.addError(errorMessage, {detail, dismissable: true})
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
