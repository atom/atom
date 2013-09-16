fsUtils = require 'fs-utils'
_ = require 'underscore'
EventEmitter = require 'event-emitter'
CSON = require 'season'
fs = require 'fs'
path = require 'path'
async = require 'async'
pathWatcher = require 'pathwatcher'

configDirPath = fsUtils.absolute("~/.atom")
nodeModulesDirPath = path.join(resourcePath, "node_modules")
bundledKeymapsDirPath = path.join(resourcePath, "keymaps")
userPackagesDirPath = path.join(configDirPath, "packages")
userPackageDirPaths = [userPackagesDirPath]
userPackageDirPaths.unshift(path.join(configDirPath, "dev", "packages")) if atom.getLoadSettings().devMode
userStoragePath = path.join(configDirPath, "storage")

# Public: Used to access all of Atom's configuration details.
#
# A global instance of this class is available to all plugins which can be
# referenced using `global.config`
#
# ### Best practices ###
#
# * Create your own root keypath using your package's name.
# * Don't depend on (or write to) configuration keys outside of your keypath.
#
# ### Example ###
#
# ```coffeescript
# global.config.set('myplugin.key', 'value')
# global.observe 'myplugin.key', ->
#   console.log 'My configuration changed:', global.config.get('myplugin.key')
# ```
module.exports =
class Config
  _.extend @prototype, EventEmitter

  configDirPath: configDirPath
  bundledPackageDirPaths: [nodeModulesDirPath]
  bundledKeymapsDirPath: bundledKeymapsDirPath
  nodeModulesDirPath: nodeModulesDirPath
  packageDirPaths: _.clone(userPackageDirPaths)
  userPackageDirPaths: userPackageDirPaths
  userStoragePath: userStoragePath
  lessSearchPaths: [
    path.join(resourcePath, 'static', 'variables')
    path.join(resourcePath, 'static')
    path.join(resourcePath, 'vendor', 'less')
  ]
  defaultSettings: null
  settings: null
  configFileHasErrors: null

  # Private: Created during initialization, available as `global.config`
  constructor: ->
    @defaultSettings =
      core: _.clone(require('root-view').configDefaults)
      editor: _.clone(require('editor').configDefaults)
    @settings = {}
    @configFilePath = fsUtils.resolve(configDirPath, 'config', ['json', 'cson'])
    @configFilePath ?= path.join(configDirPath, 'config.cson')

  # Private:
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

  # Private:
  load: ->
    @initializeConfigDirectory()
    @loadUserConfig()
    @observeUserConfig()

  # Private:
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

  # Private:
  observeUserConfig: ->
    @watchSubscription ?= pathWatcher.watch @configFilePath, (eventType) =>
      @loadUserConfig() if eventType is 'change' and @watchSubscription?

  # Private:
  unobserveUserConfig: ->
    @watchSubscription?.close()
    @watchSubscription = null

  # Private:
  setDefaults: (keyPath, defaults) ->
    keys = keyPath.split('.')
    hash = @defaultSettings
    for key in keys
      hash[key] ?= {}
      hash = hash[key]

    _.extend hash, defaults
    @update()

  # Public: Returns a new {Object} containing all of settings and defaults.
  getSettings: ->
    _.deepExtend(@settings, @defaultSettings)

  # Public: Retrieves the setting for the given key.
  #
  # keyPath - The {String} name of the key to retrieve
  #
  # Returns the value from Atom's default settings, the user's configuration file,
  # or `null` if the key doesn't exist in either.
  get: (keyPath) ->
    value = _.valueForKeyPath(@settings, keyPath) ? _.valueForKeyPath(@defaultSettings, keyPath)
    _.deepClone(value)

  # Public: Retrieves the setting for the given key as an integer.
  #
  # keyPath - The {String} name of the key to retrieve
  #
  # Returns the value from Atom's default settings, the user's configuration file,
  # or `NaN` if the key doesn't exist in either.
  getInt: (keyPath) ->
    parseInt(@get(keyPath))

  # Public: Retrieves the setting for the given key as a positive integer.
  #
  # keyPath - The {String} name of the key to retrieve
  # defaultValue - The integer {Number} to fall back to if the value isn't
  #                positive
  #
  # Returns the value from Atom's default settings, the user's configuration file,
  # or `defaultValue` if the key value isn't greater than zero.
  getPositiveInt: (keyPath, defaultValue) ->
    Math.max(@getInt(keyPath), 0) or defaultValue

  # Public: Sets the value for a configuration setting.
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

  # Public: Push the value to the array at the key path.
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

  # Public: Remove the value from the array at the key path.
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

  # Public: Establishes an event listener for a given key.
  #
  # `callback` is fired whenever the value of the key is changed and will
  #  be fired immediately unless the `callNow` option is `false`.
  #
  # keyPath - The {String} name of the key to watch
  # options - An optional {Object} containing the `callNow` key.
  # callback - The {Function} that fires when the. It is given a single argument, `value`,
  #            which is the new value of `keyPath`.
  observe: (keyPath, options={}, callback) ->
    if _.isFunction(options)
      callback = options
      options = {}

    value = @get(keyPath)
    previousValue = _.clone(value)
    updateCallback = =>
      value = @get(keyPath)
      unless _.isEqual(value, previousValue)
        previousValue = _.clone(value)
        callback(value)

    subscription = { cancel: => @off 'updated', updateCallback  }
    @on 'updated', updateCallback
    callback(value) if options.callNow ? true
    subscription

  # Private:
  update: ->
    return if @configFileHasErrors
    @save()
    @trigger 'updated'

  # Private:
  save: ->
    CSON.writeFileSync(@configFilePath, @settings)
