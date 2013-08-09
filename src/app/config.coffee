fsUtils = require 'fs-utils'
_ = require 'underscore'
EventEmitter = require 'event-emitter'
CSON = require 'season'
fs = require 'fs'
path = require 'path'
async = require 'async'
pathWatcher = require 'pathwatcher'

configDirPath = fsUtils.absolute("~/.atom")
bundledPackagesDirPath = path.join(resourcePath, "src/packages")
nodeModulesDirPath = path.join(resourcePath, "node_modules")
bundledThemesDirPath = path.join(resourcePath, "themes")
vendoredPackagesDirPath = path.join(resourcePath, "vendor/packages")
vendoredThemesDirPath = path.join(resourcePath, "vendor/themes")
userThemesDirPath = path.join(configDirPath, "themes")
userPackagesDirPath = path.join(configDirPath, "packages")
userStoragePath = path.join(configDirPath, "storage")

# Public: Handles all of Atom's configuration details.
#
# This includes loading and setting default options, as well as reading from the
# user's configuration file.
module.exports =
class Config
  configDirPath: configDirPath
  themeDirPaths: [userThemesDirPath, bundledThemesDirPath, vendoredThemesDirPath]
  bundledPackageDirPaths: [vendoredPackagesDirPath, bundledPackagesDirPath, nodeModulesDirPath]
  packageDirPaths: [userPackagesDirPath, vendoredPackagesDirPath, bundledPackagesDirPath]
  userPackagesDirPath: userPackagesDirPath
  userStoragePath: userStoragePath
  lessSearchPaths: [path.join(resourcePath, 'static'), path.join(resourcePath, 'vendor')]
  defaultSettings: null
  settings: null
  configFileHasErrors: null

  ### Internal ###

  constructor: ->
    @defaultSettings =
      core: _.clone(require('root-view').configDefaults)
      editor: _.clone(require('editor').configDefaults)
    @settings = {}
    @configFilePath = fsUtils.resolve(configDirPath, 'config', ['json', 'cson'])
    @configFilePath ?= path.join(configDirPath, 'config.cson')

  initializeConfigDirectory: (done) ->
    return if fsUtils.exists(@configDirPath)

    fsUtils.makeTree(@configDirPath)

    queue = async.queue ({sourcePath, destinationPath}, callback) =>
      fsUtils.copy(sourcePath, destinationPath, callback)
    queue.drain = done

    templateConfigDirPath = fsUtils.resolve(window.resourcePath, 'dot-atom')
    onConfigDirFile = (sourcePath) =>
      relativePath = sourcePath.substring(templateConfigDirPath.length + 1)
      destinationPath = path.join(@configDirPath, relativePath)
      queue.push({sourcePath, destinationPath})
    fsUtils.traverseTree(templateConfigDirPath, onConfigDirFile, (path) -> true)

  load: ->
    @initializeConfigDirectory()
    @loadUserConfig()
    @observeUserConfig()

  loadUserConfig: ->
    if !fsUtils.exists(@configFilePath)
      fsUtils.makeTree(path.dirname(@configFilePath))
      CSON.writeFileSync(@configFilePath, {})

    try
      userConfig = CSON.readFileSync(@configFilePath)
      _.extend(@settings, userConfig)
      @configFileHasErrors = false
      @trigger 'updated'
    catch e
      @configFileHasErrors = true
      console.error "Failed to load user config '#{@configFilePath}'", e.message
      console.error e.stack

  observeUserConfig: ->
    @watchSubscription ?= pathWatcher.watch @configFilePath, (eventType) =>
      @loadUserConfig() if eventType is 'change' and @watchSubscription?

  unobserveUserConfig: ->
    @watchSubscription?.close()
    @watchSubscription = null

  setDefaults: (keyPath, defaults) ->
    keys = keyPath.split('.')
    hash = @defaultSettings
    for key in keys
      hash[key] ?= {}
      hash = hash[key]

    _.extend hash, defaults
    @update()

  ### Public ###

  # Retrieves the setting for the given key.
  #
  # keyPath - The {String} name of the key to retrieve
  #
  # Returns the value from Atom's default settings, the user's configuration file,
  # or `null` if the key doesn't exist in either.
  get: (keyPath) ->
    value = _.valueForKeyPath(@settings, keyPath) ? _.valueForKeyPath(@defaultSettings, keyPath)
    _.deepClone(value)

  # Retrieves the setting for the given key as an integer.
  #
  # keyPath - The {String} name of the key to retrieve
  #
  # Returns the value from Atom's default settings, the user's configuration file,
  # or `NaN` if the key doesn't exist in either.
  getInt: (keyPath, defaultValueWhenFalsy) ->
    parseInt(@get(keyPath))

  # Retrieves the setting for the given key as a positive integer.
  #
  # keyPath - The {String} name of the key to retrieve
  # defaultValue - The integer {Number} to fall back to if the value isn't
  #                positive
  #
  # Returns the value from Atom's default settings, the user's configuration file,
  # or `defaultValue` if the key value isn't greater than zero.
  getPositiveInt: (keyPath, defaultValue) ->
    Math.max(@getInt(keyPath), 0) or defaultValue

  # Sets the value for a configuration setting.
  #
  # This value is stored in Atom's internal configuration file.
  #
  # keyPath - The {String} name of the key
  # value - The value of the setting
  #
  # Returns the `value`.
  set: (keyPath, value) ->
    if @get(keyPath) != value
      value = undefined if _.valueForKeyPath(@defaultSettings, keyPath) == value
      _.setValueForKeyPath(@settings, keyPath, value)
      @update()
    value

  # Push the value to the array at the key path.
  #
  # keyPath - The {String} key path.
  # value - The value to push to the array.
  #
  # Returns the new array length of the setting.
  pushAtKeyPath: (keyPath, value) ->
    arrayValue = @get(keyPath) ? []
    result = arrayValue.push(value)
    @set(keyPath, arrayValue)
    result

  # Remove the value from the array at the key path.
  #
  # keyPath - The {String} key path.
  # value - The value to remove from the array.
  #
  # Returns the new array value of the setting.
  removeAtKeyPath: (keyPath, value) ->
    arrayValue = @get(keyPath) ? []
    result = _.remove(arrayValue, value)
    @set(keyPath, arrayValue)
    result

  # Establishes an event listener for a given key.
  #
  # `callback` is fired immediately and whenever the value of the key is changed
  #
  # keyPath - The {String} name of the key to watch
  # callback - The {Function} that fires when the. It is given a single argument, `value`,
  #            which is the new value of `keyPath`.
  observe: (keyPath, callback) ->
    value = @get(keyPath)
    previousValue = _.clone(value)
    updateCallback = =>
      value = @get(keyPath)
      unless _.isEqual(value, previousValue)
        previousValue = _.clone(value)
        callback(value)

    subscription = { cancel: => @off 'updated', updateCallback  }
    @on 'updated', updateCallback
    callback(value)
    subscription

  ### Internal ###

  update: ->
    return if @configFileHasErrors
    @save()
    @trigger 'updated'

  save: ->
    CSON.writeFileSync(@configFilePath, @settings)

_.extend Config.prototype, EventEmitter
